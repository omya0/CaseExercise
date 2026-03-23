/**
 * Normalized Lead — the single canonical representation produced by
 * all three normalizer methods in caseAssignmentService.
 * This is the internal contract between normalization and the
 * deduplication / routing engine.
 */
public class LeadDTO {
    public String firstName;
    public String lastName;
    public String email;
    public String company;
    public String territory;  // 'US' or 'EU'
    public String sourceId;   // original identifier from the source system
}
