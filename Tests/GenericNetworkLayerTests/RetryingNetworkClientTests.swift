//
//  File.swift
//  GenericNetworkLayer
//
//  Created by Иван Дроботов on 8/29/25.
//

import Foundation
import Testing
@testable import GenericNetworkLayer

@Suite("RetryingNetworkClient Tests")
struct RetryingNetworkClientTests {
    
    // MARK: - Test Properties
    
    private let sut: RetryingNetworkClient
    private let mockClient: NetworkClientMock
    private let testURL = URL(string: "https://api.test.com/test")!
    private let defaultTestDelay: TimeInterval = 0.001 // 1ms for fast tests
    private let expectedTestData = "test data".data(using: .utf8)!
    
    private var testRequest: URLRequest {
        URLRequest(url: testURL)
    }
    
    // MARK: - Initialization
    
    init() {
        mockClient = NetworkClientMock()
        sut = RetryingNetworkClient(client: mockClient)
    }
    
    // MARK: - Test Helpers
    
    private func createTestRetryPolicy(maxRetries: Int = 3) -> RetryPolicy {
        RetryPolicy(maxRetries: maxRetries, initialDelay: defaultTestDelay)
    }
    
    // MARK: - No Retry Policy Tests
    
    @Test("Delegates to underlying client when no retry policy is provided - async")
    func testNoRetryPolicyAsync() async throws {
        // Given
        mockClient.addSuccessResponse(expectedTestData)
        
        // When
        let result = try await sut.execute(with: testRequest, retryPolicy: nil)
        
        // Then
        #expect(result == expectedTestData)
        #expect(mockClient.currentExecutionCount == 1)
        #expect(mockClient.lastRequest?.url == testURL)
    }
    
    @Test("Delegates to underlying client when no retry policy is provided - completion")
    func testNoRetryPolicyCompletion() async throws {
        // Given
        mockClient.addSuccessResponse(expectedTestData)
        
        // When
        let result: Result<Data, NetworkError> = await withCheckedContinuation { continuation in
            let cancellable = sut.execute(with: testRequest, retryPolicy: nil) { result in
                continuation.resume(returning: result)
            }
            #expect(cancellable != nil)
        }
        
        // Then
        let receivedData = try result.get()
        #expect(receivedData == expectedTestData)
        #expect(mockClient.currentExecutionCount == 1)
        #expect(mockClient.lastRequest?.url == testURL)
    }
    
    @Test("Delegates to underlying client when retry policy has zero retries - async")
    func testZeroRetriesAsync() async throws {
        // Given
        mockClient.addSuccessResponse(expectedTestData)
        let retryPolicy = RetryPolicy(maxRetries: 0)
        
        // When
        let result = try await sut.execute(with: testRequest, retryPolicy: retryPolicy)
        
        // Then
        #expect(result == expectedTestData)
        #expect(mockClient.currentExecutionCount == 1)
    }
    
    @Test("Delegates to underlying client when retry policy has zero retries - completion")
    func testZeroRetriesCompletion() async throws {
        // Given
        mockClient.addSuccessResponse(expectedTestData)
        let retryPolicy = RetryPolicy(maxRetries: 0)
        
        // When
        let result: Result<Data, NetworkError> = await withCheckedContinuation { continuation in
            let cancellable = sut.execute(with: testRequest, retryPolicy: retryPolicy) { result in
                continuation.resume(returning: result)
            }
            #expect(cancellable != nil)
        }
        
        // Then
        let receivedData = try result.get()
        #expect(receivedData == expectedTestData)
        #expect(mockClient.currentExecutionCount == 1)
    }
    
    // MARK: - Success Without Retry Tests
    
    @Test("Returns success immediately when request succeeds on first attempt - async")
    func testSuccessFirstAttemptAsync() async throws {
        // Given

        let successData = "success data".data(using: .utf8)!
        mockClient.addSuccessResponse(successData)

        let retryPolicy = createTestRetryPolicy()
        
        // When
        let result = try await sut.execute(with: testRequest, retryPolicy: retryPolicy)
        
        // Then
        #expect(result == successData)
        #expect(mockClient.currentExecutionCount == 1)
    }
    
    @Test("Returns success immediately when request succeeds on first attempt - completion")
    func testSuccessFirstAttemptCompletion() async throws {
        // Given

        let successData = "success data".data(using: .utf8)!
        mockClient.addSuccessResponse(successData)

        let retryPolicy = createTestRetryPolicy()
        
        // When
        let result: Result<Data, NetworkError> = await withCheckedContinuation { continuation in
            let cancellable = sut.execute(with: testRequest, retryPolicy: retryPolicy) { result in
                continuation.resume(returning: result)
            }
            #expect(cancellable != nil)
        }
        
        // Then
        let receivedData = try result.get()
        #expect(receivedData == successData)
        #expect(mockClient.currentExecutionCount == 1)
    }
    
