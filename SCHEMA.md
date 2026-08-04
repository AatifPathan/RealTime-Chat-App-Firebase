# OpenCore — Assumed Data Model

This Apex + LWC layer is built against the custom object schema below. Your org
already has "a complete OpenCore Salesforce project" per your brief, so this
document exists as the contract between the Apex controllers and your schema.

**If your actual API names differ, do one of two things:**
1. Rename your fields/objects to match this document, or
2. Send me your real object/field API names and I will regenerate the Apex
   layer against them — the LWC layer will not need to change either way,
   since it only talks to Apex, never to SOQL/object fields directly.

No custom object or field metadata is included in this deliverable (you said
the backend/data model already exists) — only Apex classes and LWC.

## Objects & Fields

### Organization__c
| Field | Type |
|---|---|
| Name | Text (standard) |
| Description__c | Long Text Area |
| Category__c | Text |
| TechStack__c | Text (semicolon-separated, e.g. `TypeScript;Go;Kafka`) |
| Website__c | URL |
| Mentor__c | Lookup(Contributor__c) |

### Repository__c
| Field | Type |
|---|---|
| Name | Text (standard) |
| Organization__c | Lookup(Organization__c) |
| Description__c | Long Text Area |
| Language__c | Text |
| Stars__c | Number |
| Forks__c | Number |
| OpenIssuesCount__c | Number (Roll-Up or Formula from Issue__c; treated as a plain Number field by Apex) |
| Difficulty__c | Picklist: Beginner, Intermediate, Advanced |
| Status__c | Picklist: Active, Archived, Looking for maintainers |
| GithubUrl__c | URL |
| Readme__c | Long Text Area (Rich Text or plain) |

### Project__c
| Field | Type |
|---|---|
| Name | Text (standard) |
| Organization__c | Lookup(Organization__c) |
| Repository__c | Lookup(Repository__c) |
| Description__c | Long Text Area |
| Status__c | Picklist: Planning, In Progress, In Review, Completed |
| Difficulty__c | Picklist: Beginner, Intermediate, Advanced |
| Progress__c | Number (0–100) |
| Mentor__c | Lookup(Contributor__c) |
| Deadline__c | Date |
| TechStack__c | Text (semicolon-separated) |

### Contributor__c
| Field | Type |
|---|---|
| Name | Text (standard) |
| User__c | Lookup(User) — links a Contributor record to the logged-in Salesforce user |
| Organization__c | Lookup(Organization__c) — primary org affiliation (child relationship name `Contributors__r`) |
| Title__c | Text |
| Role__c | Text (e.g. Core Maintainer, Contributor, Reviewer, Mentor) |
| Bio__c | Long Text Area |
| Reputation__c | Number |
| GithubUsername__c | Text |
| NotifyIssueAssignment__c | Checkbox |
| NotifyApplicationUpdates__c | Checkbox |
| NotifyWeeklyDigest__c | Checkbox |
| NotifyMentions__c | Checkbox |
| ThemePreference__c | Picklist: Light, Dark, System |

### Skill__c
| Field | Type |
|---|---|
| Name | Text (standard) |
| Category__c | Text |

### ContributorSkill__c (junction)
| Field | Type |
|---|---|
| Contributor__c | Lookup/Master-Detail(Contributor__c) |
| Skill__c | Lookup(Skill__c) |
| Level__c | Number (0–100) |

### Issue__c
| Field | Type |
|---|---|
| Name | Text (standard, auto-number recommended, e.g. `ISS-{0000}`) |
| Title__c | Text |
| Repository__c | Lookup(Repository__c) |
| Project__c | Lookup(Project__c) |
| Priority__c | Picklist: Low, Medium, High, Critical |
| Status__c | Picklist: Open, In Progress, Needs Review, Closed |
| Difficulty__c | Picklist: Beginner, Intermediate, Advanced |
| Description__c | Long Text Area |
| Requirements__c | Long Text Area |
| AssignedTo__c | Lookup(Contributor__c) |

### Application__c
| Field | Type |
|---|---|
| Contributor__c | Lookup(Contributor__c) |
| Issue__c | Lookup(Issue__c) |
| Project__c | Lookup(Project__c) |
| Status__c | Picklist: Pending, Approved, Rejected |
| AppliedDate__c | Date |

### Badge__c
| Field | Type |
|---|---|
| Name | Text (standard) |
| Description__c | Text |
| Icon__c | Text (a single glyph/character used by the UI, e.g. `★`) |

### ContributorBadge__c (junction)
| Field | Type |
|---|---|
| Contributor__c | Lookup/Master-Detail(Contributor__c) |
| Badge__c | Lookup(Badge__c) |
| EarnedDate__c | Date |

### ActivityLog__c
| Field | Type |
|---|---|
| Contributor__c | Lookup(Contributor__c) |
| Description__c | Text |
| Type__c | Text |
| ActivityDate__c | Date/Time (defaults to CreatedDate if omitted) |

### Notification__c
| Field | Type |
|---|---|
| User__c | Lookup(User) |
| Title__c | Text |
| Description__c | Text |
| Type__c | Text (used to pick an icon/color in the UI: blue/green/amber/purple) |
| IsRead__c | Checkbox |

## Apex conventions used throughout
- Every read method is `@AuraEnabled(cacheable=true)` and returns a small DTO
  (`...Item`, `...Result`) rather than raw sObjects, so LWC markup never binds
  directly to `Field__c` API names — this keeps the UI decoupled from schema.
- Every DML method (`applyToIssue`, `approveApplication`, `saveSettings`, etc.)
  is `@AuraEnabled` (not cacheable) and calls `refreshApex`-friendly patterns
  from the LWC side.
- All dynamic SOQL (sorting/filtering) uses an **allow-list** of field names —
  never raw string concatenation of user input — to prevent SOQL injection.
- `with sharing` is used on every controller.
