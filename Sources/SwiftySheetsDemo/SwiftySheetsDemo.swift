import Foundation
import SwiftySheets

@SheetRow
struct DemoUser {
    @Column("A") var name: String
    @Column("B") var email: String
    @Column("C") var score: Int
    @Column("D") var isActive: Bool
    @Column("E", format: "yyyy-MM-dd") var joinDate: Date
    @Column("F") var nickname: String?
}

@main
struct SwiftySheetsDemo {
    static func main() async {
        var app = DemoApp()
        await app.run()
    }
}

struct DemoApp {
    var client: Client?
    var spreadsheet: Spreadsheet?
    
    // Constant string
    let demoSheetName = "DemoSheet"
    
    mutating func run() async {
        print("🚀 Starting SwiftySheets Interactive Demo...")
        do {
            try await setup()
            await runMainLoop()
        } catch {
            print("❌ Fatal Error: \(error)")
            exit(1)
        }
    }
    
    mutating func setup() async throws {
        // 1. Setup Credentials
        guard let jsonPath = ProcessInfo.processInfo.environment["SWIFTYSHEETS_SERVICE_ACCOUNT_PATH"] else {
            print("❌ Missing environment variable: SWIFTYSHEETS_SERVICE_ACCOUNT_PATH")
            exit(1)
        }
        
        let credentials = try ServiceAccountCredentials(jsonPath: jsonPath)
        client = Client(credentials: credentials)
        
        // 2. Check for optional ENV ID to auto-open
        if let envId = ProcessInfo.processInfo.environment["SWIFTYSHEETS_SPREADSHEET_ID"], let client = client {
            print("ℹ️ Auto-opening ID from ENV: \(envId)")
            do {
                spreadsheet = try await client.spreadsheet(id: envId)
                print("✅ Opened: \(spreadsheet?.metadata.properties.title ?? "Unknown")")
            } catch {
                 print("⚠️ Failed to open ENV ID: \(error)")
            }
        }
    }
    
    mutating func runMainLoop() async {
        var shouldExit = false
        while !shouldExit {
            print("\n-------------------------------------------")
            if let s = spreadsheet {
                print("📍 SPREADSHEET MODE: \(s.metadata.properties.title)")
                shouldExit = await runSpreadsheetMenu()
            } else {
                print("📍 MANAGER MODE: (No Spreadsheet Open)")
                // Pass client safely
                guard client != nil else {
                     print("❌ Client not initialized")
                     return
                }
                shouldExit = await runManagerMenu()
            }
            print("-------------------------------------------")
        }
        print("👋 Exiting Demo.")
    }

    // MARK: - Manager Mode (Drive API)
    
    mutating func runManagerMenu() async -> Bool {
        print("1. 📂 List Spreadsheets")
        print("2. 🆕 Create New Spreadsheet")
        print("3. 🆔 Open by ID")
        print("0. 🚪 Exit")
        print("Enter choice: ", terminator: "")
        
        guard let choice = readLine() else { return true }
        print("")
        
        do {
            switch choice {
            case "1": try await listSpreadsheets()
            case "2": try await createNewSpreadsheet()
            case "3": try await openById()
            case "0": return true
            default: print("❌ Invalid choice")
            }
        } catch {
            print("⚠️ Action Failed: \(error)")
        }
        return false
    }
    
    mutating func listSpreadsheets() async throws {
        guard let client = client else { return }
        print("🔍 Fetching spreadsheets...")
        let files = try await client.listSpreadsheets()
        
        if files.isEmpty {
            print("   (No spreadsheets found)")
            return
        }
        
        print("\n📄 Found \(files.count) spreadsheets:")
        for (index, file) in files.enumerated() {
            print("   [\(index + 1)] \(file.name) (ID: \(file.id))")
        }
        
        print("\nOp: Enter number to open, 'd' + number to delete (e.g. d1), or Enter to cancel: ", terminator: "")
        guard let input = readLine(), !input.isEmpty else { return }
        
        if input.starts(with: "d") {
            // Delete flow
            let indexStr = input.dropFirst()
            if let index = Int(indexStr), index > 0, index <= files.count {
                let file = files[index - 1]
                print("🗑️ Deleting '\(file.name)'...")
                try await client.deleteSpreadsheet(id: file.id)
                print("✅ Deleted.")
            }
        } else {
            // Open flow
            if let index = Int(input), index > 0, index <= files.count {
                let file = files[index - 1]
                print("Opening '\(file.name)'...")
                spreadsheet = try await client.spreadsheet(id: file.id)
            }
        }
    }
    
