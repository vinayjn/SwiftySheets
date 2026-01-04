@testable import SwiftySheets
import XCTest

final class EndpointTests: XCTestCase {
    
    func testUpdateValuesEndpoint() throws {
        let endpoint = Endpoint.updateValues(
            spreadsheetId: "test-id",
            range: "A1:B2",
            valueInputOption: "USER_ENTERED"
        )
        
        let url = try endpoint.url()
        XCTAssertEqual(url.absoluteString, "https://sheets.googleapis.com/v4/spreadsheets/test-id/values/A1:B2?valueInputOption=USER_ENTERED")
        
        let request = try endpoint.request()
        XCTAssertEqual(request.httpMethod, "PUT")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
    }
    
    func testBatchUpdateEndpoint() throws {
        let endpoint = Endpoint.batchUpdate(spreadsheetId: "test-id")
        
        let url = try endpoint.url()
        XCTAssertEqual(url.absoluteString, "https://sheets.googleapis.com/v4/spreadsheets/test-id:batchUpdate")
        
        let request = try endpoint.request()
        XCTAssertEqual(request.httpMethod, "POST")
    }
    
    func testAppendValuesEndpoint() throws {
        let endpoint = Endpoint.appendValues(
            spreadsheetId: "test-id",
            range: "A1:B1",
            valueInputOption: "RAW"
        )
        
        let url = try endpoint.url()
        XCTAssertEqual(url.absoluteString, "https://sheets.googleapis.com/v4/spreadsheets/test-id/values/A1:B1:append?valueInputOption=RAW")
    }
}
