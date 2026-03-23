@isTest
private class caseAssignmentServiceTest {

    @TestSetup
    static void setup() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        insert new List<User>{
            buildUser('US_Rep_One', 'US', p.Id),
            buildUser('US_Rep_Two', 'US', p.Id),
            buildUser('EU_Rep_One', 'EU', p.Id)
        };
    }

    private static User buildUser(String alias, String country, Id profileId) {
        String unique = alias + DateTime.now().getTime();
        return new User(
            FirstName         = alias,
            LastName          = 'TestRep',
            Email             = unique + '@test.salesforce.com',
            Username          = unique + '@test.salesforce.com',
            Alias             = alias.left(8),
            TimeZoneSidKey    = 'America/New_York',
            LocaleSidKey      = 'en_US',
            EmailEncodingKey  = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId         = profileId,
            Country           = country
        );
    }

    // ─── Territory mapping ────────────────────────────────────────────────────

    @isTest
    static void mapToTerritory_usCodeReturnsUS() {
        System.assertEquals('US', caseAssignmentService.mapToTerritory('US'));
    }

    @isTest
    static void mapToTerritory_nonUsCodeReturnsEU() {
        System.assertEquals('EU', caseAssignmentService.mapToTerritory('DE'));
        System.assertEquals('EU', caseAssignmentService.mapToTerritory('UK'));
        System.assertEquals('EU', caseAssignmentService.mapToTerritory('CA'));
        System.assertEquals('EU', caseAssignmentService.mapToTerritory('APAC'));
    }

    @isTest
    static void mapToTerritory_blankReturnsEU() {
        System.assertEquals('EU', caseAssignmentService.mapToTerritory(null));
        System.assertEquals('EU', caseAssignmentService.mapToTerritory(''));
    }

    // ─── Normalization ────────────────────────────────────────────────────────

    @isTest
    static void normalizeRealTime_mapsAllFields() {
        RealTimeDTO dto = new RealTimeDTO();
        dto.firstName    = 'Jane';
        dto.lastName     = 'Doe';
        dto.emailAddress = 'jane@test.com';
        dto.companyName  = 'TestCorp';
        dto.country      = 'US';
        dto.campaignId   = 'camp_1';

        Test.startTest();
        LeadDTO result = caseAssignmentService.normalizeRealTime(dto);
        Test.stopTest();

        System.assertEquals('Jane',          result.firstName);
        System.assertEquals('Doe',           result.lastName);
        System.assertEquals('jane@test.com', result.email);
        System.assertEquals('TestCorp',      result.company);
        System.assertEquals('US',            result.territory);
        System.assertEquals('camp_1',        result.sourceId);
    }

    @isTest
    static void normalizeBulk_mapsAllFields() {
        BulkDTO dto  = new BulkDTO();
        dto.First_Name = 'John';
        dto.Last_Name  = 'Smith';
        dto.Email      = 'john@test.com';
        dto.Company    = 'SmithCo';
        dto.Region     = 'EU';
        dto.Row_ID     = '999';

        Test.startTest();
        LeadDTO result = caseAssignmentService.normalizeBulk(dto);
        Test.stopTest();

        System.assertEquals('John',          result.firstName);
        System.assertEquals('Smith',         result.lastName);
        System.assertEquals('john@test.com', result.email);
        System.assertEquals('SmithCo',       result.company);
        System.assertEquals('EU',            result.territory);
        System.assertEquals('999',           result.sourceId);
    }

    @isTest
    static void normalizeApi_mapsAllFields() {
        APIDTO dto                    = new APIDTO();
        APIDTO.UserWrapper user       = new APIDTO.UserWrapper();
        APIDTO.NameWrapper name       = new APIDTO.NameWrapper();
        APIDTO.ContactWrapper contact = new APIDTO.ContactWrapper();
        APIDTO.LocationWrapper loc    = new APIDTO.LocationWrapper();

        name.first      = 'Alice';
        name.last       = 'Johnson';
        contact.email   = 'alice@test.com';
        user.name       = name;
        user.contact    = contact;
        loc.countryCode = 'US';
        dto.user        = user;
        dto.employer    = 'Startup.io';
        dto.location    = loc;
        dto.eventId     = 'evt_1';

        Test.startTest();
        LeadDTO result = caseAssignmentService.normalizeApi(dto);
        Test.stopTest();

        System.assertEquals('Alice',          result.firstName);
        System.assertEquals('Johnson',        result.lastName);
        System.assertEquals('alice@test.com', result.email);
        System.assertEquals('Startup.io',     result.company);
        System.assertEquals('US',             result.territory);
        System.assertEquals('evt_1',          result.sourceId);
    }

    // ─── Deduplication ────────────────────────────────────────────────────────

    @isTest
    static void deduplication_byEmail_updatesExistingRecord() {
        insert new Lead(
            FirstName = 'Old', LastName = 'Name',
            Email = 'jane@test.com', Company = 'OldCorp',
            Status = 'Open - Not Contacted'
        );

        RealTimeDTO dto  = new RealTimeDTO();
        dto.firstName    = 'Jane';
        dto.lastName     = 'Doe';
        dto.emailAddress = 'jane@test.com';
        dto.companyName  = 'NewCorp';
        dto.country      = 'US';
        dto.campaignId   = 'camp_1';

        Test.startTest();
        caseAssignmentService.processLeads(new List<RealTimeDTO>{ dto });
        Test.stopTest();

        System.assertEquals(1, [SELECT COUNT() FROM Lead WHERE Email = 'jane@test.com'],
            'Should update existing record, not insert a new one');
        Lead updated = [SELECT FirstName, Company FROM Lead WHERE Email = 'jane@test.com'];
        System.assertEquals('Jane',    updated.FirstName);
        System.assertEquals('NewCorp', updated.Company);
    }

    @isTest
    static void deduplication_byNameAndCompany_updatesExistingRecord() {
        insert new Lead(
            FirstName = 'John', LastName = 'Smith',
            Email = 'old@test.com', Company = 'Global Industries',
            Status = 'Open - Not Contacted'
        );

        BulkDTO dto  = new BulkDTO();
        dto.First_Name = 'John';
        dto.Last_Name  = 'Smith';
        dto.Email      = 'new@test.com';
        dto.Company    = 'Global Industries';
        dto.Region     = 'EU';
        dto.Row_ID     = '84729';

        Test.startTest();
        caseAssignmentService.processLeads(new List<BulkDTO>{ dto });
        Test.stopTest();

        System.assertEquals(1, [SELECT COUNT() FROM Lead
            WHERE FirstName = 'John' AND LastName = 'Smith' AND Company = 'Global Industries'],
            'Should update existing record, not insert a new one');
        Lead updated = [SELECT Email FROM Lead WHERE FirstName = 'John' AND LastName = 'Smith'];
        System.assertEquals('new@test.com', updated.Email);
    }

    // ─── Routing ─────────────────────────────────────────────────────────────

    @isTest
    static void routing_usLeadGoesToUsRep() {
        RealTimeDTO dto  = new RealTimeDTO();
        dto.firstName    = 'Test';
        dto.lastName     = 'Lead';
        dto.emailAddress = 'test@us.com';
        dto.companyName  = 'US Co';
        dto.country      = 'US';
        dto.campaignId   = 'c1';

        Test.startTest();
        caseAssignmentService.processLeads(new List<RealTimeDTO>{ dto });
        Test.stopTest();

        Lead inserted = [SELECT OwnerId FROM Lead WHERE Email = 'test@us.com'];
        User owner    = [SELECT Country FROM User WHERE Id = :inserted.OwnerId];
        System.assertEquals('US', owner.Country, 'US lead must be assigned to a US-territory rep');
    }

    @isTest
    static void routing_euLeadGoesToEuRep() {
        BulkDTO dto  = new BulkDTO();
        dto.First_Name = 'EU';
        dto.Last_Name  = 'Lead';
        dto.Email      = 'eu@test.com';
        dto.Company    = 'EuCo';
        dto.Region     = 'EU';
        dto.Row_ID     = 'row_1';

        Test.startTest();
        caseAssignmentService.processLeads(new List<BulkDTO>{ dto });
        Test.stopTest();

        Lead inserted = [SELECT OwnerId FROM Lead WHERE Email = 'eu@test.com'];
        User owner    = [SELECT Country FROM User WHERE Id = :inserted.OwnerId];
        System.assertEquals('EU', owner.Country, 'EU lead must go to EU rep');
    }

    @isTest
    static void routing_skipsRepAtMaxCapacity() {
        User repOne = [SELECT Id FROM User WHERE FirstName = 'US_Rep_One' LIMIT 1];
        User repTwo = [SELECT Id FROM User WHERE FirstName = 'US_Rep_Two' LIMIT 1];

        List<Lead> preload = new List<Lead>();
        for (Integer i = 0; i < 5; i++) {
            preload.add(new Lead(
                FirstName = 'Full', LastName = 'Cap' + i,
                Email = 'cap' + i + '@test.com', Company = 'CapCo',
                Status = 'Open - Not Contacted', OwnerId = repOne.Id
            ));
        }
        insert preload;

        RealTimeDTO dto  = new RealTimeDTO();
        dto.firstName    = 'New';
        dto.lastName     = 'Lead';
        dto.emailAddress = 'new@test.com';
        dto.companyName  = 'NewCo';
        dto.country      = 'US';
        dto.campaignId   = 'c3';

        Test.startTest();
        caseAssignmentService.processLeads(new List<RealTimeDTO>{ dto });
        Test.stopTest();

        Lead newLead = [SELECT OwnerId FROM Lead WHERE Email = 'new@test.com'];
        System.assertEquals(repTwo.Id, newLead.OwnerId,
            'Rep one is at capacity so rep two should be assigned');
    }

    @isTest
    static void routing_distributesEvenlyWithinBatch() {
        User repOne = [SELECT Id FROM User WHERE FirstName = 'US_Rep_One' LIMIT 1];
        User repTwo = [SELECT Id FROM User WHERE FirstName = 'US_Rep_Two' LIMIT 1];

        RealTimeDTO dto1  = new RealTimeDTO();
        dto1.firstName    = 'First';
        dto1.lastName     = 'Lead';
        dto1.emailAddress = 'first@test.com';
        dto1.companyName  = 'Co1';
        dto1.country      = 'US';
        dto1.campaignId   = 'c1';

        RealTimeDTO dto2  = new RealTimeDTO();
        dto2.firstName    = 'Second';
        dto2.lastName     = 'Lead';
        dto2.emailAddress = 'second@test.com';
        dto2.companyName  = 'Co2';
        dto2.country      = 'US';
        dto2.campaignId   = 'c2';

        Test.startTest();
        caseAssignmentService.processLeads(new List<RealTimeDTO>{ dto1, dto2 });
        Test.stopTest();

        Set<Id> ownerIds = new Set<Id>();
        for (Lead l : [SELECT OwnerId FROM Lead WHERE Email IN ('first@test.com','second@test.com')]) {
            ownerIds.add(l.OwnerId);
        }
        System.assertEquals(2, ownerIds.size(),
            'Two leads in one batch should go to two different reps');
    }
}
