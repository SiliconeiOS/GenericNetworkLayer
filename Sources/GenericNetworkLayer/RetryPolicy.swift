//
//  File.swift
//  GenericNetworkLayer
//
//

import Foundation

/// Configuration for automatic retry logic when network requests fail.
///
/// RetryPolicy defines how failed requests should be retried, including
/// the number of attempts, delays between attempts, and which errors
/// should trigger a retry.
///
/// ## Usage
///
/// ```swift
/// // Default policy: 3 retries with exponential backoff
/// let policy = RetryPolicy()
///
/// // Custom policy
/// let customPolicy = RetryPolicy(
///     maxRetries: 5,
///     initialDelay: 2.0,
///     backoffFactor: 1.5
/// )
///
/// // Custom retry condition
/// let customCondition = RetryPolicy { error in
///     // Only retry on server errors
///     if case .unexpectedStatusCode(let code, _) = error {
///         return (500...599).contains(code)
///     }
///     return false
/// }
/// ```
public struct RetryPolicy: Sendable {
    
    /// Maximum number of retry attempts (excluding the initial request)
    public let maxRetries: Int
    
    /// Initial delay before the first retry attempt
    public let initialDelay: TimeInterval
    
    /// Multiplier for delay between subsequent retries (exponential backoff)
    public let backoffFactor: Double
    
    /// Function to determine if a specific error should trigger a retry
    public let shouldRetry: @Sendable (NetworkError) -> Bool
    
    /// Creates a RetryPolicy with the specified parameters.
    ///
    /// - Parameters:
    ///   - maxRetries: Maximum number of retry attempts (default: 3)
    ///   - initialDelay: Initial delay before first retry in seconds (default: 1.0)
    ///   - backoffFactor: Multiplier for delay between retries (default: 2.0 for exponential backoff)
    ///   - shouldRetry: Function to determine if an error should trigger a retry (default: server errors and network issues)
    public init(
        maxRetries: Int = 3,
        initialDelay: TimeInterval = 1.0,
        backoffFactor: Double = 2.0,
        shouldRetry: @escaping @Sendable (NetworkError) -> Bool = RetryPolicy.defaultShouldRetry
    ) {
        self.maxRetries = maxRetries
        self.initialDelay = initialDelay
        self.backoffFactor = backoffFactor
        self.shouldRetry = shouldRetry
    }
    
    /// Default retry condition that retries on server errors (5xx) and common network issues.
    ///
    /// This function will return `true` for:
    /// - HTTP status codes 500-599 (server errors)
    /// - Network connectivity issues (timeout, host not found, etc.)
    public static let defaultShouldRetry: @Sendable (NetworkError) -> Bool = { error in
        switch error {
        case .unexpectedStatusCode(let statusCode, _):
            return (500...599).contains(statusCode)
        case .requestFailed(let underlyingError):
            return [
                NSURLErrorTimedOut,
                NSURLErrorCannotFindHost,
                NSURLErrorCannotConnectToHost,
                NSURLErrorNetworkConnectionLost,
                NSURLErrorNotConnectedToInternet,
            ].contains(underlyingError.code)
        default:
            return false
        }
    }
}
