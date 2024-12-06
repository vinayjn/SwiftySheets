import Foundation

public final class SheetsClient {
    private let credentials: GoogleCredentials
    let baseURL = "https://sheets.googleapis.com/v4/spreadsheets"
    private let session: URLSession
    
    public init(credentials: GoogleCredentials) {
        self.credentials = credentials
        self.session = URLSession(configuration: .default)
    }
    
    public func getSpreadsheet(id: String) -> Spreadsheet {
        return Spreadsheet(client: self, id: id)
    }
    
    internal func makeRequest<T: Decodable>(_ request: URLRequest) async throws -> T {
        let authenticatedRequest = try await credentials.authenticate(request)
        let (data, response) = try await session.data(for: authenticatedRequest)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw SheetsError.invalidResponse(
                status: (response as? HTTPURLResponse)?.statusCode ?? 500
            )
        }
        
        return try JSONDecoder().decode(T.self, from: data)
    }
} 
