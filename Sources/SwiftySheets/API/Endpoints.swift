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
}

extension Endpoint {
    func url() throws -> URL {
        switch self {
        case let .spreadsheet(id):
            guard let url = URL(string: "\(Self.baseURL)/\(id)") else {
                throw SheetsError.invalidRequest
            }
            return url

        case let .values(id, range, valueRenderOption, dateTimeRenderOption):
            var components = URLComponents(string: "\(Self.baseURL)/\(id)/values/\(range)")
            components?.queryItems = [
                URLQueryItem(name: "valueRenderOption", value: valueRenderOption),
                URLQueryItem(name: "dateTimeRenderOption", value: dateTimeRenderOption),
            ]
            guard let url = components?.url else {
                throw SheetsError.invalidRequest
            }
            return url
        }
    }

    func request() throws -> URLRequest {
        var request = try URLRequest(url: url())
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        switch self {
        case .spreadsheet, .values:
            request.httpMethod = "GET"
        }

        return request
    }
}
