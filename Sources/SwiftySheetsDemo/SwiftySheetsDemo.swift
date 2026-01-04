import Foundation
import SwiftySheets

@SheetRow
struct DemoUser {
    @Column("A") var name: String
    @Column("B") var email: String
    @Column(index: 2) var score: Int
    @Column("D") var isActive: Bool
    @Column("E", format: "yyyy-MM-dd") var joinDate: Date
    @Column("F") var nickname: String?
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
            try await spreadsheet.refreshMetadata()
            
            // 4. Raw Data Operations (Headers)
            print("📝 [Raw] Writing header row...")
            _ = try await spreadsheet.updateValues(
                range: #Range("DemoSheet!A1:F1"),
                values: [["Name", "Email", "Score", "Active", "Joined", "Nickname"]]
            )
            
             // 4b. Format Header
             print("🎨 Formatting header...")
             let headerFormat = CellFormat(
                 backgroundColor: .blue,
                 textFormat: TextFormat(foregroundColor: .white, bold: true)
             )
             try await spreadsheet.format(range: "DemoSheet!A1:F1", format: headerFormat)
             print("✅ Header formatted.")
             
             // 5. Type-Safe Write using Macros
            print("✍️ [Type-Safe] Writing user data...")
            
            // Helper to create dates
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let date1 = formatter.date(from: "2023-01-01")!
            let date2 = formatter.date(from: "2023-05-15")!
            
            // Note: init(name:email:...) memberwise initializer is auto-generated
            let users = [
                DemoUser(name: "Alice", email: "alice@test.com", score: 100, isActive: true, joinDate: date1, nickname: "Ally"),
                DemoUser(name: "Bob", email: "bob@test.com", score: 250, isActive: false, joinDate: date2, nickname: nil)
            ]
            
            // Encode rows (SheetRowEncodable is auto-conformed)
            let values = try users.map { try $0.encodeRow() }
            
            try await spreadsheet.updateValues(
                range: "DemoSheet!A2",
                values: values
            )
            print("✅ Users written.")
            
            // 6. Type-Safe Append
            print("➕ [Append] Appending a new user...")
            let date3 = formatter.date(from: "2023-12-01")!
            let newUser = DemoUser(name: "Charlie", email: "charlie@test.com", score: 50, isActive: true, joinDate: date3, nickname: "Chuck")
            
            try await spreadsheet.appendValues(
                range: "DemoSheet!A1",
                values: [try newUser.encodeRow()]
            )
            print("✅ User appended.")
            
            // 9. DX: Sheet Properties & Fluent Range
            let props = try spreadsheet.sheet(named: "DemoSheet").properties
            print("📊 Sheet ID: \(props.sheetId), Index: \(props.index), Rows: \(props.gridProperties.rowCount)")
            
            // Fluent Range Builder Example
            let fluentRange = SheetRange.root("DemoSheet")
                .from(col: "A", row: 2)
                .to(col: "Z")
            print("🏗️ Fluent Range: \(fluentRange)") // Output: DemoSheet!A2:Z
            
            // 10. DX: Resize Sheet
            print("📏 Resizing 'DemoSheet' to 50 rows x 5 columns...")
            // 7. Type-Safe Read
            print("📖 [Type-Safe] Reading all users...")
            var readUsers = try await spreadsheet.values(
                range: "DemoSheet!A2:F", // Read columns A to F
                type: DemoUser.self
            )
            
            for user in readUsers {
                let nick = user.nickname ?? "-"
                let dateStr = formatter.string(from: user.joinDate)
                print("   - \(user.name): Score=\(user.score), Active=\(user.isActive), Joined=\(dateStr), Nick=\(nick)")
            }
            
            // 8. Sorting
            print("🔃 Sorting by Score (Column C, Index 2)...")
            try await spreadsheet.sort(range: "DemoSheet!A2:F", column: 2, ascending: false)
            print("✅ Sorted.")
            
            readUsers = try await spreadsheet.values(range: "DemoSheet!A2:F", type: DemoUser.self)
            print("   Top Scorer: \(readUsers.first?.name ?? "None")")

            // 9. Clear Values
            print("🧹 Clearing data...")
            try await spreadsheet.clearValues(range: "DemoSheet!A2:F")
            print("✅ Data cleared.")
            
            // 12. Clean up
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
