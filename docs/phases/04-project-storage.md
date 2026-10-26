# Phase 04 — local project packages and recovery

**Status:** PLANNED. **Dependencies:** phases 02–03. **Evidence:** none for production storage.

## Outcome and exclusions

Store originals and capture metadata durably in app-private Application Support. A project is a versioned `.secondshot` directory, not a loose set of Photos-library entries. The initial release needs no login, backend, or iCloud synchronization. Media import/export features must not be mistaken for an implemented cloud backup service.

## Package contract

Use `manifest.json` as the committed source of truth, with `schemaVersion`, project UUID, creation/update display dates, provenance, reference origin ID, and take records. Each take references immutable media, pose samples, a frame-to-media-PTS ledger, capability metadata, integrity hashes, and completeness status. Optional world maps and localization snapshots are private spatial data, not harmless cache files.

Suggested internal paths are `takes/<uuid>/original.mov`, `poses.jsonl`, `frame-ledger.jsonl`, and `maps/<uuid>.worldmap`. Treat these as schema decisions to finalize in an ADR, not public import guarantees. Keep user-facing names out of paths; UUIDs prevent collisions. Store relative validated paths only.

## Implementation tasks

1. Define Codable manifest/take models and explicit migration results in `Sources/SecondShotCore/Projects/`. Validate unknown required versions, impossible sample counts, path escapes, duplicate IDs, missing files, and contradictory provenance.
2. Implement `ProjectStore` under `Sources/SecondShotApp/Storage/` behind a protocol. Create each take in a staging directory; finish/validate media, flush metadata, then atomically publish a new manifest on the same filesystem. Never expose a staged movie as complete before `AVAssetWriter` finalizes successfully.
3. Keep originals immutable. Derivative previews, alignment edits, and export outputs reference a source take and algorithm version. Deleting an export must not delete an original; replacing a reference requires explicit confirmation when retakes depend on it.
4. Implement a bounded recovery scan on launch: reconcile staging directories, report incomplete assets, quarantine malformed metadata, and offer discard/recovery. Do not delete unknown user files silently.
5. Add a small index for library listing that can be rebuilt from manifests. It is a cache, not the only record of a project. Avoid decoding full pose trajectories or videos just to render a library row.
6. Apply iOS data protection appropriate to foreground capture, with lock behavior verified on hardware. Exclude regenerable previews and temporary files from backup; explicitly document the chosen originals/world-map backup policy before release. Default to no app-managed cloud upload.
7. Implement disk-space preflight and write-failure handling. Limits on project count, file size, archive expansion, and sample count must be explicit, with friendly errors and no half-created complete project.

## Verification

**Core/CI:** round-trip schema fixtures; migrate a previous-version synthetic fixture; reject future required versions; truncated JSON; missing movies; hash mismatches; duplicate IDs; `../` traversal; absolute paths; and oversized manifests. Use temporary test roots created by the test framework, never a user's media directory.

**Simulator integration:** inject disk-full/permission errors through the storage seam; interrupt writes before and after manifest publication; relaunch; ensure the previous good manifest remains readable. Repeat save/cancel/recovery at least 50 times with no completed records pointing to missing files.

**Hardware:** verify lock/unlock file protection and a forced foreground termination during recording once capture exists. Device recordings remain private; commit only sanitized summaries and synthetic reproductions.

## Acceptance and handoff

The target is zero silent corruption in the fault-injection suite, not a guarantee against all device/storage failures. A damaged package must produce a typed recoverable state and preserve untouched originals where possible. Schema changes require a migration test and an explicit decision about backward compatibility.

- [ ] Storage ADR and schema example reviewed against the coordinate contract.
- [ ] Atomic publication/recovery failures tested, not merely described.
- [ ] Cache rebuild and deletion dependency rules verified.
- [ ] No private media/maps, credentials, or build products staged for commit.
- [ ] Evidence, remaining hardware checks, commit SHA, and remote push recorded.
