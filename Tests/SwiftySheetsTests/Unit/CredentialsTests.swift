@testable import SwiftySheets
import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

final class CredentialsTests: XCTestCase {
    
    // MARK: - OAuthCredentials Tests
    
    func testOAuthCredentials_AddedBearerToken() async throws {
        let credentials = OAuthCredentials(accessToken: "test-token-123")
        let url = URL(string: "https://sheets.googleapis.com/test")!
        let request = URLRequest(url: url)
        
        let authenticatedRequest = try await credentials.authenticate(request)
        
        XCTAssertEqual(authenticatedRequest.value(forHTTPHeaderField: "Authorization"), "Bearer test-token-123")
    }
    
    func testOAuthCredentials_AsyncProvider() async throws {
        let credentials = OAuthCredentials {
            return "dynamic-token-456"
        }
        let url = URL(string: "https://sheets.googleapis.com/test")!
        let request = URLRequest(url: url)
        
        let authenticatedRequest = try await credentials.authenticate(request)
        
        XCTAssertEqual(authenticatedRequest.value(forHTTPHeaderField: "Authorization"), "Bearer dynamic-token-456")
    }
    
    func testOAuthCredentials_ThrowsOnNilToken() async throws {
        let credentials = OAuthCredentials {
            return nil
        }
        let url = URL(string: "https://sheets.googleapis.com/test")!
        let request = URLRequest(url: url)
        
        do {
            _ = try await credentials.authenticate(request)
            XCTFail("Should have thrown authenticationFailed")
        } catch SheetsError.authenticationFailed {
            // Success
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    // MARK: - APIKeyCredentials Tests
    
    func testAPIKeyCredentials_AppendsQueryParameter() async throws {
        let credentials = APIKeyCredentials(apiKey: "abc-xyz-key")
        let url = URL(string: "https://sheets.googleapis.com/test")!
        let request = URLRequest(url: url)
        
        let authenticatedRequest = try await credentials.authenticate(request)
        
        guard let authenticatedUrl = authenticatedRequest.url else {
            XCTFail("URL should not be nil")
            return
        }
        
        let components = URLComponents(url: authenticatedUrl, resolvingAgainstBaseURL: true)
        let queryItems = components?.queryItems
        
        XCTAssertTrue(queryItems?.contains(where: { $0.name == "key" && $0.value == "abc-xyz-key" }) ?? false)
    }
    
    func testAPIKeyCredentials_PreservesExistingQueryParams() async throws {
        let credentials = APIKeyCredentials(apiKey: "abc-xyz-key")
        let url = URL(string: "https://sheets.googleapis.com/test?foo=bar")!
        let request = URLRequest(url: url)
        
        let authenticatedRequest = try await credentials.authenticate(request)
        
        guard let authenticatedUrl = authenticatedRequest.url else {
            XCTFail("URL should not be nil")
            return
        }
        
        let components = URLComponents(url: authenticatedUrl, resolvingAgainstBaseURL: true)
        let queryItems = components?.queryItems
        
        XCTAssertTrue(queryItems?.contains(where: { $0.name == "key" && $0.value == "abc-xyz-key" }) ?? false)
        XCTAssertTrue(queryItems?.contains(where: { $0.name == "foo" && $0.value == "bar" }) ?? false)
    }
}
