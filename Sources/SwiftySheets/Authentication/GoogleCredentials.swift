import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import OAuth2

public protocol GoogleCredentials: Sendable {
    func authenticate(_ request: URLRequest) async throws -> URLRequest
}

public enum DriveScope {
    public static let readonly = "https://www.googleapis.com/auth/drive.readonly"
    public static let readwrite = "https://www.googleapis.com/auth/drive"
}

public enum SpreadsheetScope {
    public static let readonly = "https://www.googleapis.com/auth/spreadsheets.readonly"
    public static let readwrite = "https://www.googleapis.com/auth/spreadsheets"
}

// @unchecked Sendable: ServiceAccountTokenProvider is not marked Sendable but is safe
// to use from multiple contexts — it manages its own internal synchronization for token caching.
public struct ServiceAccountCredentials: GoogleCredentials, @unchecked Sendable {
    private let credentials: ServiceAccountTokenProvider

    public init(
        jsonPath: String,
        scopes: [String] = [SpreadsheetScope.readwrite, DriveScope.readwrite]
    ) throws {
        guard let jsonData = try? Data(contentsOf: URL(fileURLWithPath: jsonPath)) else {
            throw SheetsError.invalidCredentials(message: "Failed to load service account JSON file")
        }

        guard let credentials = ServiceAccountTokenProvider(credentialsData: jsonData, scopes: scopes) else {
            throw SheetsError.invalidCredentials(message: "Failed to parse service account JSON file")
        }

        self.credentials = credentials
    }

    public func authenticate(_ request: URLRequest) async throws -> URLRequest {
        let token = try await getAccessToken()
        var authenticatedRequest = request
        authenticatedRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return authenticatedRequest
    }

    private func getAccessToken() async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            // withToken either throws (callback never called) or succeeds (callback called exactly once).
            // The do/catch ensures the continuation is always resumed exactly once.
            do {
                try credentials.withToken { token, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else if let token = token?.AccessToken {
                        continuation.resume(returning: token)
                    } else {
                        continuation.resume(throwing: SheetsError.authenticationFailed)
                    }
                }
            } catch {
                continuation.resume(throwing: SheetsError.authenticationFailed)
            }
        }
    }
}

/// Credentials using a direct OAuth 2.0 access token.
/// Useful for mobile/desktop apps where the user signs in via a native flow (e.g. GoogleSignIn).
public struct OAuthCredentials: GoogleCredentials, Sendable {
    private let tokenProvider: @Sendable () async -> String?

    /// Initialize with a static access token.
    /// - Parameter accessToken: The OAuth 2.0 access token.
    public init(accessToken: String) {
        self.tokenProvider = { accessToken }
    }

    /// Initialize with an async token provider.
    /// Useful if you need to fetch or refresh the token dynamically.
    /// - Parameter tokenProvider: A closure that returns an optional access token.
    public init(tokenProvider: @escaping @Sendable () async -> String?) {
        self.tokenProvider = tokenProvider
    }
    
    public func authenticate(_ request: URLRequest) async throws -> URLRequest {
        guard let token = await tokenProvider() else {
            throw SheetsError.authenticationFailed
        }
        var authenticatedRequest = request
        authenticatedRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return authenticatedRequest
    }
}

/// Credentials using a Google Cloud API Key.
/// Useful for accessing public data (read-only).
public struct APIKeyCredentials: GoogleCredentials, Sendable {
    private let apiKey: String
    
    /// Initialize with an API Key.
    /// - Parameter apiKey: The API key from Google Cloud Console.
    public init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    public func authenticate(_ request: URLRequest) async throws -> URLRequest {
        guard let url = request.url else {
            return request
        }
        
        var components = URLComponents(url: url, resolvingAgainstBaseURL: true)
        var queryItems = components?.queryItems ?? []
        queryItems.append(URLQueryItem(name: "key", value: apiKey))
        components?.queryItems = queryItems
        
        guard let finalUrl = components?.url else {
            return request
        }
        
        var authenticatedRequest = request
        authenticatedRequest.url = finalUrl
        return authenticatedRequest
    }
}
