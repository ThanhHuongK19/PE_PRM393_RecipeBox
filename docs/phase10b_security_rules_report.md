# Phase 10B: Firestore Security Rules verification

Date: 2026-11-03  
Target project: `prm393-final`

## Summary

- Local `firestore.rules` was loaded by the Firebase Emulator Suite. **52/52 emulator checks passed.**
- The exact workspace `firestore.rules` file was deployed to production after approval; the published Rules API content hash matched the workspace file.
- Production Auth identified the configured test account and the owner-scoped recipe query returned only documents belonging to its UID.
- A production smoke test using a disposable client-authenticated test account successfully created and read an owned recipe, rejected a case-insensitive duplicate with HTTP 403, then deleted the recipe and its claim. The temporary account was also deleted.
- The earlier valid-create HTTP 403 was resolved by publishing the workspace rules. The smoke test created no lasting test records.

## Emulator test checklist

Each PASS means the actual result matched the expected result. Denied operations returned HTTP 403; successful owner operations returned HTTP 200.

| Test | Expected | Actual | Status |
|---|---|---|---|
| Unauthenticated read one recipe | Denied | HTTP 403 | PASS |
| Unauthenticated list recipes | Denied | HTTP 403 | PASS |
| Unauthenticated create recipe and claim | Denied | HTTP 403 | PASS |
| Unauthenticated update owner fixture | Denied | HTTP 403 | PASS |
| Unauthenticated delete owner fixture and claim | Denied | HTTP 403 | PASS |
| Account A reads its own recipe | Allowed | HTTP 200 | PASS |
| Account A creates its own recipe with a claim | Allowed | HTTP 200 | PASS |
| Account A updates its own recipe | Allowed | HTTP 200; updated values read back | PASS |
| Account A deletes its own recipe and claim | Allowed | HTTP 200; document no longer readable | PASS |
| Account B reads Account A's recipe | Denied | HTTP 403 | PASS |
| Account B updates Account A's recipe | Denied | HTTP 403 | PASS |
| Account B deletes Account A's recipe | Denied | HTTP 403 | PASS |
| Account B queries Account A's recipes | Denied | HTTP 403 | PASS |
| Cross-user attempts leave Account A's recipe intact | Recipe remains | Owner read returned HTTP 200 | PASS |
| Account A creates a recipe with Account B's UID | Denied | HTTP 403 | PASS |
| Empty name | Denied | HTTP 403 | PASS |
| Name containing spaces only | Denied | HTTP 403 | PASS |
| Name longer than 80 characters | Denied | HTTP 403 | PASS |
| Invalid category | Denied | HTTP 403 | PASS |
| Invalid difficulty | Denied | HTTP 403 | PASS |
| Missing `cookTime` | Denied | HTTP 403 | PASS |
| Missing each required field (`id`, `userId`, `name`, `category`, `difficulty`, `cookTime`, `favorite`, `createdAt`) | Denied | HTTP 403 for each | PASS |
| `cookTime` below 1 | Denied | HTTP 403 | PASS |
| `cookTime` above 600 | Denied | HTTP 403 | PASS |
| Decimal `cookTime` | Denied | HTTP 403 | PASS |
| String `cookTime` | Denied | HTTP 403 | PASS |
| Invalid `servings` (below 1, above 20, and string type) | Denied | HTTP 403 for each | PASS |
| Notes longer than 300 characters | Denied | HTTP 403 | PASS |
| Notes with invalid type | Denied | HTTP 403 | PASS |
| `favorite` with invalid type | Denied | HTTP 403 | PASS |
| `createdAt` with invalid type | Denied | HTTP 403 | PASS |
| Additional unapproved field | Denied | HTTP 403 | PASS |
| Duplicate name differing only by letter case, including a paired claim write | Denied | HTTP 403 | PASS |
| Two different users use the same recipe name | Allowed | Account B create returned HTTP 200 | PASS |

The disposable emulator documents were deleted by the test script; the emulator accounts and data disappear when the emulator process stops.

## Production verification

These checks used the real Firebase client Auth account and Firestore Security Rules, not the Admin SDK.

| Test | Expected | Actual | Status |
|---|---|---|---|
| Authenticate the real test account | UID matches configured user | UID matched | PASS |
| Read/query own recipes | Only own recipes returned | One recipe returned; `userId` matched the authenticated UID | PASS |
| Unauthenticated read of an existing recipe | Denied | HTTP 403 | PASS |
| Create a valid owned recipe plus matching uniqueness claim | Allowed | HTTP 200; read back successfully | PASS |
| Case-insensitive duplicate recipe name | Denied | HTTP 403 | PASS |
| Delete temporary owned recipe and claim | Allowed | HTTP 200; recipe confirmed absent | PASS |
| Unauthenticated create/update/delete | Denied | Emulator tests passed; not run against production data | NOT RUN |
| Cross-user read/update/delete | Denied | Emulator tests passed; not run against production data | NOT RUN |
| Invalid production writes | Denied | Emulator tests passed; not run against production data | NOT RUN |

Before deployment, the console screenshot showed a stale rules version. After the approved deployment, the Rules API confirmed the published content hash matches the local file and the production smoke test verified the recipe and claim flow.

## Security review and corrections

- No permissive catch-all or `allow read, write: if true` rule exists in the workspace file.
- Recipe reads are owner-scoped. Firestore list queries must include the matching `userId` constraint.
- Recipe writes enforce UID ownership, exact schema, approved category/difficulty values, and the specified field ranges.
- Case-insensitive uniqueness is enforced by normalized per-user claim documents in the same atomic write as the recipe. Rules do not query or scan the recipes collection.
- The app sends `createdAt` with a server timestamp; Rules validate that it is a timestamp and keep it unchanged on update.
- Production owner create/read/delete and duplicate rejection passed with the deployed rules. Production update, cross-user actions, and invalid-data probes were not run against real data; their matching emulator tests passed.

## Reproduction

Run from the project root:

```powershell
firebase.cmd emulators:exec --project prm393-final --only auth,firestore tooling\run_phase10b_rules.cmd
```

The run used the local `firestore.rules` and completed with **52/52 checks passed**.
