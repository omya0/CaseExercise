/**
 * caseAssignmentController
 *
 * Acts as the ingestion layer for all three lead sources.
 * Each method fetches a JSON string from the mock layer, deserializes it
 * into a typed DTO list, and hands it off to the service for processing.
 *
 * In production each method would call the real external system instead
 * of caseAssignmentMock — the service layer requires no changes.
 */
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
