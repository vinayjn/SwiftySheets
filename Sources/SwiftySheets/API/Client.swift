import Foundation

public protocol URLSessionProtocol {
    func data(
        for request: URLRequest,
        delegate: (any URLSessionTaskDelegate)?
    ) async throws -> (Data, URLResponse)
}

extension URLSession: URLSessionProtocol {}

public final class Client {
    private let credentials: GoogleCredentials
    private let session: URLSessionProtocol

    public init(
        credentials: GoogleCredentials,
        session: URLSessionProtocol = URLSession(configuration: .default)
    ) {
        self.credentials = credentials
        self.session = session
    }

    func makeRequest<T: Decodable>(_ request: URLRequest) async throws -> T {
        let authenticatedRequest = try await credentials.authenticate(request)
        let (data, response) = try await session.data(for: authenticatedRequest, delegate: nil)

        guard
            let httpResponse = response as? HTTPURLResponse,
            httpResponse.statusCode == 200
        else {
            throw SheetsError.invalidResponse(
                status: (response as? HTTPURLResponse)?.statusCode ?? 500
            )
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
}

public extension Client {
    func spreadsheet(id: String) async throws -> Spreadsheet {
        try await Spreadsheet(client: self, id: id)
    }
}
