import Foundation

public struct DriveFile: Codable {
    public let id: String
    public let name: String
    public let mimeType: String
}

struct DriveFileList: Codable {
    let files: [DriveFile]
}
