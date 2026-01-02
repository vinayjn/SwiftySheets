import Foundation

public enum Endpoint {
    private static let baseURL = "https://sheets.googleapis.com/v4/spreadsheets"

    case spreadsheet(id: String)
    case values(
        spreadsheetId: String,
        range: String,
        valueRenderOption: String,
        dateTimeRenderOption: String
    )
    case updateValues(
        spreadsheetId: String,
        range: String,
        valueInputOption: String
    )
    case batchUpdate(spreadsheetId: String)
    case appendValues(
        spreadsheetId: String,
        range: String,
        valueInputOption: String
    )
}

extension Endpoint {
    private static let apiScheme = "https"
    private static let apiHost = "sheets.googleapis.com"

    func url() throws -> URL {
        var components = URLComponents()
        components.scheme = Self.apiScheme
        components.host = Self.apiHost
        
        switch self {
        case let .spreadsheet(id):
            components.path = "/v4/spreadsheets/\(id)"
            return try components.asURL()

        case let .values(id, range, valueRenderOption, dateTimeRenderOption):
            components.path = "/v4/spreadsheets/\(id)/values/\(range)"
            components.queryItems = [
                URLQueryItem(name: "valueRenderOption", value: valueRenderOption),
                URLQueryItem(name: "dateTimeRenderOption", value: dateTimeRenderOption),
            ]
            return try components.asURL()
            
        case let .updateValues(id, range, valueInputOption):
            components.path = "/v4/spreadsheets/\(id)/values/\(range)"
            components.queryItems = [
                URLQueryItem(name: "valueInputOption", value: valueInputOption)
            ]
            return try components.asURL()
            
        case let .batchUpdate(id):
            components.path = "/v4/spreadsheets/\(id):batchUpdate"
            return try components.asURL()
            
        case let .appendValues(id, range, valueInputOption):
            components.path = "/v4/spreadsheets/\(id)/values/\(range):append"
            components.queryItems = [
                URLQueryItem(name: "valueInputOption", value: valueInputOption)
            ]
            return try components.asURL()
        }
    }

    func request() throws -> URLRequest {
        var request = try URLRequest(url: url())
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        switch self {
        case .spreadsheet, .values:
            request.httpMethod = "GET"
        case .batchUpdate, .appendValues:
            request.httpMethod = "POST"
        case .updateValues:
            request.httpMethod = "PUT"
        }

        return request
    }
    
    func request(with body: Data) throws -> URLRequest {
        var request = try self.request()
        request.httpBody = body
        return request
    }
}

extension URLComponents {
    func asURL() throws -> URL {
        guard let url = self.url else {
            throw SheetsError.invalidRequest
        }
        return url
    }
}
