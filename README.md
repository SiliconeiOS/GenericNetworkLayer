# GenericNetworkLayer

A lightweight, modern, and flexible networking layer for Swift built on top of URLSession. GenericNetworkLayer provides type-safe API request execution with built-in retry logic, authentication, and comprehensive error handling.

[![Swift](https://img.shields.io/badge/Swift-6.0-orange.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/Platforms-iOS%2014.0%2B%20%7C%20macOS%2012.0%2B-blue.svg)](https://swift.org)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![SPM](https://img.shields.io/badge/Swift%20Package%20Manager-compatible-brightgreen.svg)](https://github.com/apple/swift-package-manager)

## Features

- 🎯 **Type Safety**: Define requests and responses using Swift types with compile-time guarantees
- ⚡ **Async/Await Support**: Modern Swift concurrency patterns with backward compatibility
- 🔄 **Automatic Retry**: Configurable retry policies with exponential backoff
- 🔐 **Authentication**: Built-in token-based authentication handling
- 📝 **Logging**: Comprehensive request/response logging with cURL generation
- 🛡️ **Error Handling**: Detailed error types with localized descriptions
- 🧪 **Testability**: Protocol-based design for easy mocking and testing

## Requirements

- iOS 15.0+ / macOS 12.0+
- Swift 6.0+
- Xcode 16.0+

## Installation

### Swift Package Manager

1. In Xcode, select **File > Add Packages...**
2. Paste the repository URL: `https://github.com/SiliconeiOS/GenericNetworkLayer.git`
3. Select **"Up to Next Major Version"** and add the package.

### Manual Installation

Add the following to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/SiliconeiOS/GenericNetworkLayer.git", from: "1.0.0")
]
```

## Usage

### 1. Define Your API Requests

Create structs conforming to `APIRequestProtocol` to define your API endpoints:

```swift
import GenericNetworkLayer

// Simple GET request
struct GetUserRequest: APIRequestProtocol {
    typealias Response = User
    
    let userId: String
    
    var endpoint: String { "/users/\(userId)" }
    var method: HTTPMethod { .GET }
}

// POST request with body (automatically encoded)
struct CreateUserRequest: APIRequestProtocol, Encodable {
    typealias Response = User
    
    let name: String
    let email: String
    
    var endpoint: String { "/users" }
    var method: HTTPMethod { .POST }
}

// DELETE request with empty response
struct DeleteUserRequest: APIRequestProtocol {
    typealias Response = EmptyResponse
    
    let userId: String
    
    var endpoint: String { "/users/\(userId)" }
    var method: HTTPMethod { .DELETE }
}
```

### 2. Define Your Response Models

```swift
struct User: Decodable {
    let id: String
    let name: String
    let email: String
}
```

### 3. Create and Configure APIClient

```swift
// Basic setup
let client = APIClient(
    baseURL: "https://api.example.com",
    enableLogging: true
)

// Advanced setup with authentication and retry policy
class MyTokenProvider: TokenProviderProtocol {
    func getAccessToken() -> String? {
        return "your-access-token"
    }
}

let retryPolicy = RetryPolicy(
    maxRetries: 3,
    initialDelay: 1.0,
    backoffFactor: 2.0
)

let advancedClient = APIClient(
    baseURL: "https://api.example.com",
    session: URLSession.shared,
    tokenProvider: MyTokenProvider(),
    enableLogging: true,
    defaultRetryPolicy: retryPolicy
)
```

### 4. Execute Requests

#### Using Async/Await

```swift
import GenericNetworkLayer

class UserService {
    private let client = APIClient(baseURL: "https://api.example.com")
    
    func getUser(id: String) async throws -> User {
        let request = GetUserRequest(userId: id)
        return try await client.execute(with: request)
    }
    
    func createUser(name: String, email: String) async throws -> User {
        let request = CreateUserRequest(name: name, email: email)
        return try await client.execute(with: request)
    }
    
    func deleteUser(id: String) async throws {
        let request = DeleteUserRequest(userId: id)
        let _: EmptyResponse = try await client.execute(with: request)
    }
}

// Usage
do {
    let userService = UserService()
    let user = try await userService.getUser(id: "123")
    print("User: \(user.name)")
} catch {
    print("Error: \(error)")
}
```

#### Using Completion Handlers

```swift
class UserService {
    private let client = APIClient(baseURL: "https://api.example.com")
    
    func getUser(id: String, completion: @escaping (Result<User, APIClientError>) -> Void) {
        let request = GetUserRequest(userId: id)
        client.execute(with: request, completion: completion)
    }
}

// Usage
let userService = UserService()
userService.getUser(id: "123") { result in
    switch result {
    case .success(let user):
        print("User: \(user.name)")
    case .failure(let error):
        print("Error: \(error.localizedDescription)")
    }
}
```

### 5. Advanced Features

#### Custom Headers and Parameters

```swift
struct SearchUsersRequest: APIRequestProtocol {
    typealias Response = [User]
    
    let query: String
    let limit: Int
    
    var endpoint: String { "/users/search" }
    var method: HTTPMethod { .GET }
    
    var parameters: [URLQueryItem]? {
        [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "limit", value: "\(limit)")
        ]
    }
    
    var headers: [String: String]? {
        ["X-Custom-Header": "CustomValue"]
    }
}
```

#### Request-Specific Retry Policy

```swift
struct CriticalRequest: APIRequestProtocol {
    typealias Response = SomeModel
    
    var endpoint: String { "/critical-endpoint" }
    
    var retryPolicy: RetryPolicy? {
        RetryPolicy(
            maxRetries: 5,
            initialDelay: 0.5,
            backoffFactor: 1.5
        )
    }
}
```

#### Authentication

```swift
struct AuthenticatedRequest: APIRequestProtocol {
    typealias Response = SecureData
    
    var endpoint: String { "/secure-data" }
    var authType: AuthorizationType { .bearerToken }
}
```

## Error Handling

GenericNetworkLayer provides comprehensive error handling:

```swift
do {
    let user = try await client.execute(with: GetUserRequest(userId: "123"))
} catch let error as APIClientError {
    switch error {
    case .networkError(let networkError):
        // Handle network-specific errors
        print("Network error: \(networkError)")
    case .responseParseError(let parseError):
        // Handle JSON parsing errors
        print("Parse error: \(parseError)")
    case .requestBuilderError(let builderError):
        // Handle request building errors
        print("Request builder error: \(builderError)")
    case .unexpectedError(let unexpectedError):
        // Handle unexpected errors
        print("Unexpected error: \(unexpectedError)")
    }
}
```

## Architecture

GenericNetworkLayer follows a clean, protocol-oriented architecture:

```
┌─────────────────┐
│   APIClient     │ ← High-level type-safe interface
├─────────────────┤
│ RequestBuilder  │ ← Converts API requests to URLRequests
│ ResponseParser  │ ← Converts response data to typed objects
├─────────────────┤
│RetryingNetwork  │ ← Adds retry logic (decorator pattern)
│    Client       │
├─────────────────┤
│ NetworkClient   │ ← Low-level URLSession wrapper
└─────────────────┘
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Author

**SiliconeiOS** - [GitHub Profile](https://github.com/SiliconeiOS)

---

For more detailed documentation, see the inline documentation in the source code.
