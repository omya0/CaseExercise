// Ingestionslager för alla tre datakällor.
// Hämtar JSON, deserialiserar till typad DTO-lista och skickar vidare till service.
// I produktion ersätts mock-anropen med riktiga HTTP callouts.
public with sharing class caseAssignmentController {

    public static void processRealTimeWebhook() {
        String jsonBody = caseAssignmentMock.getRealTimeWebhook();
        try {
            List<RealTimeDTO> records = (List<RealTimeDTO>) JSON.deserialize(jsonBody, List<RealTimeDTO>.class);
            caseAssignmentService.processLeads(records);
        } catch (JSONException e) {
            throw new caseAssignmentException('Invalid JSON from real-time webhook: ' + e.getMessage(), e);
        }
    }

    public static void processNightlyBulk() {
        String jsonBody = caseAssignmentMock.getNightlyBulk();
        try {
            List<BulkDTO> records = (List<BulkDTO>) JSON.deserialize(jsonBody, List<BulkDTO>.class);
            caseAssignmentService.processLeads(records);
        } catch (JSONException e) {
            throw new caseAssignmentException('Invalid JSON from nightly bulk: ' + e.getMessage(), e);
        }
    }

    public static void processThirdPartyApi() {
        String jsonBody = caseAssignmentMock.getThirdPartyAPI();
        try {
            List<APIDTO> records = (List<APIDTO>) JSON.deserialize(jsonBody, List<APIDTO>.class);
            caseAssignmentService.processLeads(records);
        } catch (JSONException e) {
            throw new caseAssignmentException('Invalid JSON from third-party API: ' + e.getMessage(), e);
        }
    }
}
