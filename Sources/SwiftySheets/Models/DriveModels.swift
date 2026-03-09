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
    /// The token for retrieving the next page of results.
    /// `nil` when this response is the final page.
    public let nextPageToken: String?

    public init(files: [DriveFile], nextPageToken: String? = nil) {
        self.files = files
        self.nextPageToken = nextPageToken
    }
}
