import Foundation

public struct Spreadsheet {
    private let client: SheetsClient
    private let id: String
    
    init(client: SheetsClient, id: String) {
        self.client = client
        self.id = id
    }
    
    public func getValues(range: String) async throws -> [[String]] {
        var urlComponents = URLComponents(string: "\(client.baseURL)/\(id)/values/\(range)")!
        urlComponents.queryItems = [
            URLQueryItem(name: "valueRenderOption", value: "UNFORMATTED_VALUE")
        ]
        
        let request = URLRequest(url: urlComponents.url!)
        let response: ValueRange = try await client.makeRequest(request)
        return response.values
    }
}

struct ValueRange: Decodable {
    let range: String
    let values: [[String]]
} 
