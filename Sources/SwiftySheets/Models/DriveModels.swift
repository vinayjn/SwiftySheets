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
