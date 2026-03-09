import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct DriveClient: Sendable {
    private let transport: SheetsTransport
    private let baseURL = URL(string: "https://www.googleapis.com/drive/v3")!

    init(transport: SheetsTransport) {
        self.transport = transport
    }

    // MARK: - Read

    internal func list(query: String? = nil, pageSize: Int? = nil) async throws(SheetsError) -> [DriveFile] {
        let resolvedPageSize = pageSize ?? 1000
        var allFiles: [DriveFile] = []
        var pageToken: String? = nil

        repeat {
            var baseQueryItems: [URLQueryItem] = [
                URLQueryItem(name: "fields", value: "nextPageToken,files(id,name,mimeType)"),
                URLQueryItem(name: "pageSize", value: String(resolvedPageSize))
            ]

            if let query = query, !query.isEmpty {
                baseQueryItems.append(URLQueryItem(name: "q", value: query))
            }

            if let token = pageToken {
                baseQueryItems.append(URLQueryItem(name: "pageToken", value: token))
            }

            var url = baseURL.appendingPathComponent("files")
            url.append(queryItems: baseQueryItems)

            let request = URLRequest(url: url)
            let (data, response) = try await sendRequest(request)
            let fileList: DriveFileList = try ResponseHandler.validateAndDecode(data: data, response: response)

            allFiles.append(contentsOf: fileList.files)
            pageToken = fileList.nextPageToken
        } while pageToken != nil

        return allFiles
    }

    /// Create a fluent query builder for listing Drive files.
    /// ```swift
    /// let reports = try await client.drive.list()
    ///     .spreadsheets()
    ///     .notTrashed()
    ///     .nameContains("Report")
    ///     .execute()
    /// ```
    public func list() -> DriveListBuilder {
        DriveListBuilder(driveClient: self)
    }

    // MARK: - Write

    public enum FileType: Sendable {
        case spreadsheet
        case folder

        var mimeType: String {
            switch self {
            case .spreadsheet: return "application/vnd.google-apps.spreadsheet"
            case .folder: return "application/vnd.google-apps.folder"
            }
        }
    }

    public func create(name: String, type: FileType = .spreadsheet, parents: [String]? = nil) async throws(SheetsError) -> DriveFile {
        let url = baseURL.appendingPathComponent("files")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let metadata = CreateFileRequest(name: name, mimeType: type.mimeType, parents: parents)
        guard let body = try? JSONEncoder().encode(metadata) else {
            throw .invalidRequest
        }
        request.httpBody = body

        let (data, response) = try await sendRequest(request)
        return try ResponseHandler.validateAndDecode(data: data, response: response)
    }

    public func delete(id: String) async throws(SheetsError) {
        let url = baseURL.appendingPathComponent("files").appendingPathComponent(id)
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"

        let (data, response) = try await sendRequest(request)
        try ResponseHandler.validate(data: data, response: response)
    }

    private func sendRequest(_ request: URLRequest) async throws(SheetsError) -> (Data, URLResponse) {
        do {
            return try await transport.send(request)
        } catch {
            throw .networkError(error.localizedDescription)
        }
    }
}

// Internal request model
struct CreateFileRequest: Encodable, Sendable {
    let name: String
    let mimeType: String
    let parents: [String]?
}
