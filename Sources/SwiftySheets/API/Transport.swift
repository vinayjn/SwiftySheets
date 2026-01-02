import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public protocol Transport: Sendable {
    func send(_ request: URLRequest) async throws -> (Data, URLResponse)
}
