# Lead Routing & Integration Hub
**Technical Assessment — Junior Salesforce Developer**

A Salesforce Apex backend that ingests lead data from three external sources, normalizes it into a single canonical format, deduplicates against existing records, and intelligently routes each lead to the most suitable Sales Representative.

---

## Architecture

```
caseAssignmentMock          →  returns JSON strings simulating 3 external systems
caseAssignmentController    →  deserializes JSON → typed DTO list → hands off to service
caseAssignmentService       →  normalization → deduplication → routing → upsert
Salesforce Lead / User      →  standard objects used as the data store
```

For a full visual breakdown, see [CLASS_DIAGRAM.md](CLASS_DIAGRAM.md) and [ERD.md](ERD.md).

---

## Classes

| Class | Responsibility |
|-------|---------------|
| `caseAssignmentMock` | Simulates three external data sources by returning hardcoded JSON strings |
| `caseAssignmentController` | Fetches JSON, deserializes it into typed DTOs, delegates to service |
| `RealTimeDTO` | Schema for Source 1 — Real-time Webhook (Marketing Website) |
| `BulkDTO` | Schema for Source 2 — Nightly Bulk CSV (Marketing Agency) |
| `APIDTO` | Schema for Source 3 — Third-Party API (Event Platform, nested structure) |
| `LeadDTO` | Canonical normalized form — internal contract between normalization and deduplication/routing |
| `caseAssignmentService` | Core engine: normalization, deduplication, routing |

---

## How It Works

### 1. Ingestion & Deserialization
The controller fetches a JSON string from the mock layer and deserializes it into a typed DTO list using `JSON.deserialize()`. Each DTO's field names mirror the source JSON keys exactly, acting as a schema for automatic mapping.

### 2. Normalization
The service maps each source-specific DTO into a unified `LeadDTO` with consistent field names. Country/region codes (`"DE"`, `"UK"`, `"CA"` etc.) are mapped to territory buckets (`'US'` or `'EU'`) via `mapToTerritory()`.

### 3. Deduplication
Before any database write, the engine checks for existing records using two criteria:
- **Email match** — exact match on the Email field
- **Name + Company match** — exact match on First Name, Last Name, and Company combined

Duplicate leads are updated rather than inserted. All deduplication is done with **two SOQL queries** covering the entire batch — never one query per lead.

### 4. Routing
New leads are assigned to a Sales Representative based on:
- **Territory** — US leads go to US reps, EU leads to EU reps (`User.Country`)
- **Capacity** — reps holding 5 or more active leads are skipped
- **Distribution** — the rep with the fewest active leads is assigned (least-loaded, round-robin effect)

The in-memory lead counter is incremented after each assignment within a batch, ensuring even distribution without additional database queries.

---

## Bulkification
All entry points accept a `List<>` rather than a single record. The entire pipeline processes a batch with a fixed number of database operations regardless of batch size:

| Operation | Count |
|-----------|-------|
| SOQL — email dedup | 1 |
| SOQL — name+company dedup | 1 |
| SOQL — fetch eligible reps | 1 |
| SOQL — aggregate lead counts | 1 |
| DML update (duplicates) | 1 |
| DML insert (new leads) | 1 |

---

## Extensibility
Adding a fourth data source requires only:
1. A new `FourthSourceDTO.cls` mirroring the new JSON structure
2. A new `normalizeFourthSource()` method in `caseAssignmentService`
3. A new `processLeads(List<FourthSourceDTO>)` entry point in `caseAssignmentService`
4. A new `processFourthSource()` method in `caseAssignmentController`

The deduplication and routing logic requires **zero changes**.

---

## Notes
- `User.Country` is used as a territory marker (`'US'` / `'EU'`) for this prototype. In production this should be a dedicated `Territory__c` custom field on the User object.
- The territory mapping (`mapToTerritory`) currently maps only `'US'` to the US bucket — all other country codes fall into `'EU'`. In production this would be driven by Custom Metadata for maintenance without code deployments.
- No frontend UI is included — this is a backend prototype per the assessment brief.
