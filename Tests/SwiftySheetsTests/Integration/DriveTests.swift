@testable import SwiftySheets
import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

final class DriveTests: XCTestCase, @unchecked Sendable {
    private var client: Client!
    private var mockSession: MockURLSession!
    
    override func setUp() async throws {
        try await super.setUp()
        mockSession = MockURLSession()
        let credentials = MockCredentials()
        client = Client(credentials: credentials, session: mockSession)
    }
    
    func testListFiles() async throws {
        // Mock Response
        let fileList = DriveFileList(files: [
             DriveFile(id: "1", name: "File 1", mimeType: "application/vnd.google-apps.spreadsheet"),
             DriveFile(id: "2", name: "File 2", mimeType: "video/mp4")
        ])
        
        mockSession.mockData = try JSONEncoder().encode(fileList)
        
        let files = try await client.drive.list(query: nil)
        XCTAssertEqual(files.count, 2)
        XCTAssertEqual(files[0].name, "File 1")
    }
    
    func testCreateFile() async throws {
        let newFile = DriveFile(id: "new-id", name: "New Doc", mimeType: "application/vnd.google-apps.folder")
        
        mockSession.mockResponse = HTTPURLResponse(url: URL(string: "https://googleapis.com")!, statusCode: 200, httpVersion: nil, headerFields: nil)
        mockSession.mockData = try JSONEncoder().encode(newFile)
        
        let created = try await client.drive.create(name: "New Doc", type: .folder)
        XCTAssertEqual(created.id, "new-id")
        XCTAssertEqual(created.name, "New Doc")
    }
    
    func testDeleteFile() async throws {
        mockSession.mockResponse = HTTPURLResponse(url: URL(string: "https://googleapis.com")!, statusCode: 204, httpVersion: nil, headerFields: nil)
        mockSession.mockData = Data()
        
        try await client.drive.delete(id: "file-id")
        // Success if no throw
    }
}
