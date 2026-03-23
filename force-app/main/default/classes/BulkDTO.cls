// DTO för källa 2: Nightly Bulk CSV (extern marknadsföringsbyrå)
// Fältnamnen matchar JSON-nycklarna exakt (snake_case) så att JSON.deserialize() kan mappa dem automatiskt.
public class BulkDTO {
    public String First_Name;
    public String Last_Name;
    public String Email;
    public String Company;
    public String Region;
    public String Row_ID;
}