    mutating func createNewSpreadsheet() async throws {
        guard let client = client else { return }
        print("Enter title for new spreadsheet: ", terminator: "")
        let title = readLine() ?? "Untitled"
        
        print("Creating '\(title)'...")
        spreadsheet = try await client.createSpreadsheet(title: title)
        print("✅ Created and Opened (ID: \(spreadsheet?.metadata.spreadsheetId ?? "?"))")
    }
    
    mutating func openById() async throws {
        guard let client = client else { return }
        print("Enter Spreadsheet ID: ", terminator: "")
        guard let id = readLine(), !id.isEmpty else { return }
        
        print("Opening ID: \(id)...")
        spreadsheet = try await client.spreadsheet(id: id)
        print("✅ Opened.")
    }

    // MARK: - Spreadsheet Mode
    
    mutating func runSpreadsheetMenu() async -> Bool {
        guard spreadsheet != nil else { return false }
        
        print("1. 📄 Show Info")
        print("2. ➕ Add/Reset Demo Sheet")
        print("3. 📝 Write Dummy Data")
        print("4. 📖 Read Data")
        print("5. ⬇️ Append User")
        print("6. 🔃 Sort Data")
        print("7. 🧹 Clear Data")
        print("8. 📏 Resize Sheet (DSL)")
        print("9. 📊 Bulk Data + Pagination Demo")
        print("c. 🔙 Close Spreadsheet (Back to Menu)")
        print("0. 🗑️ Delete This Spreadsheet")
        print("Enter choice: ", terminator: "")
        
        guard let choice = readLine() else { return true }
        print("")

        do {
            switch choice {
            case "1": try await showInfo()
            case "2": try await setupDemoSheet()
            case "3": try await writeDummyData()
            case "4": try await readData()
            case "5": try await appendUser()
            case "6": try await sortData()
            case "7": try await clearData()
            case "8": try await resizeSheet()
            case "9": try await bulkDataAndPaginationDemo()
            case "c": 
                spreadsheet = nil
                print("🔙 Closed.")
            case "0":
                try await deleteCurrentSpreadsheet()
            default: print("❌ Invalid choice")
            }
        } catch {
            print("⚠️ Action Failed: \(error)")
        }
        
        return false // Don't exit app, just loop
    }
    
    mutating func deleteCurrentSpreadsheet() async throws {
        guard let client = client, let s = spreadsheet else { return }
        print("💥 Are you sure you want to DELETE '\(s.metadata.properties.title)'? (y/n): ", terminator: "")
        if readLine() == "y" {
            try await client.deleteSpreadsheet(id: s.metadata.spreadsheetId)
            print("✅ Deleted.")
            spreadsheet = nil
        }
    }
    
    // Existing Actions Refactored
    
    mutating func showInfo() async throws {
        guard spreadsheet != nil else { return }
        try await spreadsheet!.refreshMetadata()
        let props = spreadsheet!.metadata.properties
        print("📊 Spreadsheet Info:")
        print("   Title: \(props.title)")
        print("   ID: \(spreadsheet!.metadata.spreadsheetId)")
        print("   Sheets: \(spreadsheet!.metadata.sheets.count)")
        for sheet in spreadsheet!.metadata.sheets {
            let grid = sheet.properties.gridProperties
            print("    - \(sheet.properties.title) (ID: \(sheet.properties.sheetId)) [\(grid.rowCount)x\(grid.columnCount)]")
        }
    }
    
