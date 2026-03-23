public with sharing class caseAssignmentMock {
    public caseAssignmentMock() {

    }
    public static String getRealTimeWebhook() {
        return '[' +
            '{' +
                '"firstName": "Jane",' +
                '"lastName": "Doe",' +
                '"emailAddress": "jane.doe@techcorp.com",' +
                '"companyName": "TechCorp",' +
                '"country": "US",' +
                '"campaignId": "camp_123"' +
            '},' +
            '{' +
                '"firstName": "Michael",' +
                '"lastName": "Brown",' +
                '"emailAddress": "michael.brown@innovatex.com",' +
                '"companyName": "InnovateX",' +
                '"country": "CA",' +
                '"campaignId": "camp_124"' +
            '},' +
            '{' +
                '"firstName": "Sara",' +
                '"lastName": "Wilson",' +
                '"emailAddress": "sara.wilson@futurelabs.io",' +
                '"companyName": "FutureLabs",' +
                '"country": "UK",' +
                '"campaignId": "camp_125"' +
            '}' +
        ']';
    }
 
    public static String getNightlyBulk() {
        return '[' +
            '{' +
                '"First_Name": "John",' +
                '"Last_Name": "Smith",' +
                '"Email": "jsmith@globalindustries.co.uk",' +
                '"Company": "Global Industries",' +
                '"Region": "EU",' +
                '"Row_ID": "84729"' +
            '},' +
            '{' +
                '"First_Name": "Emma",' +
                '"Last_Name": "Taylor",' +
                '"Email": "emma.taylor@northwind.se",' +
                '"Company": "Northwind",' +
                '"Region": "SE",' +
                '"Row_ID": "84730"' +
            '},' +
            '{' +
                '"First_Name": "David",' +
                '"Last_Name": "Lee",' +
                '"Email": "david.lee@apexgroup.com",' +
                '"Company": "Apex Group",' +
                '"Region": "APAC",' +
                '"Row_ID": "84731"' +
            '}' +
        ']';
    }
 
    public static String getThirdPartyAPI() {
        return '[' +
            '{' +
                '"user": {' +
                    '"name": {' +
                        '"first": "Alice",' +
                        '"last": "Johnson"' +
                    '},' +
                    '"contact": {' +
                        '"email": "alice.j@startup.io"' +
                    '}' +
                '},' +
                '"employer": "Startup.io",' +
                '"location": {' +
                    '"countryCode": "US"' +
                '},' +
                '"eventId": "evt_998"' +
            '},' +
            '{' +
                '"user": {' +
                    '"name": {' +
                        '"first": "Robert",' +
                        '"last": "Miller"' +
                    '},' +
                    '"contact": {' +
                        '"email": "robert.m@scaleup.ai"' +
                    '}' +
                '},' +
                '"employer": "ScaleUp AI",' +
                '"location": {' +
                    '"countryCode": "DE"' +
                '},' +
                '"eventId": "evt_999"' +
            '},' +
            '{' +
                '"user": {' +
                    '"name": {' +
                        '"first": "Linda",' +
                        '"last": "Garcia"' +
                    '},' +
                    '"contact": {' +
                        '"email": "linda.g@brightworks.com"' +
                    '}' +
                '},' +
                '"employer": "BrightWorks",' +
                '"location": {' +
                    '"countryCode": "FR"' +
                '},' +
                '"eventId": "evt_1000"' +
            '}' +
        ']';
    }
}