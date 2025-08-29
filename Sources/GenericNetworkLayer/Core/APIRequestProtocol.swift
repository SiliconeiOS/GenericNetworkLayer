//
//  File.swift
//  GenericNetworkLayer
//
//

import Foundation

/// A protocol defining the structure of an API request.
///
/// Conforming types define all the necessary information to construct and execute
/// an HTTP request, including the endpoint, parameters, headers, and expected response type.
///
/// ## Usage
///
/// ```swift
/// struct GetUserRequest: APIRequestProtocol {
///     typealias Response = User
///     
///     let userId: String
///     
///     var endpoint: String { "/users/\(userId)" }
///     var method: HTTPMethod { .GET }
/// }
/// ```
///
/// For requests with body data:
/// ```swift
/// struct CreateUserRequest: APIRequestProtocol, Encodable {
///     typealias Response = User
///     
///     let name: String
///     let email: String
///     
///     var endpoint: String { "/users" }
///     var method: HTTPMethod { .POST }
///     // body is automatically provided via Encodable extension
/// }
/// ```
public protocol APIRequestProtocol: Sendable {
    /// The type of the expected response from this request.
    /// Must conform to `Decodable` for automatic parsing.
    associatedtype Response: Decodable
    
    /// The API endpoint path (without base URL).
    /// Example: "/users/123" or "/posts"
    var endpoint: String { get }
    
    /// Optional query parameters to append to the URL.
    var parameters: [URLQueryItem]? { get }
    
    /// The HTTP method for this request.
    var method: HTTPMethod { get }
    
    /// Optional HTTP headers for this request.
    var headers: [String: String]? { get }
    
    /// Optional request body data.
    /// Throws if encoding fails.
    var body: Data? { get throws }
    
    /// Optional retry policy for this specific request.
    /// Overrides the client's default retry policy.
    var retryPolicy: RetryPolicy? { get }
    
    /// Authentication type for this request.
    /// Defaults to `.none`. Use `.bearerToken` to add Authorization header.
    var authType: AuthorizationType { get }
}

/// HTTP methods supported by the network layer.
public enum HTTPMethod: String {
    case GET
    case POST
    case PUT
    case DELETE
}

// MARK: - Default Implementations
public extension APIRequestProtocol {
    var parameters: [URLQueryItem]? { nil }
    var body: Data? { nil }
    var method: HTTPMethod { .GET }
    var headers: [String: String]? { nil }
    var retryPolicy: RetryPolicy? { nil }
    var authType: AuthorizationType { .none }
}

// MARK: - Encodable Convenience
/// Automatic implementations for requests that can encode themselves as JSON.
public extension APIRequestProtocol where Self: Encodable {
    var body: Data? {
        try? JSONEncoder().encode(self)
    }
    
    var headers: [String: String]? {
        [.contentTypeHeader: .jsonContentType]
    }
}

private extension String {
    static var contentTypeHeader: String { "Content-Type" }
    static var jsonContentType: String { "application/json" }
}
