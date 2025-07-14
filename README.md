# SwiftySheets

A Swift library for interacting with Google Sheets API using modern Swift concurrency.

## Features

- **Modern Swift Concurrency**: Built with async/await from the ground up
- **Service Account Authentication**: Secure authentication using Google service account credentials
- **Type-Safe API**: Enum-based endpoints and comprehensive error handling
- **Testable Design**: Protocol-oriented architecture with dependency injection
- **Cross-Platform**: Supports macOS 13+ and iOS 15+

## Installation

### Swift Package Manager

Add SwiftySheets to your project using Swift Package Manager:

```swift
dependencies: [
    .package(url: "https://github.com/vinayjn/SwiftySheets.git", from: "1.0.0")
]
```

## Prerequisites

1. **Google Cloud Project**: Create a project in [Google Cloud Console](https://console.cloud.google.com/)
2. **Enable APIs**: Enable Google Sheets API and Google Drive API
3. **Service Account**: Create a service account and download the JSON credentials file
4. **Share Spreadsheet**: Share your Google Sheets with the service account email

## Quick Start

```swift
import SwiftySheets

// Initialize with service account credentials
let credentials = try ServiceAccountCredentials(
    jsonPath: "/path/to/service-account.json",
    scopes: [SpreadsheetScope.readwrite, DriveScope.readwrite]
)

let client = Client(credentials: credentials)

// Access a spreadsheet
let spreadsheet = try await client.spreadsheet(id: "your-spreadsheet-id")

// Read values from a range
let values = try await spreadsheet.values(range: "A1:C10")
print(values) // [["Name", "Age", "City"], ["John", "30", "NYC"], ...]

// Get sheet information
let sheets = try spreadsheet.sheets()
let specificSheet = try spreadsheet.sheet(named: "Sheet1")
```

## Authentication

### Service Account (Recommended)

```swift
let credentials = try ServiceAccountCredentials(
    jsonPath: "/path/to/service-account.json",
    scopes: [SpreadsheetScope.readwrite, DriveScope.readwrite]
)
```

### Available Scopes

```swift
// Spreadsheet scopes
SpreadsheetScope.readonly    // Read-only access to spreadsheets
SpreadsheetScope.readwrite   // Read/write access to spreadsheets

// Drive scopes  
DriveScope.readonly          // Read-only access to Drive
DriveScope.readwrite         // Read/write access to Drive
```

## API Reference

### Client

```swift
let client = Client(credentials: credentials)
let spreadsheet = try await client.spreadsheet(id: "spreadsheet-id")
```

### Spreadsheet

```swift
// Read values with options
let values = try await spreadsheet.values(
    range: "A1:Z100",
    valueRenderOption: .unformatted,
    dateTimeRenderOption: .serialNumber
)

// Get sheet metadata
let sheets = try spreadsheet.sheets()
let namedSheet = try spreadsheet.sheet(named: "MySheet")

// Refresh metadata
try await spreadsheet.refreshMetadata()
```

### Value Rendering Options

```swift
ValueRenderOption.formatted      // Returns formatted values
ValueRenderOption.unformatted    // Returns raw values
ValueRenderOption.formula        // Returns formulas

DateRenderOption.serialNumber    // Returns dates as serial numbers
DateRenderOption.formattedString // Returns formatted date strings
```

## Error Handling

SwiftySheets provides comprehensive error handling:

```swift
do {
    let spreadsheet = try await client.spreadsheet(id: "invalid-id")
} catch SheetsError.spreadsheetNotFound(let message) {
    print("Spreadsheet not found: \(message)")
} catch SheetsError.authenticationFailed {
    print("Authentication failed")
} catch SheetsError.invalidResponse(let status) {
    print("HTTP error: \(status)")
}
```

## Testing

SwiftySheets is designed for testability with protocol-oriented architecture:

```swift
// Mock URLSession for testing
class MockURLSession: URLSessionProtocol {
    // Implementation
}

// Mock credentials
class MockCredentials: GoogleCredentials {
    // Implementation
}

let client = Client(
    credentials: MockCredentials(),
    session: MockURLSession()
)
```

## Requirements

- Swift 6.0+
- macOS 13.0+ / iOS 15.0+
- Google Cloud Project with Sheets API enabled
- Service account credentials

## License

[Add your license here]

## Contributing

[Add contribution guidelines here]