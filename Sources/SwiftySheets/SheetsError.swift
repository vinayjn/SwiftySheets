import Foundation

public enum SheetsError: Error {
    case invalidResponse(status: Int)
    case authenticationFailed
    case invalidRequest
    case networkError(Error)
    case invalidCredentials(message: String)
} 