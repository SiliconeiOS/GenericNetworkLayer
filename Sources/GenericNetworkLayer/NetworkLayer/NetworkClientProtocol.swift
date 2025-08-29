//
//  File.swift
//  GenericNetworkLayer
//
//

import Foundation

/// A protocol defining the interface for low-level network clients.
///
/// This protocol abstracts the actual network execution, allowing for
/// different implementations (with/without retry logic, mock clients for testing, etc.).
public protocol NetworkClientProtocol: Sendable {
    /// Executes a URLRequest with completion handler.
    ///
    /// - Parameters:
    ///   - request: The URLRequest to execute
    ///   - retryPolicy: Optional retry policy for handling failures
    ///   - completion: Completion handler called with the result
    /// - Returns: A cancellable token, or nil if the request failed to start
    @discardableResult
    func execute(
        with request: URLRequest,
        retryPolicy: RetryPolicy?,
        completion: @escaping @Sendable (Result<Data, NetworkError>) -> Void
    ) -> Cancellable?
    
    /// Executes a URLRequest using async/await.
    ///
    /// - Parameters:
    ///   - request: The URLRequest to execute
    ///   - retryPolicy: Optional retry policy for handling failures
    /// - Returns: The response data
    /// - Throws: `NetworkError` if the request fails
    func execute(with request: URLRequest, retryPolicy: RetryPolicy?) async throws -> Data
}

// MARK: - Convenience Methods
public extension NetworkClientProtocol {
    
    @discardableResult
    func execute(
        with request: URLRequest,
        completion: @escaping @Sendable (Result<Data, NetworkError>) -> Void
    ) -> Cancellable? {
        execute(with: request, retryPolicy: nil, completion: completion)
    }
    
    @discardableResult
    func execute(with request: URLRequest) async throws -> Data {
        try await execute(with: request, retryPolicy: nil)
    }
}
