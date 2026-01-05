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

/// Errors thrown by SwiftySheets API operations.
/// All throwing functions use typed throws: `throws(SheetsError)`
public enum SheetsError: Error, Sendable {
    case invalidResponse(status: Int)
    case authenticationFailed
    case invalidRequest
    case networkError(String)  // Changed from Error to String for Sendable
    case invalidCredentials(message: String)
    case spreadsheetNotFound(message: String)
    case sheetNotFound(message: String)
    case apiError(GoogleAPIError)
    case quotaExceeded(retryAfter: TimeInterval?)
    case permissionDenied(message: String)
    case rateLimitExceeded(retryAfter: TimeInterval?)
    case invalidRange(message: String)
}
