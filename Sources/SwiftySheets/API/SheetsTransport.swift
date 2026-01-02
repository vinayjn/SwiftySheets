import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public final class SheetsTransport: Transport {
    private let credentials: GoogleCredentials
    private let session: URLSessionProtocol
    
    public init(
        credentials: GoogleCredentials,
        session: URLSessionProtocol = URLSession.shared
    ) {
        self.credentials = credentials
        self.session = session
    }
    
    public func send(_ request: URLRequest) async throws -> (Data, URLResponse) {
        var authenticatedRequest = request
        authenticatedRequest = try await credentials.authenticate(request)
        return try await session.data(for: authenticatedRequest, delegate: nil)
    }
}
