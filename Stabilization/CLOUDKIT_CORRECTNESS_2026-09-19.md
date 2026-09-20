# ComicVault CloudKit Correctness — v6 — 2026-09-19

v6 is the CloudKit correctness pass built on the September 19 persistence-verified source. The source-level implementation and static verification in this package are complete. Apple-platform build, simulator/device execution, and live CloudKit validation still require Xcode/macOS and are listed at the end of this document.

## Problems closed in v6

- A successful CloudKit operation can no longer clear an unrelated earlier failure. Failures are accumulated by operation/entity and clear only when the matching operation is resolved.
- The user-facing sync error state is owned by `SyncManager`, including CloudKit engine, account, and subscription failures.
- Sync errors take precedence over the Pending badge so queued work cannot conceal an existing failure.
- Local Only is enforced by the single `SyncManager` runtime route for lifecycle sync, manual pulls, collection writes/deletes, storage-box writes/deletes, and retry work.
- The older parallel `CloudSyncManager`, `NoCloudSync`, and `CloudSyncing` runtime paths are no longer active in the app target. Historical copies are retained under `DeferredFeatures/Obsolete` only.
- CloudKit pull treats any per-record query failure as a pull failure instead of silently dropping that record and applying a partial snapshot.
- Comic and storage-box records use last-writer-wins ordering based on persisted modification/deletion timestamps.
- Offline comic and storage-box upload/delete queues are persisted. Delete queues retain timestamps so retries preserve ordering.
- Legacy ID-only delete queues migrate conservatively. Because their original delete time is unknowable, they are not assigned a fake recent timestamp that could destroy a legitimately newer cloud edit.
- Deletes are represented as same-record tombstones rather than physical CloudKit deletion. This prevents stale/offline devices from recreating deleted records.
- Tombstones scrub user data. Comic tombstones retain only schema version, ID, deletion marker, deletion timestamp, and ordering timestamp. Cover assets, notes, grading data, metadata, and other comic fields are removed. Storage-box tombstones retain only ID and deletion/order metadata.
- A newer live edit can intentionally supersede an older tombstone, allowing recovery/restoration without creating a second record.
- Storage-box pulls reconcile comics against surviving boxes. A newer box tombstone clears affected comic box IDs/status; a surviving box corrects long/short status; repaired comics are queued for upload.
- Storage-box removal no longer launches an async comic update from a captured array index. The updated comic value is captured before the task starts.
- CloudKit silent-push signaling is consolidated on `Notification.Name.cloudKitDidChange`; the AppDelegate post and app listener now use the same canonical notification.
- Change notifications use a custom-zone subscription so both Comic and StorageBox changes wake the app.
- Zone-creation state is stamped successful only after a real successful save. Failures leave the zone eligible for retry.
- Initial/foreground/manual sync retries queued uploads and tombstones through the same provider-aware path.
- Enabling iCloud after launching in Local Only immediately initializes account/zone/subscription state and runs pull/retry/push.

## v5 compile behavior preserved

The final v5 cover-verification compile repair was restored into this v6 source:

- `EditComicViewModel` contains `isVerifying`, `verificationResult`, `verificationError`, and `verifyCover(from:)`.
- `MetadataService.CoverRecognitionResult.MatchConfidence` conforms to `Equatable`.

## Tests added

`ComicVaultTests/ComicVaultCoreTests.swift` now includes coverage for:

- sync failure accumulation preserving an earlier failure when another operation succeeds;
- comic tombstone field scrubbing and refusal to decode as a live comic;
- restoring a newer live comic over an older tombstone;
- storage-box tombstone field scrubbing;
- storage-box deletion reconciliation clearing affected comic assignments;
- preserving a newer local box and correcting a comic's long/short box status.

These tests are part of the Xcode test target. They cannot execute in the Linux repair environment because CloudKit/UIKit/iOS XCTest runtime support is unavailable here.

## Static verification completed

- Parsed all Swift source in `ComicVault`, `ComicVaultTests`, and `ComicVaultUITests` with Swift 6.2.1: **PASS**.
- Repeated the full parser pass with `USE_CLOUDSYNC`: **PASS**.
- `ComicVault/Info.plist`: **valid**.
- `ComicVault/ComicVault.entitlements`: **valid**.
- `ComicVault.xcodeproj/project.pbxproj`: **valid**.
- Active-source scan found **0 physical `deleteRecord(withID:)` calls**.
- Active-source scan found **0 lossy `matchResults.compactMap` CloudKit pull paths**.
- Active mutating `CloudSync.shared` calls are confined to `SyncProvider.swift`.
- Active source contains no `.ckRemoteChange` notification path.
- All changed production Swift files contain the required ComicVault header and a `09-19-26` Running Edit Log entry.
- The returned ZIP passed a full archive integrity test.

## CloudKit schema deployment note

v6 introduces two fields on both the `Comic` and `StorageBox` record types:

- `isDeleted`
- `deletedAt`

Development CloudKit can discover new fields during testing. Before testing against or releasing with the **production** CloudKit environment, deploy the updated schema in Apple's CloudKit tooling so production accepts these tombstone fields.

## Required Xcode / Apple-platform verification

1. Open `ComicVault.xcodeproj` and run Command+B on the shared ComicVault scheme.
2. Run Command+U for `ComicVaultTests` and the UI smoke tests.
3. Build Release for a generic iOS device.
4. With iCloud enabled, add/edit a comic on device A and confirm it appears on device B.
5. Go offline, edit a comic, reconnect, and confirm the queued change retries.
6. Go offline, delete a comic, reconnect, and confirm the tombstone reaches device B and the comic does not resurrect.
7. Create a newer edit on another device than an older pending delete and confirm the newer edit wins.
8. Delete a storage box containing assigned comics and confirm other devices move those comics to Not Sorted rather than leaving dangling box IDs.
9. Switch to Local Only and confirm manual/lifecycle sync controls perform no CloudKit data operations.
10. Verify silent CloudKit pushes trigger a pull for both Comic and StorageBox changes.
11. Deploy/verify the production CloudKit schema before TestFlight production-container testing.
