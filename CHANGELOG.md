# Changelog

All notable changes to SwiftySheets will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.0] - 2026-03-09

### Breaking Changes

- **SheetQuery is now a value type (struct).** Previously a `final class @unchecked Sendable`,
  it is now a `struct` with copy-on-return semantics. Code relying on reference semantics
  (sharing a query across variables and expecting mutations to propagate) must be updated.
  The standard chaining pattern (`.where(...).sorted(...).execute()`) works unchanged.
- **`@discardableResult` removed from SheetQuery builder methods.** Discarding the return
  value of `.where()`, `.sorted()`, `.limit()`, etc. now produces a compiler warning, since
  with a struct the modification is lost if the return is not captured.
- **`thenSorted(by:)` removed.** Use chained `.sorted(by:)` calls instead — they compose
  as primary, secondary, etc. sort keys.
- **FormatBuilder is now a value type (struct).** Same copy-on-return pattern; `@discardableResult`
  removed from its builder methods.
- **`OAuthCredentials` token provider closure requires `@Sendable`.** The `tokenProvider`
  parameter in `init(tokenProvider:)` is now `@escaping @Sendable () async -> String?`.
- **`Transport` protocol removed.** `SheetsTransport` is now a concrete `final class` that
  is not subclassable. This was internal API only.

### Added

- **Drive pagination.** `DriveClient.list()` now follows `nextPageToken` to fetch all pages,
  fixing silent truncation at 1000 files.
- **`DriveListBuilder.first()` optimization.** Passes `pageSize=1` to the API instead of
  fetching up to 1000 files and discarding all but one.
- **`SheetsError` conforms to `LocalizedError`.** All 14 error cases now have human-readable
  `errorDescription` messages for logging and display.
- **`SheetsError.decodingError(context:)` case.** Replaces the old `.invalidResponse` for
  JSON decode failures, preserving the type name and underlying error.
- **`ResizeSheet` accepts `sheetId: Int` directly.** No longer requires a full `Sheet` object;
  the convenience `init(sheet:rows:columns:)` is still available.
- **`SheetQuery.or(_:)` for compound OR logic.** Each OR branch can contain multiple AND'd
  conditions. Branches are unioned: an item passes if it matches any branch.
- **`SheetQuery.first()` optimization.** Internally limits to 1 result before executing,
  avoiding unnecessary sort/filter work on large datasets.
- **Shared `ResponseHandler`** for both Sheets and Drive API calls, eliminating ~60 lines
  of duplicated HTTP status mapping and error decoding.
- **Static `DateFormatter`s in `@SheetRow` macro.** Formatters are generated as
  `nonisolated(unsafe) static let` properties instead of being recreated on every decode.
- **Error handling section in README** with typed-throws example covering all `SheetsError` cases.
- **16 new tests** (97 → 113) covering value-type semantics, Drive pagination, quoted sheet
  names, null cell decoding, and error descriptions.

### Fixed

- **Quoted sheet name parsing.** `SheetRange.init(parsing:)` now strips surrounding
  single-quotes from sheet names (e.g. `'My Sheet'!A1:B2` → sheet name `My Sheet`).
- **`SheetQuery.or()` semantics.** Changed from flat predicate union to grouped branches
  where conditions within a branch are AND'd, and branches are OR'd.
- **`SheetQuery.first()` no longer mutates the query.** With the struct refactor, calling
  `first()` on a query and then `execute()` on the same query returns all results as expected.
- **`SafeString` null handling.** Explicit `decodeNil()` check avoids 4 unnecessary
  try/catch cycles per null cell value from the Google Sheets API.
- **Macro `names:` coverage.** `@SheetRow` macro declaration now includes `arbitrary` in its
  member names to cover generated static formatter declarations.
- **`nonisolated(unsafe)` on generated formatters.** Fixes Swift 6 strict concurrency errors
  for `ISO8601DateFormatter` and `DateFormatter` (which are not `Sendable`).

### Improved

- **Swift 6 concurrency compliance.** Removed `UncheckedSendable` wrapper,
  `nonisolated(unsafe)` from `FormatBuilder`, and `@unchecked Sendable` from
  `OAuthCredentials`. KeyPath parameters use `& Sendable` constraint.
- **`SheetColumn` validation performance.** Replaced regex with `allSatisfy` character
  check — avoids regex compilation on every column init.
- **Deduplicated column conversion helpers** in macro target — shared `ColumnHelpers.swift`
  replaces duplicate implementations in `SheetRowMacro` and `GenerateColumnsMacro`.
- **Removed dead code.** `Transport` protocol, `EmptyResponse` struct, unused `baseURL`
  constant in `Endpoints`.
- **`DriveListBuilder` uses `Set<String>`** for query parts, making filter operations
  idempotent by design.

## [1.0.0] - 2025-12-01

Initial release.
