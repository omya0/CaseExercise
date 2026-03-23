// DTO för källa 3: Third-Party API (extern eventplattform)
// Klassstrukturen speglar den nästlade JSON-strukturen så att JSON.deserialize() kan mappa alla nivåer automatiskt.
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
