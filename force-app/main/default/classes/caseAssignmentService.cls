public with sharing class caseAssignmentService {

    private static final Integer MAX_ACTIVE_LEADS = 5;

    // Territory buckets — country codes not listed here fall into 'EU'.
    // In production this mapping would live in Custom Metadata so it can be
    // maintained without a code deployment.
    private static final Set<String> US_CODES = new Set<String>{ 'US' };

    // Public entry points (one per source type, always accepts a List)

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

    // Normalization

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

    // ─── Bulk orchestration ───────────────────────────────────────────────────

    @TestVisible
    private static void processNormalizedBulk(List<LeadDTO> dtos) {

        // ── Step 1: Collect all dedup keys from the entire batch ──────────────
        Set<String> emails    = new Set<String>();
        Set<String> lastNames = new Set<String>();
        Set<String> companies = new Set<String>();

        for (LeadDTO dto : dtos) {
            if (String.isNotBlank(dto.email))   emails.add(dto.email);
            if (String.isNotBlank(dto.lastName)) lastNames.add(dto.lastName);
            if (String.isNotBlank(dto.company))  companies.add(dto.company);
        }

        // ── Step 2: ONE SOQL to find all email matches ────────────────────────
        Map<String, Lead> existingByEmail = new Map<String, Lead>();
        for (Lead l : [
            SELECT Id, FirstName, LastName, Email, Company, Country, OwnerId
            FROM Lead
            WHERE Email IN :emails
              AND IsConverted = false
        ]) {
            existingByEmail.put(l.Email, l);
        }

        // ── Step 3: ONE SOQL to find all name+company matches ─────────────────
        // We query broadly (LastName IN + Company IN) and filter the exact
        // combination in Apex memory to avoid false positives.
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

        // ── Step 4: Categorise each DTO ───────────────────────────────────────
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

        // ── Step 5: ONE bulk DML to update duplicates ─────────────────────────
        if (!toUpdate.isEmpty()) {
            update toUpdate;
        }

        // ── Step 6: Route + ONE bulk DML to insert new leads ──────────────────
        if (!toCreate.isEmpty()) {
            insert buildAndRouteNewLeads(toCreate);
        }
    }

    // ─── Routing ─────────────────────────────────────────────────────────────

    /**
     * Builds Lead SObjects for all new DTOs and assigns an owner to each
     * using a "least-loaded under capacity" strategy — all in memory after
     * two SOQL queries (one for users, one aggregate for lead counts).
     *
     * Crucially, the in-memory counter is incremented after each assignment
     * so that leads within the same batch are distributed correctly without
     * additional round-trips to the database.
     *
     * NOTE: User.Country = 'US' | 'EU' is used as territory proxy.
     *       In production this should be a dedicated Territory__c custom field.
     */
    private static List<Lead> buildAndRouteNewLeads(List<LeadDTO> dtos) {

        // Collect all territories needed in this batch
        Set<String> territories = new Set<String>();
        for (LeadDTO dto : dtos) {
            if (String.isNotBlank(dto.territory)) territories.add(dto.territory);
        }

        List<User> allReps = [
            SELECT Id, Country
            FROM User
            WHERE Country  IN :territories
              AND IsActive = true
        ];

        // Group rep IDs by territory
        Map<String, List<Id>> repsByTerritory = new Map<String, List<Id>>();
        for (User u : allReps) {
            if (!repsByTerritory.containsKey(u.Country)) {
                repsByTerritory.put(u.Country, new List<Id>());
            }
            repsByTerritory.get(u.Country).add(u.Id);
        }

        // ONE aggregate SOQL: active lead counts for all eligible reps
        Set<Id> allRepIds = new Map<Id, User>(allReps).keySet();
        Map<Id, Integer> leadCountByRep = new Map<Id, Integer>();
        for (Id repId : allRepIds) {
            leadCountByRep.put(repId, 0); // initialise at 0 (reps with no leads won't appear in aggregate)
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

        // Assign owners in memory — no further SOQL needed
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
                // Increment in memory so the next lead in this batch sees the updated count
                leadCountByRep.put(bestRep, leadCountByRep.get(bestRep) + 1);
            }

            newLeads.add(l);
        }

        return newLeads;
    }

    private static Id pickBestRep(List<Id> repIds, Map<Id, Integer> leadCountByRep) {
        if (repIds == null || repIds.isEmpty()) return null;

        Id      bestRep  = null;
        Integer minCount = MAX_ACTIVE_LEADS; // only accept strictly less than MAX

        for (Id repId : repIds) {
            Integer count = leadCountByRep.get(repId);
            if (count < minCount) {
                minCount = count;
                bestRep  = repId;
            }
        }

        return bestRep;
    }

    // ─── Helpers ──────────────────────────────────────────────────────────────

    /**
     * Maps any incoming country/region code to a territory bucket ('US' or 'EU').
     * In production this would be driven by Custom Metadata for easy maintenance.
     */
    @TestVisible
    private static String mapToTerritory(String countryCode) {
        if (String.isBlank(countryCode)) return 'EU';
        return US_CODES.contains(countryCode.toUpperCase()) ? 'US' : 'EU';
    }

    private static String nameKey(String first, String last, String company) {
        return first + '|' + last + '|' + company;
    }
}
