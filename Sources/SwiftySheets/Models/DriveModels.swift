import Foundation

public struct DriveFile: Codable, Sendable {
    public let id: String
    public let name: String
    public let mimeType: String
    
    public init(id: String, name: String, mimeType: String) {
        self.id = id
        self.name = name
        self.mimeType = mimeType
    }
}

public struct DriveFileList: Codable, Sendable {
    public let files: [DriveFile]
    
    public init(files: [DriveFile]) {
        self.files = files
    }
}

public struct DriveQuery: Sendable {
    public let query: String
    
    public init(_ query: String) {
        self.query = query
    }
    
    // Helpers
    public static func mimeType(_ type: String) -> DriveQuery {
        return DriveQuery("mimeType = '\(type)'")
    }
    
    public static func nameContains(_ text: String) -> DriveQuery {
        return DriveQuery("name contains '\(text)'")
    }
    
    public static var spreadsheets: DriveQuery {
        return .mimeType("application/vnd.google-apps.spreadsheet")
    }
    
    public static var folders: DriveQuery {
        return .mimeType("application/vnd.google-apps.folder")
    }
    
    public static var notTrashed: DriveQuery {
        return DriveQuery("trashed = false")
    }
    
    public func and(_ other: DriveQuery) -> DriveQuery {
        return DriveQuery("(\(self.query)) and (\(other.query))")
    }
}
