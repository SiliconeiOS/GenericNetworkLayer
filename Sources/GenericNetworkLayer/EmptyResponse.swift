//
//  File.swift
//  GenericNetworkLayer
//
//

import Foundation

/// A response type for API requests that don't return meaningful data.
///
/// Use `EmptyResponse` as the response type for API requests that only
/// need to know about success/failure, such as DELETE operations or
/// status updates that return empty bodies or simple success indicators.
///
/// ## Usage
///
/// ```swift
/// struct DeleteUserRequest: APIRequestProtocol {
///     typealias Response = EmptyResponse
///     
///     let userId: String
///     var endpoint: String { "/users/\(userId)" }
///     var method: HTTPMethod { .DELETE }
/// }
/// ```
public struct EmptyResponse: Decodable, Sendable {}