    mutating func setupDemoSheet() async throws {
        guard spreadsheet != nil else { return }
        let name = demoSheetName
        print("Adding/Resetting '\(name)'...")
        
        if let existingSheet = try? spreadsheet!.sheet(named: name) {
            let id = existingSheet.properties.sheetId
            print("   Deleting existing...")
            try await spreadsheet!.batchUpdate { DeleteSheet(id: id) }
            try await spreadsheet!.refreshMetadata()
        }
        
        let response = try await spreadsheet!.batchUpdate { AddSheet(name) }
        if let newId = response.replies?.first?.addSheet?.properties.sheetId {
            print("✅ Sheet '\(name)' added with ID: \(newId)")
        }
        try await spreadsheet!.refreshMetadata()
    }
    
    mutating func writeDummyData() async throws {
        guard spreadsheet != nil else { return }
        let name = demoSheetName
        print("📝 Writing Headers & Dummy Data...")
        
        // Headers
        _ = try await spreadsheet!.updateValues(
            range: SheetRange(parsing: "\(name)!A1:F1"),
            values: [["Name", "Email", "Score", "Active", "Joined", "Nickname"]]
        )
        
        let headerFormat = CellFormat(
            backgroundColor: .blue,
            textFormat: TextFormat(foregroundColor: .white, bold: true)
        )
        try await spreadsheet!.format(range: SheetRange(parsing: "\(name)!A1:F1"), format: headerFormat)
        
        // Data
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let users = [
            DemoUser(name: "Alice", email: "alice@test.com", score: 100, isActive: true, joinDate: formatter.date(from: "2023-01-01")!, nickname: "Ally"),
            DemoUser(name: "Bob", email: "bob@test.com", score: 250, isActive: false, joinDate: formatter.date(from: "2023-05-15")!, nickname: nil)
        ]
        
        let values = try users.map { try $0.encodeRow() }
        try await spreadsheet!.updateValues(range: SheetRange(parsing: "\(name)!A2"), values: values)
        print("✅ Written \(users.count) users + headers.")
    }
    
    func readData() async throws {
        guard let s = spreadsheet else { return }
        let name = demoSheetName
        print("📖 Reading Data from '\(name)'...")
        
        // We use 'try?' here in case sheet doesn't exist to avoid crashing the demo flow
        do {
            let users = try await s.values(
                range: SheetRange(parsing: "\(name)!A2:F"),
                type: DemoUser.self
            )
            
            if users.isEmpty {
                print("   (No data found)")
                return
            }
            
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            print("   --- Data Start ---")
            for user in users {
                let nick = user.nickname ?? "-"
                let dateStr = formatter.string(from: user.joinDate)
                print("   👤 \(user.name): Score=\(user.score), Active=\(user.isActive), Joined=\(dateStr), Nick=\(nick)")
            }
            print("   --- Data End ---")
        } catch {
            print("❌ Read failed (Does sheet exist?): \(error)")
        }
    }
    
    mutating func appendUser() async throws {
        guard let s = spreadsheet else { return }
        let name = demoSheetName
        print("⬇️ Enter details:")
        print("   Name: ", terminator: "")
        let inputName = readLine() ?? "Unknown"
        print("   Score: ", terminator: "")
        let inputScore = Int(readLine() ?? "0") ?? 0
        
        let newUser = DemoUser(name: inputName, email: "\(inputName.lowercased())@example.com", score: inputScore, isActive: true, joinDate: Date(), nickname: nil)
        
        do {
            try await s.appendValues(
                range: SheetRange(parsing: "\(name)!A1"),
                values: [try newUser.encodeRow()]
            )
            print("✅ Appended.")
        } catch {
             print("❌ Append failed: \(error)")
        }
    }
    
    mutating func sortData() async throws {
        guard spreadsheet != nil else { return }
        print("🔃 Sorting by Score...")
        try await spreadsheet!.sort(range: SheetRange(parsing: "\(demoSheetName)!A2:F"), column: 2, ascending: false)
        print("✅ Sorted.")
    }
    
    mutating func clearData() async throws {
        guard spreadsheet != nil else { return }
        print("🧹 Clearing data...")
        try await spreadsheet!.clearValues(range: SheetRange(parsing: "\(demoSheetName)!A2:F"))
        print("✅ Cleared.")
    }
    
