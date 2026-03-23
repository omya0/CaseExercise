# Entity Relationship Diagram — Lead Routing & Integration Hub

```mermaid
erDiagram
    LEAD {
        Id          Id          PK
        String      FirstName
        String      LastName
        String      Email
        String      Company
        String      Country
        String      Status
        Boolean     IsConverted
        Id          OwnerId     FK
    }

    USER {
        Id          Id          PK
        String      FirstName
        String      LastName
        String      Email
        String      Country
        Boolean     IsActive
    }

    LEAD_DTO {
        String      firstName
        String      lastName
        String      email
        String      company
        String      territory
        String      sourceId
    }

    REAL_TIME_DTO {
        String      firstName
        String      lastName
        String      emailAddress
        String      companyName
        String      country
        String      campaignId
    }

    BULK_DTO {
        String      First_Name
        String      Last_Name
        String      Email
        String      Company
        String      Region
        String      Row_ID
    }

    API_DTO {
        String      employer
        String      eventId
        UserWrapper user
        LocationWrapper location
    }

    USER ||--o{ LEAD : "owns (OwnerId)"

    REAL_TIME_DTO ||--|| LEAD_DTO : "normalizes to"
    BULK_DTO      ||--|| LEAD_DTO : "normalizes to"
    API_DTO       ||--|| LEAD_DTO : "normalizes to"

    LEAD_DTO ||--o| LEAD : "upserts to"
```

## Notes

| Fält | Förklaring |
|------|-----------|
| `Lead.Country` | Lagrar territorium ('US' eller 'EU') — normaliserat från källans landskod |
| `Lead.OwnerId` | FK till User — sätts av routing-motorn baserat på territorium och kapacitet |
| `User.Country` | Används som territoriummarkör ('US' eller 'EU') — i produktion ersätts detta av ett dedikerat `Territory__c` custom field |
| `Lead.IsConverted` | Salesforce standard-fält — används för att filtrera bort konverterade leads vid deduplicering och kapacitetsräkning |
| `LeadDTO` | Inte ett databasentitet — en in-memory representation som existerar enbart under normalisering |
