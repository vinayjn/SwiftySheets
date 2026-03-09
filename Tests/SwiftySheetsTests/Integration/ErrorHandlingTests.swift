@testable import SwiftySheets
import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

final class ErrorHandlingTests: XCTestCase, @unchecked Sendable {
    private var client: Client!
    private var mockSession: MockURLSession!
    
    override func setUp() async throws {
        try await super.setUp()
        mockSession = MockURLSession()
        let credentials = MockCredentials()
        client = Client(credentials: credentials, session: mockSession)
    }
    
    func testErrorHandling401() async throws {
        let mockResponse = HTTPURLResponse(
            url: URL(string: "https://example.com")!,
            statusCode: 401,
            httpVersion: nil,
            headerFields: nil
        )
        mockSession.mockResponse = mockResponse
        mockSession.mockData = Data()
        
        do {
            let _: ValueRange = try await client.makeRequest(URLRequest(url: URL(string: "https://example.com")!))
            XCTFail("Should have thrown authenticationFailed error")
        } catch SheetsError.authenticationFailed {
            // Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testErrorHandling403WithAPIError() async throws {
        let mockResponse = HTTPURLResponse(
            url: URL(string: "https://example.com")!,
            statusCode: 403,
            httpVersion: nil,
            headerFields: nil
        )
        
        let apiError = GoogleAPIError(
            error: GoogleAPIError.ErrorDetails(
                code: 403,
                message: "The caller does not have permission",
                status: "PERMISSION_DENIED",
                details: nil
            )
        )
        mockSession.mockResponse = mockResponse
        mockSession.mockData = try JSONEncoder().encode(apiError)
        
        do {
            let _: ValueRange = try await client.makeRequest(URLRequest(url: URL(string: "https://example.com")!))
            XCTFail("Should have thrown permissionDenied error")
        } catch SheetsError.permissionDenied(let message) {
            XCTAssertEqual(message, "The caller does not have permission")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testErrorHandling429WithRetryAfter() async throws {
        let mockResponse = HTTPURLResponse(
            url: URL(string: "https://example.com")!,
            statusCode: 429,
            httpVersion: nil,
            headerFields: ["Retry-After": "60"]
        )
        mockSession.mockResponse = mockResponse
        mockSession.mockData = Data()
        
        do {
            let _: ValueRange = try await client.makeRequest(URLRequest(url: URL(string: "https://example.com")!))
            XCTFail("Should have thrown rateLimitExceeded error")
        } catch SheetsError.rateLimitExceeded(let retryAfter) {
            XCTAssertEqual(retryAfter, 60)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testDecodingErrorPreservesContext() async throws {
        let mockResponse = HTTPURLResponse(
            url: URL(string: "https://example.com")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        mockSession.mockResponse = mockResponse
        // Send invalid JSON that can't decode to ValueRange
        mockSession.mockData = Data("{\"invalid\": true}".utf8)

        do {
            let _: ValueRange = try await client.makeRequest(URLRequest(url: URL(string: "https://example.com")!))
            XCTFail("Should have thrown decodingError")
        } catch SheetsError.decodingError(let context) {
            XCTAssertTrue(context.contains("ValueRange"), "Error context should mention the type: \(context)")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testDriveErrorHandling401() async throws {
        let mockResponse = HTTPURLResponse(
            url: URL(string: "https://example.com")!,
            statusCode: 401,
            httpVersion: nil,
            headerFields: nil
        )
        mockSession.mockResponse = mockResponse
        mockSession.mockData = Data()

        do {
            _ = try await client.drive.create(name: "Test")
            XCTFail("Should have thrown authenticationFailed error")
        } catch SheetsError.authenticationFailed {
            // Expected - DriveClient now uses shared ResponseHandler
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testDriveErrorHandling429() async throws {
        let mockResponse = HTTPURLResponse(
            url: URL(string: "https://example.com")!,
            statusCode: 429,
            httpVersion: nil,
            headerFields: ["Retry-After": "30"]
        )
        mockSession.mockResponse = mockResponse
        mockSession.mockData = Data()

        do {
            _ = try await client.drive.create(name: "Test")
            XCTFail("Should have thrown rateLimitExceeded error")
        } catch SheetsError.rateLimitExceeded(let retryAfter) {
            XCTAssertEqual(retryAfter, 30)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testSuccessfulResponseCodes() async throws {
        let successCodes = [200, 201, 204, 299]
        
        let mockValueRange = ValueRange(range: "A1:A1", values: [["test"]])
        let mockData = try JSONEncoder().encode(mockValueRange)
        
        for statusCode in successCodes {
            let mockResponse = HTTPURLResponse(
                url: URL(string: "https://example.com")!,
                statusCode: statusCode,
                httpVersion: nil,
                headerFields: nil
            )
            mockSession.mockResponse = mockResponse
            mockSession.mockData = mockData
            
            do {
                let result: ValueRange = try await client.makeRequest(URLRequest(url: URL(string: "https://example.com")!))
                XCTAssertEqual(result.values, [["test"]])
            } catch {
                XCTFail("Should not throw error for status code \(statusCode): \(error)")
            }
        }
    }
}
