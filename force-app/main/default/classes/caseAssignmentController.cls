// Ingestionslager för alla tre datakällor.
// Hämtar JSON, deserialiserar till typad DTO-lista och skickar vidare till service.
// I produktion ersätts mock-anropen med riktiga HTTP callouts.
public with sharing class caseAssignmentController {

    public static void processRealTimeWebhook() {
        String jsonBody = caseAssignmentMock.getRealTimeWebhook();
        List<RealTimeDTO> records = (List<RealTimeDTO>) JSON.deserialize(jsonBody, List<RealTimeDTO>.class);
        caseAssignmentService.processLeads(records);
    }

    public static void processNightlyBulk() {
        String jsonBody = caseAssignmentMock.getNightlyBulk();
        List<BulkDTO> records = (List<BulkDTO>) JSON.deserialize(jsonBody, List<BulkDTO>.class);
        caseAssignmentService.processLeads(records);
    }

    public static void processThirdPartyApi() {
        String jsonBody = caseAssignmentMock.getThirdPartyAPI();
        List<APIDTO> records = (List<APIDTO>) JSON.deserialize(jsonBody, List<APIDTO>.class);
        caseAssignmentService.processLeads(records);
    }
}
