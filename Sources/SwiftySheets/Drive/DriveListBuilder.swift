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
public final class DriveListBuilder: @unchecked Sendable {
    private let driveClient: DriveClient
    
    // Use Set to prevent duplicate filters
    private var queryParts: Set<String> = []
    
    init(driveClient: DriveClient) {
        self.driveClient = driveClient
    }
    
    // MARK: - File Type Filters
    
    /// Filter to only spreadsheets.
    @discardableResult
    public func spreadsheets() -> DriveListBuilder {
        queryParts.insert("mimeType = '\(DriveClient.FileType.spreadsheet.mimeType)'")
        return self
    }
    
    /// Filter to only folders.
    @discardableResult
    public func folders() -> DriveListBuilder {
        queryParts.insert("mimeType = '\(DriveClient.FileType.folder.mimeType)'")
        return self
    }
    
    // MARK: - Name Filters
    
    /// Filter files where name contains the substring.
    @discardableResult
    public func nameContains(_ substring: String) -> DriveListBuilder {
        let escaped = substring.replacingOccurrences(of: "'", with: "\\'")
        queryParts.insert("name contains '\(escaped)'")
        return self
    }
    
    /// Filter files where name equals exactly.
    @discardableResult
    public func nameEquals(_ name: String) -> DriveListBuilder {
        let escaped = name.replacingOccurrences(of: "'", with: "\\'")
        queryParts.insert("name = '\(escaped)'")
        return self
    }
    
    // MARK: - State Filters
    
    /// Exclude trashed files.
    @discardableResult
    public func notTrashed() -> DriveListBuilder {
        queryParts.insert("trashed = false")
        return self
    }
    
    /// Include only trashed files.
    @discardableResult
    public func trashed() -> DriveListBuilder {
        queryParts.insert("trashed = true")
        return self
    }
    
    /// Filter files owned by the authenticated user.
    @discardableResult
    public func ownedByMe() -> DriveListBuilder {
        queryParts.insert("'me' in owners")
        return self
    }
    
    /// Filter files shared with the authenticated user.
    @discardableResult
    public func sharedWithMe() -> DriveListBuilder {
        queryParts.insert("sharedWithMe = true")
        return self
    }
    
    /// Filter files starred by the authenticated user.
    @discardableResult
    public func starred() -> DriveListBuilder {
        queryParts.insert("starred = true")
        return self
    }
    
    // MARK: - Parent Folder
    
    /// Filter files in a specific folder.
    @discardableResult
    public func inFolder(_ folderId: String) -> DriveListBuilder {
        queryParts.insert("'\(folderId)' in parents")
        return self
    }
    
    // MARK: - Custom
    
    /// Add a raw custom query string.
    /// ```swift
    /// .custom("appProperties has { key = 'val' }")
    /// ```
    @discardableResult
    public func custom(_ query: String) -> DriveListBuilder {
        queryParts.insert(query)
        return self
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
        try await driveClient.list(query: buildQuery())
    }
    
    /// Return the first matching file.
    /// Note: This fetches all matching files and returns the first one.
    /// There is no server-side limit optimization.
    public func first() async throws(SheetsError) -> DriveFile? {
        try await execute().first
    }

    /// Return the count of matching files.
    /// Note: This fetches all matching files and counts them client-side.
    /// There is no server-side count optimization.
    public func count() async throws(SheetsError) -> Int {
        try await execute().count
    }
}
