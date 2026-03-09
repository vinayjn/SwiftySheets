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

    // MARK: - Pagination Tests

    func testListFilesPagination() async throws {
        // Page 1: returns 2 files + nextPageToken
        let page1 = DriveFileList(
            files: [
                DriveFile(id: "1", name: "File 1", mimeType: "application/vnd.google-apps.spreadsheet"),
                DriveFile(id: "2", name: "File 2", mimeType: "application/vnd.google-apps.spreadsheet")
            ],
            nextPageToken: "token-page-2"
        )
        mockSession.queue(data: try JSONEncoder().encode(page1))

        // Page 2: returns 1 file, no nextPageToken (final page)
        let page2 = DriveFileList(
            files: [
                DriveFile(id: "3", name: "File 3", mimeType: "application/vnd.google-apps.spreadsheet")
            ],
            nextPageToken: nil
        )
        mockSession.queue(data: try JSONEncoder().encode(page2))

        let files = try await client.drive.list(query: nil)
        XCTAssertEqual(files.count, 3)
        XCTAssertEqual(files[0].name, "File 1")
        XCTAssertEqual(files[1].name, "File 2")
        XCTAssertEqual(files[2].name, "File 3")
    }

    func testListFilesSinglePage() async throws {
        // Single page: no nextPageToken
        let page = DriveFileList(
            files: [DriveFile(id: "1", name: "Only File", mimeType: "text/plain")],
            nextPageToken: nil
        )
        mockSession.queue(data: try JSONEncoder().encode(page))

        let files = try await client.drive.list(query: nil)
        XCTAssertEqual(files.count, 1)
        XCTAssertEqual(files[0].name, "Only File")
    }

    func testListFilesEmptyResult() async throws {
        let page = DriveFileList(files: [], nextPageToken: nil)
        mockSession.queue(data: try JSONEncoder().encode(page))

        let files = try await client.drive.list(query: nil)
        XCTAssertEqual(files.count, 0)
    }

    func testDriveListBuilderFirstUsesSmallPageSize() async throws {
        // first() should only fetch 1 file, not a full page of 1000
        let page = DriveFileList(
            files: [DriveFile(id: "1", name: "First", mimeType: "text/plain")],
            nextPageToken: nil
        )
        mockSession.queue(data: try JSONEncoder().encode(page))

        let first = try await client.drive.list().first()
        XCTAssertNotNil(first)
        XCTAssertEqual(first?.name, "First")
    }
}
