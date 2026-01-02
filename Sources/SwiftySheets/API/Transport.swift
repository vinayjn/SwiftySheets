import Foundation

public protocol Transport: Sendable {
    func send(_ request: URLRequest) async throws -> (Data, URLResponse)
}
