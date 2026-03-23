// DTO för källa 1: Real-time Webhook (marknadsföringswebbplatsen)
// Fältnamnen matchar JSON-nycklarna exakt så att JSON.deserialize() kan mappa dem automatiskt.
public class RealTimeDTO {
    public String firstName;
    public String lastName;
    public String emailAddress;
    public String companyName;
    public String country;
    public String campaignId;
}
