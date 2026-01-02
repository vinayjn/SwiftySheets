import Foundation
import SwiftySheets

@SheetRow
struct DemoUser: SheetRowCodable {
    @Column("A") var name: String
    @Column("B") var email: String
    @Column(index: 2) var score: Int
}

@main
struct SwiftySheetsDemo {
    static func main() async {
        print("🚀 Starting SwiftySheets Demo...")
        
        // 1. Setup Credentials
        // Read configuration from environment variables
        guard let jsonPath = ProcessInfo.processInfo.environment["SWIFTYSHEETS_SERVICE_ACCOUNT_PATH"] else {
            print("❌ Missing environment variable: SWIFTYSHEETS_SERVICE_ACCOUNT_PATH")
            exit(1)
        }

        // 2. Determine Spreadsheet ID
        let envSpreadsheetId = ProcessInfo.processInfo.environment["SWIFTYSHEETS_SPREADSHEET_ID"]
        var createdSpreadsheetId: String? = nil
        var spreadsheet: Spreadsheet
        
        do {
            let credentials = try ServiceAccountCredentials(jsonPath: jsonPath)
            let client = Client(credentials: credentials)
            
            if let id = envSpreadsheetId {
                print("ℹ️ Using ID from ENV: \(id)")
                spreadsheet = try await client.spreadsheet(id: id)
            } else {
                print("📝 No ID provided. Creating a temporary spreadsheet...")
                let title = "SwiftySheets Demo \(Int(Date().timeIntervalSince1970))"
                spreadsheet = try await client.createSpreadsheet(title: title)
                createdSpreadsheetId = spreadsheet.metadata.spreadsheetId
                print("✅ Created Spreadsheet: \(title) (ID: \(spreadsheet.metadata.spreadsheetId))")
            }
            
            print("✅ Ready to work on: \(spreadsheet.metadata.properties.title)")
            
            // 3. Add a Sheet using DSL
            print("PAGE: Adding a new sheet 'DemoSheet'...")
            
            // Check if it exists first and delete (Clean Slate)
            if let existingSheet = try? spreadsheet.sheet(named: "DemoSheet") {
                let idToDelete = existingSheet.properties.sheetId
                print("⚠️ 'DemoSheet' already exists. Deleting it first...")
                try await spreadsheet.batchUpdate {
                    DeleteSheet(id: idToDelete)
                }
                // Refresh metadata after deletion to ensure local state is synced
                try await spreadsheet.refreshMetadata()
            }
            
            let response = try await spreadsheet.batchUpdate {
                AddSheet("DemoSheet")
            }
            
            // Extract the new sheet ID from response
            let newSheetId = response.replies?.first?.addSheet?.properties.sheetId
            guard let sheetId = newSheetId else {
                print("❌ Failed to get new sheet ID")
                exit(1)
            }
            print("✅ Sheet added with ID: \(sheetId)")
            
            // 4. Raw Data Operations (Non-Type Safe)
            print("📝 [Raw] Writing header row...")
            _ = try await spreadsheet.updateValues(
                range: "DemoSheet!A1:C1",
                values: [["Name", "Email", "Score"]]
            )
            
             print("📖 [Raw] Reading headers back...")
             let headers = try await spreadsheet.values(range: "DemoSheet!A1:C1")
             print("   Headers: \(headers.first ?? [])")
             
             // 4b. Format Header
             print("🎨 Formatting header...")
             let headerFormat = CellFormat(
                 backgroundColor: .blue,
                 textFormat: TextFormat(fgColor: .white, bold: true)
             )
             try await spreadsheet.format(range: "DemoSheet!A1:C1", format: headerFormat)
             print("✅ Header formatted.")
             
             // 5. Type-Safe Write using Macros
            print("✍️ [Type-Safe] Writing user data...")
            let users = [
                try DemoUser(row: ["Alice", "alice@test.com", "100"]),
                try DemoUser(row: ["Bob", "bob@test.com", "250"])
            ]
            
            // New Generic API
            try await spreadsheet.updateValues(
                range: "DemoSheet!A2",
                values: users
            )
            print("✅ Users written.")
            
            // 6. Type-Safe Append
            print("➕ [Append] Appending a new user...")
            let newUser = try DemoUser(row: ["Charlie", "charlie@test.com", "50"])
            try await spreadsheet.appendValues(
                range: "DemoSheet!A1", // A1 is enough, Google finds the next empty row
                values: [newUser]
            )
            print("✅ User appended.")
            
            // 7. Type-Safe Read
            print("📖 [Type-Safe] Reading all users...")
            let readUsers = try await spreadsheet.values(
                range: "DemoSheet!A2:C", // Skip header
                type: DemoUser.self
            )
            
            for user in readUsers {
                print("   - \(user.name) (\(user.email)): \(user.score) points")
            }
            
            // 8. Clean up
            print("🧹 Cleaning up (Deleting Sheet ID: \(sheetId))...")
            try await spreadsheet.batchUpdate {
                DeleteSheet(id: sheetId)
            }
            print("✅ Sheet deleted.")
            
            print("🎉 Demo completed successfully!")
            
            // 9. Cleanup Created Spreadsheet
            if let createdId = createdSpreadsheetId {
                print("🗑️ Deleting temporary spreadsheet: \(createdId)...")
                try await client.deleteSpreadsheet(id: createdId)
                print("✅ Spreadsheet deleted.")
            }
            
        } catch {
            print("❌ Error: \(error)")
            exit(1)
        }
    }
}
