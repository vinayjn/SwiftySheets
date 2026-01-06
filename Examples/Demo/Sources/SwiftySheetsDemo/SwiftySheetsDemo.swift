import Foundation
import ArgumentParser
import SwiftySheets
import Rainbow
import SwiftyTextTable

// --- Models ---

@SheetRow
struct DemoUser {
    @Column("A") var name: String
    @Column("B") var email: String
    @Column("C") var score: Int
    @Column("D") var isActive: Bool
    @Column("E", format: "yyyy-MM-dd") var joinDate: Date
    @Column("F") var nickname: String?
}

// --- Main Command ---

@main
struct SwiftySheetsDemo: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "A CLI demo for SwiftySheets",
        subcommands: [Interactive.self, Config.self],
        defaultSubcommand: Interactive.self
    )
}

// --- Subcommands ---

struct Interactive: AsyncParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Run the interactive demo menu")
    
    @Option(name: .shortAndLong, help: "Path to service account JSON")
    var creds: String?

    func run() async throws {
        // Load Config
        var config = AppConfig.load()
        
        // Resolve Credentials
        let jsonPath: String
        if let flagPath = creds {
            jsonPath = flagPath
        } else if let configPath = config.serviceAccountPath {
            jsonPath = configPath
        } else {
            print("🔑 No credentials found.".yellow)
            print("Please enter the path to your Service Account JSON file:")
            guard let input = readLine(), !input.isEmpty else {
                print("❌ Credentials are required.".red)
                return
            }
            jsonPath = input
            // Ask to save
            print("Save this path for future use? (y/n)")
            if readLine()?.lowercased() == "y" {
                config.serviceAccountPath = jsonPath
                config.save()
                print("✅ Saved.".green)
            }
        }
        
        // Init Client
        print("Connecting...".cyan)
        let client: Client
        do {
            let credentials = try ServiceAccountCredentials(jsonPath: jsonPath)
            client = Client(credentials: credentials)
            print("✅ Connected.".green)
        } catch {
            print("❌ Failed to authenticate: \(error)".red)
            return
        }
        
        // Start Menu Loop
        var app = DemoApp(client: client, config: config)
        await app.run()
    }
}

struct Config: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Manage stored configuration")
    
    func run() {
        let config = AppConfig.load()
        print("📂 Configuration Location: \(AppConfig.defaultConfigPath.path)".blue)
        print("--------------------------------")
        print("Service Account: \(config.serviceAccountPath ?? "Not Set".red)")
        print("Last Spreadsheet: \(config.lastSpreadsheetId ?? "None".red)")
    }
}

// --- Application Logic ---

struct DemoApp {
    let client: Client
    var config: AppConfig
    
    var spreadsheet: Spreadsheet?
    
    init(client: Client, config: AppConfig) {
        self.client = client
        self.config = config
    }
    
    mutating func run() async {
        // Auto-open last spreadsheet if available
        if let lastId = config.lastSpreadsheetId {
            print("Open last used spreadsheet? (ID: \(lastId)) [y/n]: ".cyan, terminator: "")
            if readLine()?.lowercased() == "y" {
                do {
                    spreadsheet = try await client.spreadsheet(id: lastId)
                    print("✅ Opened: \(spreadsheet?.metadata.properties.title ?? "Unknown")".green)
                } catch {
                    print("⚠️ Failed to open last spreadsheet: \(error)".yellow)
                }
            }
        }
        
        var shouldExit = false
        while !shouldExit {
            print("\n-------------------------------------------")
            if let s = spreadsheet {
                print("📍 SPREADSHEET MODE: \(s.metadata.properties.title)".bold)
                shouldExit = await runSpreadsheetMenu()
            } else {
                print("📍 MANAGER MODE".bold)
                shouldExit = await runManagerMenu()
            }
        }
        print("👋 Exiting.".blue)
    }
    
