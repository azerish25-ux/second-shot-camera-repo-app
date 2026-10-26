# Phase 17 — project library, imports and recoverable lifecycle

**Status:** PLANNED.

## Outcome and dependencies

Let creators keep a small body of work, identify the correct reference take and recover from cancellation, interruption or accidental deletion. Build on phase 04's canonical package schema, phases 12–14's comparison/export contracts and phase 16's accessible UI. Do not create a second schema here. The baseline remains local-first: no login, server, collaborative editing or implicit cloud synchronization.

The project, not a thumbnail or a temporary export file, is the unit of ownership. A `.secondshot` package contains a manifest and associated media/pose assets; details belong to the storage contract. Personal footage and saved room maps never belong in Git history or public CI artifacts.

## Implementation work

1. Extend the repository abstraction under `Sources/SecondShotApp/Storage/` with enumerating, opening, renaming, duplicating, importing and retiring packages. Keep filesystem coordination out of SwiftUI views. Add `LibraryViewModel` as a presentation adapter rather than another database.
2. Index stable project IDs, user-visible names, creation/modification dates, reference identity, take count, source mode and thumbnail status. Generate small thumbnails off the main actor; lazy-load the visible range. Empty or corrupt thumbnails must not make valid media inaccessible.
3. Add rename, duplicate and delete actions with accessible confirmations. Duplicate to new project/take identifiers while preserving a documented relationship to the original. Never accidentally give unrelated camera maps a shared origin ID. A missing reference cannot silently become another take.
4. Make destructive deletion two-stage: move to an app-managed Recently Deleted area, then explicitly purge or apply a disclosed retention policy. Proposed retention is seven days, subject to storage review; do not promise recovery after an explicit purge, app deletion or operating-system cleanup. Keep retained disk use visible.
5. Support imports through the system document picker with scoped file access. Validate the entire package into a staging location before publishing it to the library. Bound file count, cumulative bytes, path depth, media duration and manifest version. Reject traversal paths, symlink escapes, missing assets and inconsistent origin/lens metadata. Handle duplicate IDs by offering an import-as-copy flow, never blind replacement.
6. Reuse atomic-save and crash-recovery machinery from phase 04. Do not delete originals after an export without a separate user action. Cancelled or failed imports/exports remove only their own temporary output after readers have released it.
7. Explain storage occupancy and allow users to share a project deliberately. Sharing a package may expose room geometry and raw media; make that different from sharing a rendered clip. Strip unnecessary metadata from rendered exports according to phase 19's policy.

## Verification

Add repository tests for empty libraries, 200 synthetic projects, renamed files, duplicates, broken thumbnails, unsupported manifests, failed migrations and files disappearing between enumeration and open. Inject low-space and interrupted-write conditions; assert that the last valid manifest remains readable. Test malicious path entries and oversized packages using generated synthetic fixtures, not downloaded untrusted archives.

Simulator journeys must cover creating/renaming/duplicating a project, deleting and restoring, cancelling an import and reopening after app relaunch. Real-device checks must include Files-provider access, locked/protected files, a storage-pressure case and a large real project whose owners consented to testing.

## Acceptance and failure behavior

- No delete, rename or failed import mutates another project's files.
- A valid original remains available after every simulated failure point; incomplete packages are never presented as completed takes.
- Each destructive action identifies the target, consequence and available recovery path.
- A project containing a future unsupported schema opens a useful explanation or read-only information view; it is never rewritten by an older app.
- Initial performance target: the first visible library page for 200 indexed synthetic projects appears within one second on the chosen floor device after a warm launch. This target must be measured and adjusted explicitly, not asserted from simulator timing.

If storage is exhausted, preserve recoverable captures and explain what can be deleted. Do not automatically purge original footage to make a new export succeed. Recover the library index from manifests if the index is corrupt; do not treat the index as the sole source of truth.

## Evidence and handoff

Save package-validation test results, failure-injection cases, migration fixtures and redacted device traces. Document retention decisions and package-sharing warnings. Include a support procedure for copying a user's project out without collecting it by default. Update the phase-04 schema reference only if the implementation genuinely requires a versioned migration, and rerun its compatibility suite.

Primary reference: [Apple document picker documentation](https://developer.apple.com/documentation/uikit/uidocumentpickerviewcontroller). Verify file-provider and security-scoped access behavior against the selected SDK during implementation.