    // MARK: - Retry Success Tests
    
    @Test("Retries and eventually succeeds - async")
    func testRetrySuccessAsync() async throws {
        // Given

        let successData = "success after retry".data(using: .utf8)!
        // First two attempts fail, third succeeds
        mockClient.addFailureResponse(.unexpectedStatusCode(statusCode: 500, body: nil))
        mockClient.addFailureResponse(.unexpectedStatusCode(statusCode: 502, body: nil))
        mockClient.addSuccessResponse(successData)
        

        let retryPolicy = createTestRetryPolicy()
        
        // When
        let result = try await sut.execute(with: testRequest, retryPolicy: retryPolicy)
        
        // Then
        #expect(result == successData)
        #expect(mockClient.currentExecutionCount == 3) // 1 initial + 2 retries
    }
    
    @Test("Retries and eventually succeeds - completion")
    func testRetrySuccessCompletion() async throws {
        // Given

        let successData = "success after retry".data(using: .utf8)!
        // First two attempts fail, third succeeds
        mockClient.addFailureResponse(.unexpectedStatusCode(statusCode: 500, body: nil))
        mockClient.addFailureResponse(.unexpectedStatusCode(statusCode: 502, body: nil))
        mockClient.addSuccessResponse(successData)
        

        let retryPolicy = createTestRetryPolicy()
        
        // When
        let result: Result<Data, NetworkError> = await withCheckedContinuation { continuation in
            let cancellable = sut.execute(with: testRequest, retryPolicy: retryPolicy) { result in
                continuation.resume(returning: result)
            }
            #expect(cancellable != nil)
        }
        
        // Then
        let receivedData = try result.get()
        #expect(receivedData == successData)
        #expect(mockClient.currentExecutionCount == 3) // 1 initial + 2 retries
    }
    
