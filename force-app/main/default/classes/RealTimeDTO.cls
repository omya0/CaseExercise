/**
 * DTO for Source 1: Real-time Webhook (Marketing Website)
 * Field names match the JSON payload keys exactly so that
 * JSON.deserialize() can map them automatically.
 *
 * Raw payload:
 * { "firstName": "...", "lastName": "...", "emailAddress": "...",
 *   "companyName": "...", "country": "...", "campaignId": "..." }
 */
public class RealTimeDTO {
    public String firstName;
    public String lastName;
    public String emailAddress;
    public String companyName;
    public String country;
    public String campaignId;
}
