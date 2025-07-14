import Foundation

public struct GoogleAPIError: Codable, Sendable {
    public let error: ErrorDetails
    
    public struct ErrorDetails: Codable, Sendable {
        public let code: Int
        public let message: String
        public let status: String
        public let details: [ErrorDetail]?
        
        public struct ErrorDetail: Codable, Sendable {
            public let type: String?
            public let reason: String?
            public let domain: String?
        }
    }
}

public enum SheetsError: Error {
    case invalidResponse(status: Int)
    case authenticationFailed
    case invalidRequest
    case networkError(Error)
    case invalidCredentials(message: String)
    case spreadsheetNotFound(message: String)
    case sheetNotFound(message: String)
    case apiError(GoogleAPIError)
    case quotaExceeded(retryAfter: TimeInterval?)
    case permissionDenied(message: String)
    case rateLimitExceeded(retryAfter: TimeInterval?)
}
