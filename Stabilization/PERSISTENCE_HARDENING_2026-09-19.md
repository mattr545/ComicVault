# ComicVault Persistence Hardening — 2026-09-19

Roadmap item #1 is complete for ComicVault's core local persistence layer **at the code and executable filesystem-test level**. This pass was re-opened after the initial syntax-only verification to make sure the behavior actually works under realistic save, corruption, recovery, and compatibility scenarios.

## What changed

- Added one shared durable JSON persistence layer in `FileProtection.swift`.
- Every canonical JSON write is encoded, decoded for type validity, written atomically, then **read back from the actual file on disk and decoded again** before the write is considered successful.
- The same on-disk verification is performed for the `.backup` recovery copy.
- Corrupt, truncated, empty, or otherwise unreadable JSON is no longer silently treated as valid empty data.
- When a primary JSON file is unreadable, ComicVault preserves an exact `.corrupt-<timestamp>-<id>` copy before trying the recovery copy.
- When the recovery copy is valid, ComicVault loads it and attempts to rebuild the canonical primary store.
- When the primary is valid but the recovery copy is stale or damaged, the valid primary refreshes the recovery copy.
- If neither primary nor recovery copy can be decoded, the unreadable data is preserved and ComicVault does not automatically overwrite it with an empty collection.
- A backup-write failure is distinguished from a primary-write failure. The app can tell the user that the current primary data was saved even if the recovery copy could not be updated.
- Local load/save/recovery failures are queued in `PersistenceIssueCenter` and shown in `MainTabView` as a dismissible data-health banner. They are no longer DEBUG-only events.
- Wishlist records were moved from `UserDefaults` to a protected canonical JSON store with migration from all known legacy wishlist keys.
- Value histories were moved from `UserDefaults` to a protected canonical JSON store with migration from the old history key.
- Collection migration recognizes the historical `comics.json`, `saved_comics`, and `comics` sources only as migration inputs.
- Storage boxes and all three soft-delete/recovery stores now use the same durable JSON behavior.
- Legacy sources are removed only after the canonical primary plus its recovery copy save successfully. A valid canonical store also cleans up leftover legacy sources on later launches.
- `MigrationManager` no longer creates shadow UserDefaults stores such as `saved_comics` or `saved_wishlist`, its backup-folder move no longer uses a silent `try?`, failed migrations are not stamped complete, and the manager is invoked during app startup.

## Backward-compatible Comic decoding

`Comic` now has a backward-compatible decoder that:

- requires the historical identity/core fields (`id`, `title`, `createdAt`) rather than inventing a different comic;
- decodes all optional historical/new fields when present;
- defaults `isSigned` to `false`;
- defaults `isFromComicVine` to its historical model default of `true`;
- defaults `coverComparisonPerformed`, `isFavorite`, and `isFromCryptoComics` to `false`;
- uses `createdAt` as `modifiedAt` when an older record predates that field, avoiding a fake "just modified now" timestamp.

## Authoritative local stores

| Data type | Canonical primary store |
| --- | --- |
| Owned collection | `collection_comics.json` |
| Wishlist | `wishlist_comics.json` |
| Value history | `value_histories.json` |
| Storage boxes | `storage_boxes.json` |
| Soft-deleted comics | `soft_delete_entries.json` |
| Soft-delete batch history | `soft_delete_batches.json` |
| Box-renumber recovery history | `soft_delete_renumbers.json` |

## Functional verification executed

The production `LocalJSONStore` implementation was executed against real temporary filesystem locations. Normal save, stale-backup refresh, truncated-primary recovery, corrupt-file preservation, double-corruption failure, and backup-write failure reporting all passed.

A second executable Swift harness verified old-style Comic JSON compatibility and round-tripping.

## XCTest coverage

`ComicVaultTests/ComicVaultCoreTests.swift` contains tests for legacy Comic compatibility, primary/recovery disk writes, stale recovery refresh, corrupt-primary recovery, double corruption, backup-write failure reporting, and canonical persistence filename uniqueness.

## Files changed for persistence hardening

- `ComicVault/FileProtection.swift`
- `ComicVault/Comic.swift`
- `ComicVault/CollectionViewModel.swift`
- `ComicVault/WishlistViewModel.swift`
- `ComicVault/StorageBoxViewModel.swift`
- `ComicVault/SoftDeleteArchive.swift`
- `ComicVault/MainTabView.swift`
- `ComicVault/MigrationManager.swift`
- `ComicVault/ComicVaultApp.swift`
- `ComicVaultTests/ComicVaultCoreTests.swift`