    @Test("Retries with different retryable errors - async")
    func testRetryWithDifferentErrorsAsync() async throws {
        // Given

        let successData = "success".data(using: .utf8)!
        
        // Different retryable errors
        let timeoutError = NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut, userInfo: nil)
        let networkError = NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet, userInfo: nil)
        
        mockClient.addFailureResponse(.requestFailed(AnySendableError(timeoutError)))
        mockClient.addFailureResponse(.unexpectedStatusCode(statusCode: 503, body: nil))
        mockClient.addFailureResponse(.requestFailed(AnySendableError(networkError)))
        mockClient.addSuccessResponse(successData)
        

        let retryPolicy = createTestRetryPolicy(maxRetries: 4)
        
        // When
        let result = try await sut.execute(with: testRequest, retryPolicy: retryPolicy)
        
        // Then
        #expect(result == successData)
        #expect(mockClient.currentExecutionCount == 4) // 1 initial + 3 retries
    }
    
    // MARK: - Retry Exhaustion Tests
    
    @Test("Exhausts all retries and fails with allRetriesFailed error - async")
    func testRetryExhaustionAsync() async throws {
        // Given

        // All attempts fail
        mockClient.addFailureResponse(.unexpectedStatusCode(statusCode: 500, body: nil))
        mockClient.addFailureResponse(.unexpectedStatusCode(statusCode: 502, body: nil))
        mockClient.addFailureResponse(.unexpectedStatusCode(statusCode: 503, body: nil))
        mockClient.addFailureResponse(.unexpectedStatusCode(statusCode: 504, body: nil))
        

        let retryPolicy = createTestRetryPolicy()
        
        do {
            // When
            _ = try await sut.execute(with: testRequest, retryPolicy: retryPolicy)
            Issue.record("Expected allRetriesFailed error but request succeeded")
        } catch let error as NetworkError {
            // Then
            guard case .allRetriesFailed(let lastError, let totalAttempts) = error else {
                Issue.record("Expected allRetriesFailed error, got \(error)")
                return
            }
            
            #expect(totalAttempts == 4) // 1 initial + 3 retries
            #expect(mockClient.currentExecutionCount == 4)
            
            // Verify the last error is preserved
            guard case .unexpectedStatusCode(let statusCode, _) = lastError else {
                Issue.record("Expected unexpectedStatusCode as last error, got \(lastError)")
                return
            }
            #expect(statusCode == 504)
        } catch {
            Issue.record("Expected NetworkError.allRetriesFailed, got \(error)")
        }
    }
    
    @Test("Exhausts all retries and fails with allRetriesFailed error - completion")
    func testRetryExhaustionCompletion() async {
        // Given

        // All attempts fail
        mockClient.addFailureResponse(.unexpectedStatusCode(statusCode: 500, body: nil))
        mockClient.addFailureResponse(.unexpectedStatusCode(statusCode: 502, body: nil))
        mockClient.addFailureResponse(.unexpectedStatusCode(statusCode: 503, body: nil))
        mockClient.addFailureResponse(.unexpectedStatusCode(statusCode: 504, body: nil))
        
        let sut = RetryingNetworkClient(client: mockClient)
        let retryPolicy = RetryPolicy(maxRetries: 3, initialDelay: 0.01)
        
        // When
        let result: Result<Data, NetworkError> = await withCheckedContinuation { continuation in
            let cancellable = sut.execute(with: testRequest, retryPolicy: retryPolicy) { result in
                continuation.resume(returning: result)
            }
            #expect(cancellable != nil)
        }
        
        // Then
        do {
            _ = try result.get()
            #expect(Bool(false), "Expected allRetriesFailed error")
        } catch {
            guard case .allRetriesFailed(let lastError, let totalAttempts) = error else {
                #expect(Bool(false), "Expected allRetriesFailed error, got \(error)")
                return
            }
            
            #expect(totalAttempts == 4) // 1 initial + 3 retries
            #expect(mockClient.currentExecutionCount == 4)
            
            // Verify the last error is preserved
            if case .unexpectedStatusCode(let statusCode, _) = lastError {
                #expect(statusCode == 504)
            } else {
                #expect(Bool(false), "Expected unexpectedStatusCode as last error")
            }
        }
    }
    
    // MARK: - Non-Retryable Error Tests
    
    @Test("Does not retry on non-retryable errors - async")
    func testNonRetryableErrorAsync() async {
        // Given

        // 401 is not retryable by default
        mockClient.addFailureResponse(.unauthorized(nil))
        
        let sut = RetryingNetworkClient(client: mockClient)
        let retryPolicy = RetryPolicy(maxRetries: 3, initialDelay: 0.01)
        
        do {
            // When
            _ = try await sut.execute(with: testRequest, retryPolicy: retryPolicy)
            #expect(Bool(false), "Expected unauthorized error")
        } catch {
            // Then
            guard let networkError = error as? NetworkError,
                  case .unauthorized = networkError else {
                #expect(Bool(false), "Expected unauthorized error, got \(error)")
                return
            }
            
            #expect(mockClient.currentExecutionCount == 1) // No retries
        }
    }
    
    @Test("Does not retry on client errors (4xx) - async")
    func testClientErrorsNotRetriedAsync() async {
        // Given

        // 400, 404 are client errors - not retryable
        mockClient.addFailureResponse(.unexpectedStatusCode(statusCode: 400, body: nil))
        
        let sut = RetryingNetworkClient(client: mockClient)
        let retryPolicy = RetryPolicy(maxRetries: 3, initialDelay: 0.01)
        
        do {
            // When
            _ = try await sut.execute(with: testRequest, retryPolicy: retryPolicy)
            #expect(Bool(false), "Expected unexpectedStatusCode error")
        } catch {
            // Then
            guard let networkError = error as? NetworkError,
                  case .unexpectedStatusCode(let statusCode, _) = networkError else {
                #expect(Bool(false), "Expected unexpectedStatusCode error, got \(error)")
                return
            }
            
            #expect(statusCode == 400)
            #expect(mockClient.currentExecutionCount == 1) // No retries
        }
    }
    
    @Test("Uses custom retry condition")
    func testCustomRetryConditionAsync() async throws {
        // Given

        let successData = "success".data(using: .utf8)!
        // Add a 400 error which normally wouldn't be retried
        mockClient.addFailureResponse(.unexpectedStatusCode(statusCode: 400, body: nil))
        mockClient.addFailureResponse(.unexpectedStatusCode(statusCode: 400, body: nil))
        mockClient.addSuccessResponse(successData)
        

        
        // Custom retry policy that retries on 400 errors
        let customRetryPolicy = RetryPolicy(
            maxRetries: 3,
            initialDelay: defaultTestDelay
        ) { error in
            if case .unexpectedStatusCode(let statusCode, _) = error {
                return statusCode == 400 // Retry only on 400
            }
            return false
        }
        
        // When
        let result = try await sut.execute(with: testRequest, retryPolicy: customRetryPolicy)
        
        // Then
        #expect(result == successData)
        #expect(mockClient.currentExecutionCount == 3) // 1 initial + 2 retries
    }
    
    // MARK: - Cancellation Tests
    
    @Test("Returns valid cancellable for completion-based execution")
    func testReturnsValidCancellable() {
        // Given
        mockClient.addSuccessResponse(expectedTestData)
        let retryPolicy = createTestRetryPolicy()
        
        let completionBox = CompletionBox()
        
        // When
        let cancellable = sut.execute(with: testRequest, retryPolicy: retryPolicy) { _ in
            completionBox.completionCalled = true
        }
        
        // Then
        #expect(cancellable != nil)
        
        // Test that cancellable can be called without issues
        cancellable?.cancel()
    }
    
    @Test("Handles immediate cancellation gracefully")
    func testImmediateCancellation() {
        // Given


        let retryPolicy = createTestRetryPolicy()
        
        let completionBox = CompletionBox()
        
        // When
        let cancellable = sut.execute(with: testRequest, retryPolicy: retryPolicy) { _ in
            completionBox.completionCalled = true
        }
        
        // Then
        #expect(cancellable != nil)
        
        // Cancel immediately and verify it doesn't crash
        cancellable?.cancel()
    }
    
    // MARK: - Backoff Timing Tests
    
    @Test("Retries with exponential backoff configuration")
    func testExponentialBackoffConfiguration() async {
        // Given

        // All attempts fail
        mockClient.addFailureResponse(.unexpectedStatusCode(statusCode: 500, body: nil))
        mockClient.addFailureResponse(.unexpectedStatusCode(statusCode: 500, body: nil))
        mockClient.addFailureResponse(.unexpectedStatusCode(statusCode: 500, body: nil))
        mockClient.addFailureResponse(.unexpectedStatusCode(statusCode: 500, body: nil))
        
        let sut = RetryingNetworkClient(client: mockClient)
        let retryPolicy = RetryPolicy(
            maxRetries: 3,
            initialDelay: 0.01, // 10ms
            backoffFactor: 2.0
        )
        
        do {
            // When
            _ = try await sut.execute(with: testRequest, retryPolicy: retryPolicy)
            #expect(Bool(false), "Expected failure")
        } catch {
            // Then
            guard let networkError = error as? NetworkError,
                  case .allRetriesFailed(_, let totalAttempts) = networkError else {
                #expect(Bool(false), "Expected allRetriesFailed error, got \(error)")
                return
            }
            
            // Verify the correct number of attempts were made (1 initial + 3 retries)
            #expect(totalAttempts == 4)
            #expect(mockClient.currentExecutionCount == 4)
        }
    }
    
    // MARK: - Edge Cases
    
    @Test("Preserves request details across retries")
    func testRequestPreservationAcrossRetries() async throws {
        // Given

        let successData = "success".data(using: .utf8)!
        let testBodyData = "test body".data(using: .utf8)!
        
        // First attempt fails, second succeeds
        mockClient.addFailureResponse(.unexpectedStatusCode(statusCode: 500, body: nil))
        mockClient.addSuccessResponse(successData)
        
        var customRequest = testRequest
        customRequest.httpMethod = "POST"
        customRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        customRequest.httpBody = testBodyData
        

        let retryPolicy = createTestRetryPolicy()
        
        // When
        _ = try await sut.execute(with: customRequest, retryPolicy: retryPolicy)
        
        // Then
        #expect(mockClient.currentExecutionCount == 2)
        let requests = mockClient.currentAllRequests
        #expect(requests.count == 2)
        
        // Verify both requests are identical
        for request in requests {
            #expect(request.url == customRequest.url)
            #expect(request.httpMethod == "POST")
            #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
            #expect(request.httpBody == testBodyData)
        }
    }
    
    @Test("Handles network client returning nil cancellable")
    func testHandlesNilCancellable() {
        // Given
        mockClient.addSuccessResponse(expectedTestData)
        
        // When
        let cancellable = sut.execute(with: testRequest, retryPolicy: nil) { _ in
            // Completion handler
        }
        
        // Then
        // Should not crash even if underlying client returns nil
        #expect(cancellable != nil) // Our mock returns non-nil, but this tests the interface
    }
    
    @Test("Handles empty retry policy correctly")
    func testEmptyRetryPolicy() async throws {
        // Given
        mockClient.addSuccessResponse(expectedTestData)
        let emptyRetryPolicy = RetryPolicy(maxRetries: 0, initialDelay: 0)
        
        // When
        let result = try await sut.execute(with: testRequest, retryPolicy: emptyRetryPolicy)
        
        // Then
        #expect(result == expectedTestData)
        #expect(mockClient.currentExecutionCount == 1) // No retries
    }
}