    // MARK: - Manager Mode
    
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
            default: print("❌ Invalid choice".red)
            }
        } catch {
            print("⚠️ Action Failed: \(error)".red)
        }
        return false
    }
    
    mutating func listSpreadsheets() async throws {
        print("🔍 Fetching spreadsheets...".cyan)
        let files = try await client.listSpreadsheets()
        
        if files.isEmpty {
            print("   (No spreadsheets found)".yellow)
            return
        }
        
        // Render Table
        let idxCol = TextTableColumn(header: "#")
        let nameCol = TextTableColumn(header: "Name")
        let idCol = TextTableColumn(header: "ID")
        var table = TextTable(columns: [idxCol, nameCol, idCol])
        
        for (index, file) in files.enumerated() {
            table.addRow(values: ["\(index + 1)", file.name, file.id])
        }
        print(table.render())
        
        print("\nSelect # to open (or Enter to cancel): ", terminator: "")
        guard let input = readLine(), !input.isEmpty, let index = Int(input) else { return }
        
        if index > 0 && index <= files.count {
            let file = files[index - 1]
            try await openSpreadsheet(id: file.id)
        } else {
            print("❌ Invalid selection.".red)
        }
    }
    
    mutating func createNewSpreadsheet() async throws {
        print("Enter title: ", terminator: "")
        let title = readLine() ?? "Untitled"
        print("Creating...".cyan)
        let s = try await client.createSpreadsheet(title: title)
        try await openSpreadsheet(id: s.metadata.spreadsheetId)
    }
    
    mutating func openById() async throws {
        print("Enter Spreadsheet ID: ", terminator: "")
        guard let id = readLine(), !id.isEmpty else { return }
        try await openSpreadsheet(id: id)
    }
    
    mutating func openSpreadsheet(id: String) async throws {
        print("Opening...".cyan)
        spreadsheet = try await client.spreadsheet(id: id)
        print("✅ Opened.".green)
        
        // Save to config
        config.lastSpreadsheetId = id
        config.save()
    }
    
    // MARK: - Spreadsheet Mode
    
    mutating func runSpreadsheetMenu() async -> Bool {
        guard spreadsheet != nil else { return false }
        
        print("1. 📄 Show Info")
        print("2. 📝 Write Dummy Data")
        print("3. 📖 Read Data (Table View)")
        print("4. 🎨 Formatting Playground")
        print("5. ✏️ Edit Cell")
        print("9. 🗑️ Delete This Spreadsheet")
        print("0. 🔙 Close Spreadsheet (Back to Menu)")
        print("Enter choice: ", terminator: "")
        
        guard let choice = readLine() else { return true }
        print("")
        
        do {
            switch choice {
            case "1": try await showInfo()
            case "2": try await writeDummyData()
            case "3": try await readData()
            case "4": try await formattingPlayground()
            case "5": try await editCell()
            case "9": try await deleteCurrentSpreadsheet()
            case "0": 
                spreadsheet = nil
                return false
            default: print("❌ Invalid choice".red)
            }
        } catch {
            print("⚠️ Action Failed: \(error)".red)
        }
        
        return false
    }
    
    mutating func showInfo() async throws {
        guard spreadsheet != nil else { return }
        try await spreadsheet!.refreshMetadata()
        guard let s = spreadsheet else { return }
        let props = s.metadata.properties
        
        print("Title: \(props.title)".bold)
        print("ID: \(s.metadata.spreadsheetId)")
        
        let sheetName = TextTableColumn(header: "Sheet")
        let sheetId = TextTableColumn(header: "ID")
        let gridSize = TextTableColumn(header: "Size")
        var table = TextTable(columns: [sheetName, sheetId, gridSize])
        
        for sheet in s.metadata.sheets {
            let g = sheet.properties.gridProperties
            table.addRow(values: [sheet.properties.title, "\(sheet.properties.sheetId)", "\(g.rowCount)x\(g.columnCount)"])
        }
        print(table.render())
    }
    
    mutating func deleteCurrentSpreadsheet() async throws {
        guard let s = spreadsheet else { return }
        print("💥 DELETE '\(s.metadata.properties.title)'? (y/n): ".red, terminator: "")
        if readLine() == "y" {
            try await client.deleteSpreadsheet(id: s.metadata.spreadsheetId)
            print("✅ Deleted.".green)
            spreadsheet = nil
            config.lastSpreadsheetId = nil
            config.save()
        }
    }
    
    mutating func writeDummyData() async throws {
        guard let s = spreadsheet else { return }
        print("Writing data...".cyan)
        // Add sheet if needed
        let name = "DemoSheet"
        if (try? s.sheet(named: name)) == nil {
             _ = try? await s.batchUpdate { AddSheet(name) }
        }
        
        let users = [
            DemoUser(name: "Alice", email: "alice@test.com", score: 100, isActive: true, joinDate: Date(), nickname: "Ally"),
            DemoUser(name: "Bob", email: "bob@test.com", score: 50, isActive: false, joinDate: Date(), nickname: nil)
        ]
        
        // Headers
        _ = try await s.updateValues(range: SheetRange(parsing: "\(name)!A1"), values: [["Name", "Email", "Score", "Active", "Joined", "Nickname"]])
        // Data
        let values = try users.map { try $0.encodeRow() }
        _ = try await s.updateValues(range: SheetRange(parsing: "\(name)!A2"), values: values)
        
        print("✅ Written.".green)
    }
    
    func readData() async throws {
        guard let s = spreadsheet else { return }
        let name = "DemoSheet"
        
        // Safely try to read, might fail if sheet doesn't exist
        do {
            let users = try await s.values(range: SheetRange(parsing: "\(name)!A2:F"), type: DemoUser.self)
            
            let c1 = TextTableColumn(header: "Name")
            let c2 = TextTableColumn(header: "Score")
            let c3 = TextTableColumn(header: "Active")
            var table = TextTable(columns: [c1, c2, c3])
            
            for user in users {
                table.addRow(values: [user.name, "\(user.score)", user.isActive ? "✅" : "❌"])
            }
            print(table.render())
        } catch {
            print("❌ Read failed (Does sheet exist?): \(error)".red)
        }
    }
    
    // MARK: - New Features
    
    mutating func editCell() async throws {
        guard let s = spreadsheet else { return }
        print("Enter Cell Address (e.g. Sheet1!A1): ", terminator: "")
        guard let addr = readLine(), !addr.isEmpty else { return }
        
        // Read
        let current = try await s[addr].get()
        print("Current Value: \(current ?? "nil")".blue)
        
        print("Enter New Value (or Enter to skip): ", terminator: "")
        let input = readLine() ?? ""
        if !input.isEmpty {
            try await s[addr].set(input)
            print("✅ Updated.".green)
        }
    }
    
    mutating func formattingPlayground() async throws {
        guard let s = spreadsheet else { return }
        print("Enter Range to Format (e.g. Sheet1!A1:B2): ", terminator: "")
        guard let rangeStr = readLine(), !rangeStr.isEmpty else { return }
        let range = try SheetRange(parsing: rangeStr)
        
        print("Select Color: 1.Red 2.Blue 3.Green 4.Clear")
        let colorChoice = readLine()
        
        print("Bold? (y/n)")
        let bold = readLine() == "y"
        
        var builder = s.format(range)
        if bold { builder = builder.bold() }
        
        switch colorChoice {
        case "1": builder = builder.backgroundColor(.red)
        case "2": builder = builder.backgroundColor(.blue)
        case "3": builder = builder.backgroundColor(.green)
        case "4": builder = builder.backgroundColor(.clear)
        default: break
        }
        
        try await builder.apply()
        print("✅ Applied.".green)
    }
}
