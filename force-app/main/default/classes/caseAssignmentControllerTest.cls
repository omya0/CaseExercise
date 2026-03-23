@isTest
private class caseAssignmentControllerTest {

    @TestSetup
    static void setup() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        insert new List<User>{
            buildUser('Ctrl_US_One', 'US', p.Id),
            buildUser('Ctrl_US_Two', 'US', p.Id),
            buildUser('Ctrl_EU_One', 'EU', p.Id),
            buildUser('Ctrl_EU_Two', 'EU', p.Id)
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

    @isTest
    static void processRealTimeWebhook_createsLeadsFromWebhookJson() {
        Test.startTest();
        caseAssignmentController.processRealTimeWebhook();
        Test.stopTest();

        System.assertEquals(3, [SELECT COUNT() FROM Lead],
            'Three leads from the webhook JSON should be created');
    }

    @isTest
    static void processNightlyBulk_createsLeadsFromCsvJson() {
        Test.startTest();
        caseAssignmentController.processNightlyBulk();
        Test.stopTest();

        System.assertEquals(3, [SELECT COUNT() FROM Lead],
            'Three leads from the bulk CSV JSON should be created');
    }

    @isTest
    static void processThirdPartyApi_createsLeadsFromApiJson() {
        Test.startTest();
        caseAssignmentController.processThirdPartyApi();
        Test.stopTest();

        System.assertEquals(3, [SELECT COUNT() FROM Lead],
            'Three leads from the third-party API JSON should be created');
    }

    @isTest
    static void allSources_allLeadsAreAssigned() {
        Test.startTest();
        caseAssignmentController.processRealTimeWebhook();
        caseAssignmentController.processNightlyBulk();
        caseAssignmentController.processThirdPartyApi();
        Test.stopTest();

        Integer unassigned = [SELECT COUNT() FROM Lead WHERE OwnerId = null];
        System.assertEquals(0, unassigned,
            'Every lead should have an assigned owner after processing all sources');
    }
}
