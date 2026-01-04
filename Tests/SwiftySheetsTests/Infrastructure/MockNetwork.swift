@testable import SwiftySheets
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

final class MockURLSession: URLSessionProtocol, @unchecked Sendable {
    var responseQueue: [(Data, URLResponse, Error?)] = []
    
    // Legacy support: Setting these resets the queue to a single item
    var mockData: Data? {
        didSet { updateSingleItemQueue() }
    }
    var mockResponse: URLResponse? {
        didSet { updateSingleItemQueue() }
    }
    var mockError: Error? {
        didSet { updateSingleItemQueue() }
    }
    
    private func updateSingleItemQueue() {
        // If we are setting legacy props, we assume a single response scenario
        let d = mockData ?? Data()
        let r = mockResponse ?? HTTPURLResponse(url: URL(string: "https://example.com")!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        responseQueue = [(d, r, mockError)]
    }
    
    func queue(data: Data, response: URLResponse? = nil, error: Error? = nil) {
        let resp = response ?? HTTPURLResponse(url: URL(string: "https://example.com")!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        responseQueue.append((data, resp, error))
    }
    
    func data(for request: URLRequest, delegate: (any URLSessionTaskDelegate)?) async throws -> (Data, URLResponse) {
        if !responseQueue.isEmpty {
            let (data, response, error) = responseQueue.removeFirst()
            if let error = error { throw error }
            return (data, response)
        }
        // Fallback or error
        return (Data(), HTTPURLResponse(url: URL(string: "https://example.com")!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
    }
}

final class MockCredentials: GoogleCredentials, @unchecked Sendable {
    func authenticate(_ request: URLRequest) async throws -> URLRequest {
        var authenticatedRequest = request
        authenticatedRequest.setValue("Bearer mock-token", forHTTPHeaderField: "Authorization")
        return authenticatedRequest
    }
}

enum TestConstants {
    static let jsonPath = "/dummy/path/service_account.json"
    static let spreadsheetID = "test-spreadsheet-id"
}
