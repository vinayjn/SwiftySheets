import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Shared response handling for both Sheets and Drive API calls.
/// Extracts HTTP status mapping, error decoding, and retry-after parsing.
enum ResponseHandler {

    static func validateAndDecode<T: Decodable & Sendable>(
        data: Data,
        response: URLResponse
    ) throws(SheetsError) -> T {
        let httpResponse = try validateHTTPResponse(response)

        guard (200...299).contains(httpResponse.statusCode) else {
            throw mapError(data: data, statusCode: httpResponse.statusCode, headers: httpResponse.allHeaderFields)
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw SheetsError.decodingError(context: "Failed to decode \(T.self): \(error.localizedDescription)")
        }
    }

    static func validate(
        data: Data,
        response: URLResponse
    ) throws(SheetsError) {
        let httpResponse = try validateHTTPResponse(response)

        guard (200...299).contains(httpResponse.statusCode) else {
            throw mapError(data: data, statusCode: httpResponse.statusCode, headers: httpResponse.allHeaderFields)
        }
    }

    private static func validateHTTPResponse(_ response: URLResponse) throws(SheetsError) -> HTTPURLResponse {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SheetsError.invalidResponse(status: 500)
        }
        return httpResponse
    }

    static func mapError(data: Data, statusCode: Int, headers: [AnyHashable: Any]) -> SheetsError {
        let retryAfter = extractRetryAfter(from: headers)

        switch statusCode {
        case 401:
            return .authenticationFailed
        case 403:
            if let apiError = try? JSONDecoder().decode(GoogleAPIError.self, from: data) {
                if apiError.error.status == "PERMISSION_DENIED" {
                    return .permissionDenied(message: apiError.error.message)
                } else if apiError.error.message.contains("quota") {
                    return .quotaExceeded(retryAfter: retryAfter)
                }
                return .apiError(apiError)
            }
            return .permissionDenied(message: "Access denied")
        case 404:
            return .spreadsheetNotFound(message: "Resource not found")
        case 429:
            return .rateLimitExceeded(retryAfter: retryAfter)
        default:
            if let apiError = try? JSONDecoder().decode(GoogleAPIError.self, from: data) {
                return .apiError(apiError)
            }
            return .invalidResponse(status: statusCode)
        }
    }

    private static func extractRetryAfter(from headers: [AnyHashable: Any]) -> TimeInterval? {
        if let retryAfterStr = headers["Retry-After"] as? String {
            return TimeInterval(retryAfterStr)
        }
        return nil
    }
}
