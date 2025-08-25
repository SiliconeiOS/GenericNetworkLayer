//
//  File.swift
//  GenericNetworkLayer
//
//

import Foundation

public final class RetryingNetworkClient: NetworkClientProtocol {
    private let client: NetworkClientProtocol
    
    public init(client: NetworkClientProtocol) {
        self.client = client
    }
    
    
    public func execute(
        with request: URLRequest,
        retryPolicy: RetryPolicy?,
        completion: @escaping @Sendable (Result<Data, NetworkError>) -> Void
    ) -> (any Cancellable)? {
        
        guard let policy = retryPolicy, policy.maxRetries > 0 else {
            return client.execute(with: request, completion: completion)
        }
        
        let cancellableToken = RetryCancellable()
        
        performRequest(
            with: request,
            policy: policy,
            attempt: 0,
            currentDelay: policy.initialDelay,
            cancellableToken: cancellableToken,
            completion: completion
        )
        
        return cancellableToken
    }
    
    public func execute(with request: URLRequest, retryPolicy: RetryPolicy?) async throws -> Data {
        guard let policy = retryPolicy, policy.maxRetries > 0 else {
            return try await client.execute(with: request)
        }
        
        var lastError: NetworkError?
        var currentDelay = policy.initialDelay
        
        let totalAttempts = policy.maxRetries + 1
        
        for attempt in 0..<totalAttempts {
            do {
                return try await client.execute(with: request)
            } catch let error as NetworkError where policy.shouldRetry(error) {
                lastError = error
                
                if attempt < policy.maxRetries {
                    try? await Task.sleep(nanoseconds: UInt64(currentDelay).seconds)
                    currentDelay *= policy.backoffFactor
                }
            } catch {
                throw error
            }
        }
        
        throw NetworkError.allRetriesFailed(
            lastError: lastError ?? .allRetriesFailedFallback,
            totalAttempts: totalAttempts
        )
    }
    
    private func performRequest(
        with request: URLRequest,
        policy: RetryPolicy,
        attempt: Int,
        currentDelay: TimeInterval,
        cancellableToken: RetryCancellable,
        completion: @escaping @Sendable (Result<Data, NetworkError>) -> Void
    ) {
        guard !cancellableToken.isOperationCancelled else { return }
        
        let task = client.execute(with: request) { [weak self] result in
            guard let self, !cancellableToken.isOperationCancelled else { return }
            
            switch result {
            case .success:
                completion(result)
            case .failure(let error) where policy.shouldRetry(error) && attempt < policy.maxRetries:
                
                guard !cancellableToken.isOperationCancelled else { return }
                
                DispatchQueue.global().asyncAfter(deadline: .now() + currentDelay) {
                    self.performRequest(
                        with: request,
                        policy: policy,
                        attempt: attempt + 1,
                        currentDelay: currentDelay * policy.backoffFactor,
                        cancellableToken: cancellableToken,
                        completion: completion)
                }
            case .failure:
                completion(result)
            }
        }
        
        cancellableToken.update(task: task)
    }
}



private extension UInt64 {
    var seconds: UInt64 {
        self * 1_000_000_000
    }
}
