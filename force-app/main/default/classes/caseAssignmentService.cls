// Hanterar normalisering, deduplicering och routing av leads från alla källor.
// Alla entry points tar emot en List så att SOQL queries aldrig körs i en loop.
public with sharing class caseAssignmentService {

    // Max antal aktiva leads en säljare får ha innan den hoppas över vid routing
    private static final Integer MAX_ACTIVE_LEADS = 5;

    // Landskoder som tillhör US-territoriet, allt annat hamnar i EU.
    // I produktion hanteras denna mappning via Custom Metadata.
    private static final Set<String> US_CODES = new Set<String>{ 'US' };

    // Entry points - en per källtyp, Apex väljer rätt version automatiskt baserat på listtypen

    public static void processLeads(List<RealTimeDTO> dtos) {
        List<LeadDTO> normalized = new List<LeadDTO>();
        for (RealTimeDTO dto : dtos) {
            normalized.add(normalizeRealTime(dto));
        }
        processNormalizedBulk(normalized);
    }

    public static void processLeads(List<BulkDTO> dtos) {
        List<LeadDTO> normalized = new List<LeadDTO>();
        for (BulkDTO dto : dtos) {
            normalized.add(normalizeBulk(dto));
        }
        processNormalizedBulk(normalized);
    }

    public static void processLeads(List<APIDTO> dtos) {
        List<LeadDTO> normalized = new List<LeadDTO>();
        for (APIDTO dto : dtos) {
            normalized.add(normalizeApi(dto));
        }
        processNormalizedBulk(normalized);
    }

    // Normalisering - översätter varje källas fältnamn till LeadDTOs enhetliga format

    @TestVisible
    private static LeadDTO normalizeRealTime(RealTimeDTO dto) {
        LeadDTO ld   = new LeadDTO();
        ld.firstName = dto.firstName;
        ld.lastName  = dto.lastName;
        ld.email     = dto.emailAddress;
        ld.company   = dto.companyName;
        ld.territory = mapToTerritory(dto.country);
        ld.sourceId  = dto.campaignId;
        return ld;
    }

    @TestVisible
    private static LeadDTO normalizeBulk(BulkDTO dto) {
        LeadDTO ld   = new LeadDTO();
        ld.firstName = dto.First_Name;
        ld.lastName  = dto.Last_Name;
        ld.email     = dto.Email;
        ld.company   = dto.Company;
        ld.territory = mapToTerritory(dto.Region);
        ld.sourceId  = dto.Row_ID;
        return ld;
    }

    @TestVisible
    private static LeadDTO normalizeApi(APIDTO dto) {
        LeadDTO ld   = new LeadDTO();
        ld.firstName = dto.user.name.first;
        ld.lastName  = dto.user.name.last;
        ld.email     = dto.user.contact.email;
        ld.company   = dto.employer;
        ld.territory = mapToTerritory(dto.location.countryCode);
        ld.sourceId  = dto.eventId;
        return ld;
    }

    // Deduplicering - hanterar hela batchen med fyra SOQL queries oavsett storlek

    @TestVisible
    private static void processNormalizedBulk(List<LeadDTO> dtos) {

        // Steg 1: Samla alla dedup-nycklar från hela batchen i Sets
        Set<String> emails    = new Set<String>();
        Set<String> lastNames = new Set<String>();
        Set<String> companies = new Set<String>();

        for (LeadDTO dto : dtos) {
            if (String.isNotBlank(dto.email))    emails.add(dto.email);
            if (String.isNotBlank(dto.lastName)) lastNames.add(dto.lastName);
            if (String.isNotBlank(dto.company))  companies.add(dto.company);
        }

        // Steg 2: En SOQL query för att hitta email-träffar
        Map<String, Lead> existingByEmail = new Map<String, Lead>();
        for (Lead l : [
            SELECT Id, FirstName, LastName, Email, Company, Country, OwnerId
            FROM Lead
            WHERE Email IN :emails
              AND IsConverted = false
        ]) {
            existingByEmail.put(l.Email, l);
        }

        // Steg 3: En SOQL query för att hitta namn+företag-träffar
        // Queryn är bred (LastName IN + Company IN) och filtreras till exakta kombinationer i minnet
        Map<String, Lead> existingByNameCompany = new Map<String, Lead>();
        for (Lead l : [
            SELECT Id, FirstName, LastName, Email, Company, Country, OwnerId
            FROM Lead
            WHERE LastName IN :lastNames
              AND Company  IN :companies
              AND IsConverted = false
        ]) {
            String key = nameKey(l.FirstName, l.LastName, l.Company);
            existingByNameCompany.put(key, l);
        }

        // Steg 4: Kategorisera varje lead som duplikat eller nytt
        List<Lead>    toUpdate = new List<Lead>();
        List<LeadDTO> toCreate = new List<LeadDTO>();

        for (LeadDTO dto : dtos) {
            if (existingByEmail.containsKey(dto.email)) {
                Lead existing      = existingByEmail.get(dto.email);
                existing.FirstName = dto.firstName;
                existing.LastName  = dto.lastName;
                existing.Company   = dto.company;
                toUpdate.add(existing);

            } else if (existingByNameCompany.containsKey(nameKey(dto.firstName, dto.lastName, dto.company))) {
                Lead existing  = existingByNameCompany.get(nameKey(dto.firstName, dto.lastName, dto.company));
                existing.Email = dto.email;
                toUpdate.add(existing);

            } else {
                toCreate.add(dto);
            }
        }

        // Steg 5: En bulk DML update för alla duplikat
        if (!toUpdate.isEmpty()) {
            update toUpdate;
        }

        // Steg 6: Routing + en bulk DML insert för alla nya leads
        if (!toCreate.isEmpty()) {
            insert buildAndRouteNewLeads(toCreate);
        }
    }

    // Routing - tilldelar säljare till nya leads baserat på territorium och kapacitet
    // Använder "least-loaded" strategi: säljaren med minst aktiva leads får nästa lead.
    // User.Country används som territoriummarkör - bör ersättas med Territory__c i produktion.
    private static List<Lead> buildAndRouteNewLeads(List<LeadDTO> dtos) {

        // Samla alla territorier som förekommer i batchen
        Set<String> territories = new Set<String>();
        for (LeadDTO dto : dtos) {
            if (String.isNotBlank(dto.territory)) territories.add(dto.territory);
        }

        // En SOQL query för att hämta alla eligibla säljare i relevanta territorier
        List<User> allReps = [
            SELECT Id, Country
            FROM User
            WHERE Country  IN :territories
              AND IsActive = true
        ];

        // Gruppera säljar-IDs per territorium för snabb uppslagning
        Map<String, List<Id>> repsByTerritory = new Map<String, List<Id>>();
        for (User u : allReps) {
            if (!repsByTerritory.containsKey(u.Country)) {
                repsByTerritory.put(u.Country, new List<Id>());
            }
            repsByTerritory.get(u.Country).add(u.Id);
        }

        // En aggregat SOQL query för att räkna aktiva leads per säljare
        Set<Id> allRepIds = new Map<Id, User>(allReps).keySet();
        Map<Id, Integer> leadCountByRep = new Map<Id, Integer>();
        for (Id repId : allRepIds) {
            leadCountByRep.put(repId, 0); // initieras till 0 då säljare utan leads inte syns i aggregat query
        }
        for (AggregateResult ar : [
            SELECT OwnerId, COUNT(Id) cnt
            FROM Lead
            WHERE OwnerId     IN :allRepIds
              AND IsConverted = false
            GROUP BY OwnerId
        ]) {
            leadCountByRep.put((Id) ar.get('OwnerId'), (Integer) ar.get('cnt'));
        }

        // Tilldela säljare i minnet - inga fler SOQL queries behövs
        List<Lead> newLeads = new List<Lead>();
        for (LeadDTO dto : dtos) {
            Lead l = new Lead(
                FirstName = dto.firstName,
                LastName  = dto.lastName,
                Email     = dto.email,
                Company   = dto.company,
                Country   = dto.territory,
                Status    = 'Open - Not Contacted'
            );

            List<Id> repsForTerritory = repsByTerritory.get(dto.territory);
            Id bestRep = pickBestRep(repsForTerritory, leadCountByRep);
            if (bestRep != null) {
                l.OwnerId = bestRep;
                // Räknaren uppdateras i minnet så att nästa lead i samma batch ser rätt antal
                leadCountByRep.put(bestRep, leadCountByRep.get(bestRep) + 1);
            }

            newLeads.add(l);
        }

        return newLeads;
    }

    private static Id pickBestRep(List<Id> repIds, Map<Id, Integer> leadCountByRep) {
        if (repIds == null || repIds.isEmpty()) return null;

        Id      bestRep  = null;
        Integer minCount = MAX_ACTIVE_LEADS; // säljaren måste ha strikt färre än MAX

        for (Id repId : repIds) {
            Integer count = leadCountByRep.get(repId);
            if (count < minCount) {
                minCount = count;
                bestRep  = repId;
            }
        }

        return bestRep;
    }

    // Hjälpmetoder

    // Mappar landskoder till territorium-bucket ('US' eller 'EU').
    // I produktion driven av Custom Metadata.
    @TestVisible
    private static String mapToTerritory(String countryCode) {
        if (String.isBlank(countryCode)) return 'EU';
        return US_CODES.contains(countryCode.toUpperCase()) ? 'US' : 'EU';
    }

    // Bygger en unik nyckel av förnamn, efternamn och företag för deduplicering
    private static String nameKey(String first, String last, String company) {
        return first + '|' + last + '|' + company;
    }
}
