//
//  MockNetworkClient.swift
//  GenericNetworkLayer
//
//  Created by Иван Дроботов on 8/29/25.
//

import Foundation
@testable import GenericNetworkLayer

/// Mock NetworkClient for testing retry behavior
final class NetworkClientMock: NetworkClientProtocol, @unchecked Sendable {
    
    private let queue = DispatchQueue(label: "com.test.MockNetworkClient", attributes: .concurrent)
    
    // MARK: - Configuration
    
    /// The responses to return in order. Each call will consume the next response.
    var responses: [Result<Data, NetworkError>] = []
    
    /// Delay to simulate network latency
    var delay: TimeInterval = 0.0
    
    /// Track all execution calls
    private(set) var executionCount = 0
    private(set) var lastRequest: URLRequest?
    private(set) var allRequests: [URLRequest] = []
    private(set) var lastRetryPolicy: RetryPolicy?
    
    // MARK: - Completion-based execution
    
    func execute(
        with request: URLRequest,
        retryPolicy: RetryPolicy?,
        completion: @escaping @Sendable (Result<Data, NetworkError>) -> Void
    ) -> Cancellable? {
        
        return queue.sync(flags: .barrier) {
            executionCount += 1
            lastRequest = request
            allRequests.append(request)
            lastRetryPolicy = retryPolicy
            
            guard !responses.isEmpty else {
                completion(.failure(.requestFailed(AnySendableError(NSError(
                    domain: "MockNetworkClient",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "No mock responses configured"]
                )))))
                return MockCancellable()
            }
            
            let response = responses.removeFirst()
            let cancellable = MockCancellable()
            
            if delay > 0 {
                DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
                    guard !cancellable.isCancelled else { return }
                    completion(response)
                }
            } else {
                DispatchQueue.global().async {
                    guard !cancellable.isCancelled else { return }
                    completion(response)
                }
            }
            
            return cancellable
        }
    }
    
    // MARK: - Async/await execution
    
    func execute(with request: URLRequest, retryPolicy: RetryPolicy?) async throws -> Data {
        let result: Result<Data, NetworkError> = await withCheckedContinuation { continuation in
            let _ = execute(with: request, retryPolicy: retryPolicy) { result in
                continuation.resume(returning: result)
            }
        }
        
        return try result.get()
    }
    
    // MARK: - Helper methods
    
    func reset() {
        queue.sync(flags: .barrier) {
            responses = []
            executionCount = 0
            lastRequest = nil
            allRequests = []
            lastRetryPolicy = nil
            delay = 0.0
        }
    }
    
    func addResponse(_ response: Result<Data, NetworkError>) {
        queue.sync(flags: .barrier) {
            responses.append(response)
        }
    }
    
    func addSuccessResponse(_ data: Data = Data()) {
        addResponse(.success(data))
    }
    
    func addFailureResponse(_ error: NetworkError) {
        addResponse(.failure(error))
    }
    
    var currentExecutionCount: Int {
        queue.sync { executionCount }
    }
    
    var currentAllRequests: [URLRequest] {
        queue.sync { allRequests }
    }
}

// MARK: - Mock Cancellable

final class MockCancellable: Cancellable, @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.test.MockCancellable")
    private var _isCancelled = false
    
    var isCancelled: Bool {
        queue.sync { _isCancelled }
    }
    
    func cancel() {
        queue.sync { _isCancelled = true }
    }
}
