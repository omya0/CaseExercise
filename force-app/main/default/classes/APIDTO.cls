/**
 * DTO for Source 3: Third-Party API (External Event Platform)
 * The class structure mirrors the nested JSON payload exactly
 * so that JSON.deserialize() can map all levels automatically.
 *
 * Raw payload:
 * { "user": { "name": { "first": "...", "last": "..." },
 *             "contact": { "email": "..." } },
 *   "employer": "...",
 *   "location": { "countryCode": "..." },
 *   "eventId": "..." }
 */
public class APIDTO {
    public UserWrapper     user;
    public String          employer;
    public LocationWrapper location;
    public String          eventId;

    public class UserWrapper {
        public NameWrapper    name;
        public ContactWrapper contact;
    }

    public class NameWrapper {
        public String first;
        public String last;
    }

    public class ContactWrapper {
        public String email;
    }

    public class LocationWrapper {
        public String countryCode;
    }
}
