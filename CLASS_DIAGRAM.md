# UML Class Diagram — Lead Routing & Integration Hub

```mermaid
classDiagram

    class caseAssignmentMock {
        +getRealTimeWebhook() String
        +getNightlyBulk() String
        +getThirdPartyAPI() String
    }

    class caseAssignmentController {
        +processRealTimeWebhook() void
        +processNightlyBulk() void
        +processThirdPartyApi() void
    }

    class RealTimeDTO {
        +String firstName
        +String lastName
        +String emailAddress
        +String companyName
        +String country
        +String campaignId
    }

    class BulkDTO {
        +String First_Name
        +String Last_Name
        +String Email
        +String Company
        +String Region
        +String Row_ID
    }

    class APIDTO {
        +UserWrapper user
        +String employer
        +LocationWrapper location
        +String eventId
    }

    class LeadDTO {
        +String firstName
        +String lastName
        +String email
        +String company
        +String territory
        +String sourceId
    }

    class caseAssignmentService {
        -Integer MAX_ACTIVE_LEADS
        -Set~String~ US_CODES
        +processLeads(List~RealTimeDTO~) void
        +processLeads(List~BulkDTO~) void
        +processLeads(List~APIDTO~) void
        -normalizeRealTime(RealTimeDTO) LeadDTO
        -normalizeBulk(BulkDTO) LeadDTO
        -normalizeApi(APIDTO) LeadDTO
        -processNormalizedBulk(List~LeadDTO~) void
        -buildAndRouteNewLeads(List~LeadDTO~) List~Lead~
        -pickBestRep(List~Id~, Map) Id
        -mapToTerritory(String) String
        -nameKey(String, String, String) String
    }

    class Lead {
        +Id Id
        +String FirstName
        +String LastName
        +String Email
        +String Company
        +String Country
        +String Status
        +Boolean IsConverted
        +Id OwnerId
    }

    class User {
        +Id Id
        +String FirstName
        +String LastName
        +String Email
        +String Country
        +Boolean IsActive
    }

    caseAssignmentController --> caseAssignmentMock       : hämtar JSON
    caseAssignmentController --> RealTimeDTO              : deserialiserar till
    caseAssignmentController --> BulkDTO                  : deserialiserar till
    caseAssignmentController --> APIDTO                   : deserialiserar till
    caseAssignmentController --> caseAssignmentService    : anropar processLeads()

    caseAssignmentService --> RealTimeDTO                 : normaliserar
    caseAssignmentService --> BulkDTO                     : normaliserar
    caseAssignmentService --> APIDTO                      : normaliserar
    caseAssignmentService --> LeadDTO                     : producerar
    caseAssignmentService --> Lead                        : upsert
    caseAssignmentService --> User                        : hämtar för routing

    Lead --> User                                         : OwnerId (FK)
```

## Förklaring av notation

| Symbol | Betydelse |
|--------|-----------|
| `+` | public |
| `-` | private |
| `-->` | beroende / anropar |
| `~Type~` | generisk typ, t.ex. `List<String>` |
