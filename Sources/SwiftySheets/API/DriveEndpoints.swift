import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public enum DriveEndpoint {
    private static let apiScheme = "https"
    private static let apiHost = "www.googleapis.com"
    private static let basePath = "/drive/v3"

    case delete(fileId: String)
    case list(query: String)
}

extension DriveEndpoint {
    func url() throws -> URL {
        var components = URLComponents()
        components.scheme = Self.apiScheme
        components.host = Self.apiHost
        
        switch self {
        case let .delete(fileId):
            components.path = "\(Self.basePath)/files/\(fileId)"
            return try components.asURL()
            
        case let .list(query):
            components.path = "\(Self.basePath)/files"
            components.queryItems = [
                URLQueryItem(name: "q", value: query),
                URLQueryItem(name: "fields", value: "files(id, name, mimeType)")
            ]
            return try components.asURL()
        }
    }

    func request() throws -> URLRequest {
        var request = try URLRequest(url: url())
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        switch self {
        case .delete:
            request.httpMethod = "DELETE"
        case .list:
            request.httpMethod = "GET"
        }

        return request
    }
}
