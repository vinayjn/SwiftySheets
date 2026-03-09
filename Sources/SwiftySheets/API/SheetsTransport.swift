import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

final class SheetsTransport: Sendable {
    private let credentials: GoogleCredentials
    private let session: URLSessionProtocol

    init(
        credentials: GoogleCredentials,
        session: URLSessionProtocol = URLSession.shared
    ) {
        self.credentials = credentials
        self.session = session
    }

    func send(_ request: URLRequest) async throws -> (Data, URLResponse) {
        let authenticatedRequest = try await credentials.authenticate(request)
        return try await session.data(for: authenticatedRequest, delegate: nil)
    }
}
