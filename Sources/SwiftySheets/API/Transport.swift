import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

protocol Transport: Sendable {
    func send(_ request: URLRequest) async throws -> (Data, URLResponse)
}
