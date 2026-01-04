import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct DriveClient: Sendable {
    private let transport: SheetsTransport
    private let baseURL = URL(string: "https://www.googleapis.com/drive/v3")!
    
    init(transport: SheetsTransport) {
        self.transport = transport
    }
    
    // MARK: - Read
    
    public func list(query: String? = nil) async throws -> [DriveFile] {
        var url = baseURL.appendingPathComponent("files")
        
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "fields", value: "files(id, name, mimeType)"),
            URLQueryItem(name: "pageSize", value: "1000") // Default generous page size
        ]
        
        if let query = query, !query.isEmpty {
            queryItems.append(URLQueryItem(name: "q", value: query))
        }
        
        url.append(queryItems: queryItems)
        
        let request = URLRequest(url: url)
        let response: DriveFileList = try validateAndDecode(await transport.send(request))
        return response.files
    }
    
    public func list(query: DriveQuery) async throws -> [DriveFile] {
        return try await list(query: query.query)
    }
    
    // MARK: - Write
    
    public func create(name: String, mimeType: String, parents: [String]? = nil) async throws -> DriveFile {
        let url = baseURL.appendingPathComponent("files")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let metadata = CreateFileRequest(name: name, mimeType: mimeType, parents: parents)
        request.httpBody = try JSONEncoder().encode(metadata)
        
        return try validateAndDecode(await transport.send(request))
    }
    
    public func delete(id: String) async throws {
        let url = baseURL.appendingPathComponent("files").appendingPathComponent(id)
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        
        try validate(await transport.send(request))
    }
    private func validateAndDecode<T: Decodable>(_ result: (Data, URLResponse)) throws -> T {
        let (data, response) = result
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SheetsError.invalidResponse(status: 500)
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            // Basic error handling for now, can be improved to match Client's full logic or shared
            if let apiError = try? JSONDecoder().decode(GoogleAPIError.self, from: data) {
                 throw SheetsError.apiError(apiError)
            }
            throw SheetsError.invalidResponse(status: httpResponse.statusCode)
        }
        
        return try JSONDecoder().decode(T.self, from: data)
    }
    
    private func validate(_ result: (Data, URLResponse)) throws {
        let (data, response) = result
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SheetsError.invalidResponse(status: 500)
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
             if let apiError = try? JSONDecoder().decode(GoogleAPIError.self, from: data) {
                 throw SheetsError.apiError(apiError)
            }
            throw SheetsError.invalidResponse(status: httpResponse.statusCode)
        }
    }
}

// Internal request model
struct CreateFileRequest: Encodable {
    let name: String
    let mimeType: String
    let parents: [String]?
}
