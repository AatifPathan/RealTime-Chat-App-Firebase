# OpenCore — Real Org Schema (reconciled)

This replaces `SCHEMA.md`. That file documented a schema I *assumed* before
you'd shared your actual org. You've now uploaded a metadata retrieve
(`objects/`, `classes/`, `lwc/`, `tabs/`, `flexipages/`) and the real schema
is meaningfully different — this doc reflects what's actually in your org,
and the design decisions made to bridge it to the existing LWC layer.

## Key structural differences from my original assumption

- **`Mentor__c` is its own object**, not a role on `Contributor__c`. Mentors
  review applications/contributions, own projects (`Project_Manager__c`),
  and lead organizations (`Organization__c.Primary_Mentor__c`).
- **No `Notification__c` object.** Per your "don't regenerate objects"
  instruction, `NotificationController` now *synthesizes* a feed from real
  records (recently-reviewed `Application__c`, recently-awarded `Badge__c`,
  recently-reviewed `Contribution__c`) instead of reading a dedicated object.
  Read/unread state is **not persisted** — there's no field for it — so
  "mark as read" is a local, session-only UI state now (see `notifications.js`).
- **No link from `Contributor__c`/`Mentor__c` to `User`.** I resolve "the
  current logged-in person's record" via `OwnerId = UserInfo.getUserId()`.
  This assumes each Contributor/Mentor record's Owner is set to the
  matching Salesforce/Experience Cloud user. If your data doesn't follow
  that convention, tell me the real linking field and I'll swap it in one
  place (`ContributorController.getCurrentContributorId()` /
  `MentorController.getCurrentMentorId()`).
- **Reputation, rank, and badges are trigger-maintained**, not computed by
  my controllers. `ContributionTriggerHandler` → `ContributorService` /
  `BadgeService` already update `Contributor__c.Reputation_Score__c`,
  `Current_Rank__c`, `Total_Contributions__c`, and insert `Badge__c` rows
  whenever a `Contribution__c` is inserted/updated. My controllers only
  **read** these — they never recompute them.
- **`Issue__c` has no `AssignedTo__c`.** "Who's working an issue" is derived
  from `Contribution__c`/`Application__c`, not a direct lookup.
- **No `Readme__c`, `TechStack__c` (on Project), or `Difficulty__c` (on
  Project) fields.** Where the UI needs these, the controller composes them
  from real fields it does have (see per-object notes below) rather than
  inventing new fields.
- **`Contributor_Skill__c.Proficiency_Level__c` is a picklist**
  (Beginner/Intermediate/Advanced/Expert), not a 0–100 number. Mapped to a
  percentage for the existing progress-bar UI: 25/50/75/100.
- **Settings**: real `Contributor__c` has no notification-preference or
  theme-preference fields. Those two tabs in Settings now hold **local,
  browser-session-only** state (clearly not persisted) instead of pretending
  to save to Salesforce. Profile fields that *do* exist (`Bio__c`,
  `GitHub_Username__c`) still save for real.

## Object → controller field mapping (abbreviated, see Apex for full detail)

| DTO field | Real source |
|---|---|
| Repository language | `Primary_Language__c` |
| Repository status | `Status__c` (Active / Archived / Under Maintenance) |
| Repository open issues | `Open_Issues__c` (trigger-maintained) |
| Repository "readme" | Composed from `Description__c`, `Topics__c`, `License__c`, `Visibility__c`, `Last_Synced__c` — there's no dedicated readme field |
| Org repo/contributor counts | `Total_Repositories__c` / `Active_Contributors__c` (trigger-maintained, read directly) |
| Org "category" | First tag from `Technology_Stack__c` (no dedicated category field) |
| Project progress % | Computed live: closed vs. total `Issue__c` across the project's repositories |
| Project difficulty | Most common `Difficulty_Level__c` among the project's repositories (no field on Project itself) |
| Project tech stack | Distinct `Primary_Language__c` values from the project's repositories |
| Contributor "role" text | `Experience_Level__c` + `Current_Rank__c` (e.g. "Advanced · Gold") |
| Contribution timeline / activity feed | `Contribution__c` (real commit/PR-style records) — replaces the fictional `ActivityLog__c` from before |
| Badge catalog (locked/unlocked) | The 8 real `Badge_Type__c` picklist values; progress for the 4 auto-awarded types (First Contribution/Top Contributor/Open Source Champion/Community Helper) is computed from `Total_Contributions__c` against the real thresholds in `BadgeService.awardBadges` (1 / 5 / 25 / 50) |

## Untouched (out of scope, left exactly as you built them)
`*API.cls` (REST endpoints), `*SOAPService.cls`, `GitHubService`/
`GitHubSyncController` (external GitHub sync), all `*TriggerHandler.cls`,
all `*Service.cls`. The new/extended controllers call into these where it
made sense (e.g. a "Sync from GitHub" button now calls your existing
`GitHubSyncController.syncRepository`) but nothing in that layer was modified.
