import Foundation

/// A fluent builder for listing Drive files with chainable filters.
/// ```swift
/// let reports = try await client.drive.list()
///     .spreadsheets()
///     .notTrashed()
///     .nameContains("Report")
///     .execute()
/// ```
public final class DriveListBuilder: @unchecked Sendable {
    private let driveClient: DriveClient
    
    // Mutable state - accumulated filters
    private var queryParts: [String] = []
    
    init(driveClient: DriveClient) {
        self.driveClient = driveClient
    }
    
    // MARK: - File Type Filters
    
    /// Filter to only spreadsheets.
    @discardableResult
    public func spreadsheets() -> DriveListBuilder {
        queryParts.append("mimeType = 'application/vnd.google-apps.spreadsheet'")
        return self
    }
    
    /// Filter to only folders.
    @discardableResult
    public func folders() -> DriveListBuilder {
        queryParts.append("mimeType = 'application/vnd.google-apps.folder'")
        return self
    }
    
    /// Filter by specific MIME type.
    @discardableResult
    public func mimeType(_ type: String) -> DriveListBuilder {
        queryParts.append("mimeType = '\(type)'")
        return self
    }
    
    // MARK: - Name Filters
    
    /// Filter files where name contains the substring.
    @discardableResult
    public func nameContains(_ substring: String) -> DriveListBuilder {
        let escaped = substring.replacingOccurrences(of: "'", with: "\\'")
        queryParts.append("name contains '\(escaped)'")
        return self
    }
    
    /// Filter files where name equals exactly.
    @discardableResult
    public func nameEquals(_ name: String) -> DriveListBuilder {
        let escaped = name.replacingOccurrences(of: "'", with: "\\'")
        queryParts.append("name = '\(escaped)'")
        return self
    }
    
    // MARK: - State Filters
    
    /// Exclude trashed files.
    @discardableResult
    public func notTrashed() -> DriveListBuilder {
        queryParts.append("trashed = false")
        return self
    }
    
    /// Include only trashed files.
    @discardableResult
    public func trashed() -> DriveListBuilder {
        queryParts.append("trashed = true")
        return self
    }
    
    /// Filter files owned by the authenticated user.
    @discardableResult
    public func ownedByMe() -> DriveListBuilder {
        queryParts.append("'me' in owners")
        return self
    }
    
    /// Filter files shared with the authenticated user.
    @discardableResult
    public func sharedWithMe() -> DriveListBuilder {
        queryParts.append("sharedWithMe = true")
        return self
    }
    
    /// Filter files starred by the authenticated user.
    @discardableResult
    public func starred() -> DriveListBuilder {
        queryParts.append("starred = true")
        return self
    }
    
    // MARK: - Parent Folder
    
    /// Filter files in a specific folder.
    @discardableResult
    public func inFolder(_ folderId: String) -> DriveListBuilder {
        queryParts.append("'\(folderId)' in parents")
        return self
    }
    
    // MARK: - Custom Query
    
    /// Add a custom query part (for advanced use).
    @discardableResult
    public func custom(_ queryPart: String) -> DriveListBuilder {
        queryParts.append(queryPart)
        return self
    }
    
    // MARK: - Execute
    
    /// Build the query string from accumulated parts.
    private func buildQuery() -> String? {
        guard !queryParts.isEmpty else { return nil }
        return queryParts.joined(separator: " and ")
    }
    
    /// Execute the query and return matching files.
    public func execute() async throws(SheetsError) -> [DriveFile] {
        try await driveClient.list(query: buildQuery())
    }
    
    /// Alias for execute().
    public func fetch() async throws(SheetsError) -> [DriveFile] {
        try await execute()
    }
    
    /// Return the first matching file.
    public func first() async throws(SheetsError) -> DriveFile? {
        try await execute().first
    }
    
    /// Return the count of matching files.
    public func count() async throws(SheetsError) -> Int {
        try await execute().count
    }
}
