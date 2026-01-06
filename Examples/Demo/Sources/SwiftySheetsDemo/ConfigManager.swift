import Foundation

struct AppConfig: Codable {
    var serviceAccountPath: String?
    var lastSpreadsheetId: String?
    
    static let defaultConfigPath: URL = {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let configDir = home.appendingPathComponent(".swiftysheets")
        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)
        return configDir.appendingPathComponent("config.json")
    }()
    
    static func load() -> AppConfig {
        guard let data = try? Data(contentsOf: defaultConfigPath),
              let config = try? JSONDecoder().decode(AppConfig.self, from: data) else {
            return AppConfig()
        }
        return config
    }
    
    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        try? data.write(to: Self.defaultConfigPath)
    }
}
