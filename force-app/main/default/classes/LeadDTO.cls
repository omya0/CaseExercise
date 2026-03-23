// Normaliserad Lead - det gemensamma formatet som alla tre källor översätts till.
// Fungerar som internt kontrakt mellan normalisering och deduplicering/routing.
public class LeadDTO {
    public String firstName;
    public String lastName;
    public String email;
    public String company;
    public String territory;  // 'US' eller 'EU'
    public String sourceId;   // ursprungligt ID från källsystemet
}
