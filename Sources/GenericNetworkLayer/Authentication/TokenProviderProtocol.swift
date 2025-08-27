//
//  File.swift
//  GenericNetworkLayer
//
//

import Foundation

/// A protocol for providing authentication tokens to API requests.
///
/// Implementations of this protocol should handle token storage, retrieval,
/// and refresh logic. The network layer will call `getAccessToken()` when
/// building requests that require authentication.
///
/// ## Usage
///
/// ```swift
/// class KeychainTokenProvider: TokenProviderProtocol {
///     func getAccessToken() -> String? {
///         // Retrieve token from keychain
///         return retrieveFromKeychain("access_token")
///     }
/// }
/// ```
public protocol TokenProviderProtocol: Sendable {
    /// Returns the current access token for authentication.
    ///
    /// This method should return the current valid access token,
    /// or nil if no token is available or the token has expired.
    ///
    /// - Returns: The access token string, or nil if not available
    func getAccessToken() -> String? 
}
