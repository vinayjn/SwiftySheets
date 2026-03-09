import Foundation

/// A fluent builder for listing Drive files with chainable filters.
/// Uses Set-based storage to prevent duplicate filters (idempotent operations).
/// ```swift
/// let reports = try await client.drive.list()
///     .spreadsheets()
///     .notTrashed()
///     .nameContains("Report")
///     .execute()
/// ```
public struct DriveListBuilder: Sendable {
    private let driveClient: DriveClient

    // Use Set to prevent duplicate filters
    private var queryParts: Set<String> = []

    /// When set, overrides the default page size used in each API request.
    /// `first()` sets this to 1 internally to avoid fetching unnecessary results.
    private var _pageSize: Int?

    init(driveClient: DriveClient) {
        self.driveClient = driveClient
    }

    private func adding(_ part: String) -> DriveListBuilder {
        var copy = self
        copy.queryParts.insert(part)
        return copy
    }

    // MARK: - File Type Filters

    /// Filter to only spreadsheets.
    public func spreadsheets() -> DriveListBuilder {
        adding("mimeType = '\(DriveClient.FileType.spreadsheet.mimeType)'")
    }

    /// Filter to only folders.
    public func folders() -> DriveListBuilder {
        adding("mimeType = '\(DriveClient.FileType.folder.mimeType)'")
    }

    // MARK: - Name Filters

    /// Filter files where name contains the substring.
    public func nameContains(_ substring: String) -> DriveListBuilder {
        let escaped = substring.replacingOccurrences(of: "'", with: "\\'")
        return adding("name contains '\(escaped)'")
    }

    /// Filter files where name equals exactly.
    public func nameEquals(_ name: String) -> DriveListBuilder {
        let escaped = name.replacingOccurrences(of: "'", with: "\\'")
        return adding("name = '\(escaped)'")
    }

    // MARK: - State Filters

    /// Exclude trashed files.
    public func notTrashed() -> DriveListBuilder {
        adding("trashed = false")
    }

    /// Include only trashed files.
    public func trashed() -> DriveListBuilder {
        adding("trashed = true")
    }

    /// Filter files owned by the authenticated user.
    public func ownedByMe() -> DriveListBuilder {
        adding("'me' in owners")
    }

    /// Filter files shared with the authenticated user.
    public func sharedWithMe() -> DriveListBuilder {
        adding("sharedWithMe = true")
    }

    /// Filter files starred by the authenticated user.
    public func starred() -> DriveListBuilder {
        adding("starred = true")
    }

    // MARK: - Parent Folder

    /// Filter files in a specific folder.
    public func inFolder(_ folderId: String) -> DriveListBuilder {
        adding("'\(folderId)' in parents")
    }

    // MARK: - Custom

    /// Add a raw custom query string.
    /// ```swift
    /// .custom("appProperties has { key = 'val' }")
    /// ```
    public func custom(_ query: String) -> DriveListBuilder {
        adding(query)
    }

    // MARK: - Execute

    /// Build the query string from accumulated parts.
    private func buildQuery() -> String? {
        guard !queryParts.isEmpty else { return nil }
        // Sort for deterministic output
        return queryParts.sorted().joined(separator: " and ")
    }

    /// Execute the query and return matching files.
    public func execute() async throws(SheetsError) -> [DriveFile] {
        try await driveClient.list(query: buildQuery(), pageSize: _pageSize)
    }

    /// Return the first matching file.
    /// Sets `pageSize` to 1 so only a single file is fetched from the API.
    public func first() async throws(SheetsError) -> DriveFile? {
        var copy = self
        copy._pageSize = 1
        return try await copy.execute().first
    }

    /// Return the count of matching files.
    /// Note: This fetches all matching files and counts them client-side.
    /// There is no server-side count optimization.
    public func count() async throws(SheetsError) -> Int {
        try await execute().count
    }
}
