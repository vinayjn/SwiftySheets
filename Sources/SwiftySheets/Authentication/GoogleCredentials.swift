import Foundation
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
