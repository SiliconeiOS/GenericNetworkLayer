//
//  File.swift
//  GenericNetworkLayer
//
//

import Foundation

public protocol NetworkClientProtocol: Sendable {
    @discardableResult
    func execute(
        with request: URLRequest,
        retryPolicy: RetryPolicy?,
        completion: @escaping @Sendable (Result<Data, NetworkError>) -> Void
    ) -> Cancellable?
    func execute(with request: URLRequest, retryPolicy: RetryPolicy?) async throws -> Data
}

public extension NetworkClientProtocol {
    
    @discardableResult
    func execute(
        with request: URLRequest,
        completion: @escaping @Sendable (Result<Data, NetworkError>) -> Void
    ) -> Cancellable? {
        execute(with: request, retryPolicy: nil, completion: completion)
    }
    
    func execute(with request: URLRequest) async throws -> Data {
        try await execute(with: request, retryPolicy: nil)
    }
}
