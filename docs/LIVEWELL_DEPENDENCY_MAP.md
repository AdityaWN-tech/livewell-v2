# LiveWell V2 — Dependency Map

Arrows mean "must be done first". Per-task dependencies are also in the master tracker.

## Critical paths

```mermaid
flowchart LR
  subgraph Existing app
    AGT02[AGT-02 ✔] --> AGT04[AGT-04 Coach Agent]
    AGT03[AGT-03 ✔ dev] --> AGT04
    AGT04 --> DLY01[DLY-01/03/05 AI parts]
    AGT04 --> CNV[CNV-01/02 chat + voice]
    AGT04 --> AGT05[AGT-05 Memory]
    AGT04 --> AGT06[AGT-06 Insights] --> DLY07[DLY-07 weekly review]
    AGT04 --> AGT07[AGT-07 Portal agent]
    PRT02[PRT-02 PR #105] --> AGT07
    PRT01[PRT-01 TagMango ⛔] --> PRT04[PRT-04..07]
    ASM01[ASM-01 question bank ⛔] --> ASM03[ASM-03]
    VOC01[VOC-01 voice vendor ⛔] --> VOC[VOC-03..06]
    VOC01 --> CNV
  end
  subgraph Hierarchy
    D97[IAM-00 decision D-97 ⛔] --> IAM01[IAM-01 roles]
    D97 --> IAM02[IAM-02 org model]
    PRT02 --> IAM01
    IAM01 --> IAM03[IAM-03 rules]
    IAM02 --> IAM03
    IAM01 --> IAM04[IAM-04 API guard]
    IAM01 --> IAM05[IAM-05 superadmin provisioning]
    FND09[FND-09 audit PR #97] --> IAM05
    IAM04 --> SAD[SAD-01..04 Superadmin]
    FND11[FND-11 flags PR #85] --> SAD
    FND10[FND-10 PR #94] --> SAD
    IAM04 --> ORG[ORG-01/02 Admin]
    IAM03 --> ORG
    IAM02 --> INV01[INV-01 invitations]
    IAM04 --> INV01
    INV01 --> INV02[INV-02 allowlist]
    BLAZE[Blaze + Identity Platform ⛔] --> INV02
    INV02 --> INV03[INV-03 mobile join]
    IAM04 --> PRM01[PRM-01 permissions]
    FND11 --> PRM01
    PRM01 --> PRM02[PRM-02 mobile gating]
    PRM01 --> PRM03[PRM-03 authz everywhere]
    IAM03 --> PRM03
    PRM03 --> SEC01[SEC-01 security suite] --> CMP04[CMP-04 pen test] --> REL02[REL-02 release]
  end
```

⛔ = blocked on a person, vendor or decision.

## Cross-links between existing and new work

| Existing | New | Link |
|---|---|---|
| PRT-02 staff roles (PR #105) | IAM-01 | Rename staff `admin`, add superadmin/org roles. Merge #105 first, then extend. |
| FND-06 rules | IAM-03 | Same rules file and coverage gate. |
| FND-07 migration (PR #96) | IAM-02 | Same migration tooling; org backfill is a new dry-run migration. |
| FND-09 audit (PR #97) | IAM-05, SAD-04 | New admin action names must be allow-listed. |
| FND-10 monitoring (PR #94) | SAD-03 | Dashboards build on it. |
| FND-11 flags (PR #85) | SAD-02, PRM-01 | Global flags become the base layer. |
| FND-04 shell | PRM-02 | Router and tab guards. |
| ONB-01 sign-in | INV-03 | Join flow inserted before onboarding; conflict with open sign-up. |
| AGT-01 service | PRM-03 | Endpoints check org/permission. |
| CMP-01 legal texts | IAM-00 | Terms/Privacy must describe the Admin role. |
| CMP-04 pen test | SEC-01 | Scope grows. |
| REL-02 store release | INV-03 | Invite-only app review (demo account). |

## Independent streams (safe to run in parallel)

1. **Existing app stream:** AGT-04 → AGT-05/06/07, DLY/CNV AI parts (Python agents + app).
2. **Review stream:** owner reviews and merges the 24 open PRs (no new code).
3. **Hierarchy stream:** starts only after D-97; IAM-01/02 touch Core API, rules and data model, not the agents. Conflicts with stream 1 are limited to `firebase/firestore.rules` and the data model, so rule changes go in small PRs.