    mutating func resizeSheet() async throws {
        guard spreadsheet != nil else { return }
        let name = demoSheetName
        
        guard let sheet = try? spreadsheet!.sheet(named: name) else {
            print("❌ Sheet '\(name)' not found")
            return
        }
        
        print("Enter new Row Count (current: \(sheet.properties.gridProperties.rowCount)): ", terminator: "")
        let rows = Int(readLine() ?? "") ?? 100
        print("Enter new Column Count (current: \(sheet.properties.gridProperties.columnCount)): ", terminator: "")
        let cols = Int(readLine() ?? "") ?? 26
        
        print("📏 Resizing to \(rows)x\(cols)...")
        try await spreadsheet!.batchUpdate {
            ResizeSheet(sheet: sheet, rows: rows, columns: cols)
        }
        try await spreadsheet!.refreshMetadata()
        print("✅ Resized.")
    }
    
    mutating func bulkDataAndPaginationDemo() async throws {
        guard let s = spreadsheet else { return }
        let name = demoSheetName
        
        print("📊 Bulk Data + Pagination Demo")
        print("   This demo will:")
        print("   1. Generate 50 random users")
        print("   2. Write them to the sheet")
        print("   3. Query with pagination (10 per page)")
        print("")
        print("Continue? (y/n): ", terminator: "")
        guard readLine() == "y" else { return }
        
        // Step 1: Generate bulk data
        print("\n🔄 Generating 50 random users...")
        let names = ["Alice", "Bob", "Charlie", "Diana", "Eve", "Frank", "Grace", "Henry", "Ivy", "Jack"]
        let domains = ["example.com", "test.org", "demo.io"]
        var users: [DemoUser] = []
        
        for i in 1...50 {
            let name = names[i % names.count]
            let domain = domains[i % domains.count]
            let score = Int.random(in: 10...100)
            let daysAgo = Double.random(in: 0...365)
            let joinDate = Date().addingTimeInterval(-daysAgo * 86400)
            
            users.append(DemoUser(
                name: "\(name) \(i)",
                email: "\(name.lowercased())\(i)@\(domain)",
                score: score,
                isActive: i % 3 != 0,
                joinDate: joinDate,
                nickname: i % 5 == 0 ? "Nick\(i)" : nil
            ))
        }
        
        // Step 2: Clear and write data
        print("📝 Writing 50 users to sheet...")
        try await s.clearValues(range: SheetRange(parsing: "\(name)!A2:F"))
        
        // Write headers first
        _ = try await s.updateValues(
            range: SheetRange(parsing: "\(name)!A1:F1"),
            values: [["Name", "Email", "Score", "Active", "Joined", "Nickname"]]
        )
        
        // Write all users
        let values = try users.map { try $0.encodeRow() }
        try await s.updateValues(range: SheetRange(parsing: "\(name)!A2"), values: values)
        print("✅ Written 50 users.")
        
        // Step 3: Demonstrate pagination
        print("\n📄 Demonstrating Pagination (10 per page):")
        
        let pageSize = 10
        let totalPages = 5
        
        for page in 1...totalPages {
            let offset = (page - 1) * pageSize
            
            let pageUsers = try await s.query(DemoUser.self, in: SheetRange(parsing: "\(name)!A2:F"))
                .sorted(by: \.score, ascending: false)  // Sort by score descending
                .offset(offset)
                .limit(pageSize)
                .fetch()
            
            print("\n   📖 Page \(page) (offset: \(offset), limit: \(pageSize)):")
            for (i, user) in pageUsers.enumerated() {
                print("      [\(offset + i + 1)] \(user.name) - Score: \(user.score)")
            }
        }
        
        // Bonus: Show filtering + pagination
        print("\n🔍 Bonus: Active users with score > 50 (first 5):")
        let filtered = try await s.query(DemoUser.self, in: SheetRange(parsing: "\(name)!A2:F"))
            .where(\.isActive, equals: true)
            .where(\.score, greaterThan: 50)
            .sorted(by: \.score, ascending: false)
            .limit(5)
            .fetch()
        
        for user in filtered {
            print("      ✅ \(user.name) - Score: \(user.score)")
        }
        
        print("\n🎉 Pagination demo complete!")
    }
}
