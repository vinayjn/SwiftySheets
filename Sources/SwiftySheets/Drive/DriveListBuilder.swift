import Foundation

/// MIME types for Drive file filtering.
public enum DriveMimeType: String, Sendable {
    case spreadsheet = "application/vnd.google-apps.spreadsheet"
    case folder = "application/vnd.google-apps.folder"
    case document = "application/vnd.google-apps.document"
    case presentation = "application/vnd.google-apps.presentation"
    case drawing = "application/vnd.google-apps.drawing"
    case form = "application/vnd.google-apps.form"
    case script = "application/vnd.google-apps.script"
    case site = "application/vnd.google-apps.site"
    case pdf = "application/pdf"
}

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
        mimeType(.spreadsheet)
    }
    
    /// Filter to only folders.
    @discardableResult
    public func folders() -> DriveListBuilder {
        mimeType(.folder)
    }
    
    /// Filter to only documents.
    @discardableResult
    public func documents() -> DriveListBuilder {
        mimeType(.document)
    }
    
    /// Filter by MIME type enum.
    @discardableResult
    public func mimeType(_ type: DriveMimeType) -> DriveListBuilder {
        queryParts.insert("mimeType = '\(type.rawValue)'")
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
    
    // MARK: - Custom Query
    
    /// Add a custom query part (for advanced use).
    @discardableResult
    public func custom(_ queryPart: String) -> DriveListBuilder {
        queryParts.insert(queryPart)
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
