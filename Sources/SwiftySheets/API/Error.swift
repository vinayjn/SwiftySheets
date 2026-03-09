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
    case networkError(String)
    case invalidCredentials(message: String)
    case spreadsheetNotFound(message: String)
    case sheetNotFound(message: String)
    case apiError(GoogleAPIError)
    case quotaExceeded(retryAfter: TimeInterval?)
    case permissionDenied(message: String)
    case rateLimitExceeded(retryAfter: TimeInterval?)
    case invalidRange(message: String)
    case decodingError(context: String)
}

extension SheetsError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidResponse(let status):
            return "Invalid API response (HTTP \(status))"
        case .authenticationFailed:
            return "Authentication failed — check your credentials"
        case .invalidRequest:
            return "The request could not be constructed"
        case .networkError(let reason):
            return "Network error: \(reason)"
        case .invalidCredentials(let message):
            return "Invalid credentials: \(message)"
        case .spreadsheetNotFound(let message):
            return "Spreadsheet not found: \(message)"
        case .sheetNotFound(let message):
            return "Sheet not found: \(message)"
        case .apiError(let error):
            return "Google API error \(error.error.code): \(error.error.message)"
        case .quotaExceeded(let retryAfter):
            if let seconds = retryAfter {
                return "Quota exceeded — retry after \(Int(seconds))s"
            }
            return "Quota exceeded"
        case .permissionDenied(let message):
            return "Permission denied: \(message)"
        case .rateLimitExceeded(let retryAfter):
            if let seconds = retryAfter {
                return "Rate limit exceeded — retry after \(Int(seconds))s"
            }
            return "Rate limit exceeded"
        case .invalidRange(let message):
            return "Invalid range: \(message)"
        case .decodingError(let context):
            return "Decoding error: \(context)"
        }
    }
}
