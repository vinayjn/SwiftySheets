# Authentication Guide

SwiftySheets supports three main authentication mechanisms to suit different use cases: Service Accounts (Server-side), OAuth 2.0 (User-side), and API Keys (Public Data).

## 1. Service Account (Server-Side Automation)
**Best for:** Backend scripts, bots, server-to-server communication.
**Not recommended for:** Mobile apps or public distribution.

Service accounts allow your application to authenticate as itself rather than as a specific user.

### Setup
1. Go to [Google Cloud Console](https://console.cloud.google.com/).
2. Create a Service Account and download the JSON key file.
3. Share your target Google Sheet with the service account's email address (e.g., `remote-bot@project-id.iam.gserviceaccount.com`).

### Usage
```swift
import SwiftySheets

let credentials = try ServiceAccountCredentials(jsonPath: "/path/to/service-account.json")
let client = Client(credentials: credentials)
```

## 2. OAuth 2.0 (Mobile & Desktop Apps)
**Best for:** iOS/macOS apps where users sign in with their own Google account.

SwiftySheets integrates easily with authentication libraries like [GoogleSignIn-iOS](https://github.com/google/GoogleSignIn-iOS). It accepts an access token directly.

### Usage with GoogleSignIn
```swift
import SwiftySheets
import GoogleSignIn

// 1. User signs in via GoogleSignIn
let user = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)
let accessToken = user.accessToken.tokenString

// 2. Initialize SwiftySheets with the token
let credentials = OAuthCredentials(accessToken: accessToken)
let client = Client(credentials: credentials)

// Now you can access the user's private sheets
let spreadsheet = try await client.spreadsheet(id: "user-spreadsheet-id")
```

### Handling Token Refresh
To handle token expiration automatically, usage the closure-based initializer. This ensures SwiftySheets always gets a fresh token for every request.

```swift
let credentials = OAuthCredentials {
    // This closure is called before every request
    guard let user = GIDSignIn.sharedInstance.currentUser else { return nil }
    
    // Automatically refreshes token if needed
    return try? await user.accessToken.refreshIfNeeded().tokenString
}
let client = Client(credentials: credentials)
```

## 3. API Key (Public Data)
**Best for:** Reading public or published spreadsheets without user sign-in.
**Limitations:** Read-only access usually; cannot access private data.

### Setup
1. Go to [Google Cloud Console](https://console.cloud.google.com/).
2. detailed in "APIs & Services" > "Credentials", create an API Key.
3. Restrict the key to "Google Sheets API" for security.

### Usage
```swift
import SwiftySheets

let credentials = APIKeyCredentials(apiKey: "YOUR_API_KEY")
let client = Client(credentials: credentials)

// Read a public spreadsheet
let spreadsheet = try await client.spreadsheet(id: "public-spreadsheet-id")
let values: [String] = try await spreadsheet.values(range: Column.A[1]...Column.B[10])
```

## Summary

| Type | Class | Use Case |
|------|-------|----------|
| **Service Account** | `ServiceAccountCredentials` | Backend automation, bots |
| **OAuth 2.0** | `OAuthCredentials` | Mobile apps, accessing user data |
| **API Key** | `APIKeyCredentials` | Reading public data only |
