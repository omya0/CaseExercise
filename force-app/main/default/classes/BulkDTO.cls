/**
 * DTO for Source 2: Nightly Bulk CSV (External Marketing Agency)
 * Field names match the JSON payload keys exactly (snake_case with capitals)
 * so that JSON.deserialize() can map them automatically.
 *
 * Raw payload:
 * { "First_Name": "...", "Last_Name": "...", "Email": "...",
 *   "Company": "...", "Region": "...", "Row_ID": "..." }
 */
public class BulkDTO {
    public String First_Name;
    public String Last_Name;
    public String Email;
    public String Company;
    public String Region;
    public String Row_ID;
}
