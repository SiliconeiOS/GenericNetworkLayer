//
//  File.swift
//  GenericNetworkLayer
//
//

import Foundation

/// A Sendable wrapper for any Error type.
///
/// This type wraps non-Sendable errors to make them safe to pass across
/// concurrency boundaries. It preserves the essential error information
/// (description, code, domain) while ensuring Sendable compliance.
public struct AnySendableError: Error, Sendable {
    /// The localized description of the original error
    public let localizedDescription: String
    
    /// The error code from the original error
    public let code: Int
    
    /// The error domain from the original error
    public let domain: String
    
    /// Creates a Sendable error wrapper from any Error.
    ///
    /// - Parameter error: The original error to wrap
    public init(_ error: Error) {
        let nsError = error as NSError
        self.localizedDescription = error.localizedDescription
        self.code = nsError.code
        self.domain = nsError.domain
    }
}
