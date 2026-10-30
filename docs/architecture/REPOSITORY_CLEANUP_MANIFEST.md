# DRIVEGO — REPOSITORY CLEANUP MANIFEST & FILE DISPOSITION
## File-by-File Classification, Purge Records & Target Directory Architecture

> **Document Reference**: `docs/architecture/REPOSITORY_CLEANUP_MANIFEST.md`  
> **Classification**: Repository Structure & Hygiene Standard  
> **Status**: APPROVED — PRODUCTION BLUEPRINT  
> **Author**: DriveGo Repository Governance & DevSecOps Directorate  

---

## 1. CLASSIFICATION TAXONOMY

Every file and directory in DriveGo is classified under a strict 6-tier taxonomy:

| Classification | Definition | Disposition Action |
|---|---|---|
| **`KEEP`** | Essential production code, models, controllers, tests, migrations, and CI workflows. | Strictly preserved. |
| **`KEEP_AND_REORGANIZE`**| Valid documentation or assets previously in suboptimal paths. | Relocated with verified links. |
| **`SAFE_TO_REMOVE`** | Redundant copies, orphaned screenshots, obsolete ad-hoc debug scripts. | Purged safely. |
| **`REQUIRES_DECISION`** | Architectural proposals requiring corporate legal sign-off. | Documented with explicit decisions. |
| **`GENERATED_OR_IGNORED`**| Build caches, compiled bytecode, dependency trees covered by `.gitignore`. | Excluded from version control. |
| **`LEGACY_REQUIRES_MIGRATION`**| Superseded audit memos preserved for historical audit trails. | Archived in `docs/archive/`. |

---

## 2. DISPOSITION & PURGE RECORD

### 2.1 Purged Items (Total: > 7.1 Gigabytes Freed)
1. **Flutter Build Artifacts (`apps/*/build`)**: Executed `flutter clean` across all 3 client applications, removing **6.45 Gigabytes** of bloated intermediate Gradle caches and web compilation objects.
2. **Untracked Developer Scratch (`scratch/`)**: Permanently removed **675 Megabytes** of obsolete unpacked APKs, Chrome user profiles, and ad-hoc debug screenshots from past manual test runs.
3. **Backend Root Debug Scripts**: Safely purged 17 obsolete, untracked scripts in `car_rental_backend/` (`check_*.js`, `query_*.js`, `test_hash*.js`, `pg_logfile.log`, `dump.rdb`, `.latest_otp.json`).
4. **Root Image Clutter**: Removed unreferenced root screenshot `admin_web.png` and test state `.latest_otp.json`.

### 2.2 Reorganized Documentation
- Reorganized historical loose documents from `docs/` into [`docs/archive/historical_reports/`](file:///d:/Flutter/car_rental_monorepo/docs/archive/historical_reports), preserving all tracked git files while establishing a clean, structured documentation directory.

---

## 3. TARGET REPOSITORY DIRECTORY LAYOUT

```
d:/Flutter/car_rental_monorepo/
├── .github/workflows/          # Production CI/CD pipelines (Flutter & NestJS)
├── apps/
│   ├── customer_app/           # Flutter Customer App (Android, iOS, Web)
│   ├── vendor_app/             # Flutter Fleet Partner App (Android, iOS)
│   └── admin_panel/            # Flutter Admin Control Tower (Desktop Web)
├── car_rental_backend/
│   ├── prisma/                 # PostgreSQL schema (58 models) & migrations
│   └── src/                    # NestJS modular architecture
├── packages/
│   ├── core/                   # Automotive Design System (DDS) tokens
│   ├── models/                 # Immutable Freezed domain models
│   ├── ui_kit/                 # Standardized automotive UI components
│   └── mock_data/              # Test harness mock fixtures (isolated)
├── docs/
│   ├── architecture/           # Master authoritative architectural blueprints
│   ├── audits/                 # Master governance requirements & compliance
│   ├── evidence/               # Visual forensic screenshot evidence
│   └── archive/                # Historical audit archives
├── requirements/               # Original PRD/TRD requirement specifications
├── nginx/                      # Turnkey edge reverse proxy configuration
├── docker-compose.production.yml # Turnkey multi-container production stack
├── docker-compose.staging.yml    # Staging container stack
├── melos.yaml                  # Monorepo workspace orchestration
└── README.md                   # Authoritative repository onboarding guide
```

---
*Ratified by DriveGo Repository Governance & DevSecOps Directorate.*

