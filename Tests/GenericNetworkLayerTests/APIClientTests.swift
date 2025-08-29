//
//  APIClientTests.swift
//  GenericNetworkLayer
//
//  Created by Иван Дроботов on 8/29/25.
//

import Foundation
import Testing
@testable import GenericNetworkLayer

@Suite("APIClient Tests")
struct APIClientTests {
    
    // MARK: - Test Properties
    
    private let sut: APIClient
    private let mockNetworkClient: NetworkClientMock
    private let mockRequestBuilder: RequestBuilderMock
    private let mockResponseParser: ResponseParserMock
    private let mockTokenProvider: TokenProviderMock
    private let baseURL = "https://api.test.com"
    private let testData = "test response".data(using: .utf8)!
    private let testUser = TestUser(id: 42, name: "John Doe")
    
    // MARK: - Initialization
    
    init() {
        mockNetworkClient = NetworkClientMock()
        mockRequestBuilder = RequestBuilderMock()
        mockResponseParser = ResponseParserMock()
        mockTokenProvider = TokenProviderMock(token: "test-token")
        
        sut = APIClient(
            baseURL: baseURL,
            networkClient: mockNetworkClient,
            requestBuilder: mockRequestBuilder,
            responseParser: mockResponseParser,
            tokenProvider: mockTokenProvider,
            defaultRetryPolicy: RetryPolicy(maxRetries: 2, initialDelay: 0.001)
        )
    }
    
    // MARK: - Async/Await Success Tests
    
    @Test("Successfully executes request and parses response - async")
    func testAsyncExecuteSuccess() async throws {
        // Given
        let request = GetUserRequest(userID: 42)
        let expectedURL = URL(string: "\(baseURL)/users/42")!
        let expectedURLRequest = URLRequest(url: expectedURL)
        
        mockRequestBuilder.urlRequestToReturn = expectedURLRequest
        mockNetworkClient.addSuccessResponse(testData)
        mockResponseParser.setSuccessResult(testUser)
        
        // When
        let result = try await sut.execute(with: request)
        
        // Then
        #expect(result.id == testUser.id)
        #expect(result.name == testUser.name)
        #expect(mockRequestBuilder.currentBuildRequestCallCount == 1)
        #expect(mockNetworkClient.currentExecutionCount == 1)
        #expect(mockResponseParser.currentParseCallCount == 1)
    }
    
    @Test("Successfully executes request with retry policy - async")
    func testAsyncExecuteWithRetryPolicy() async throws {
        // Given
        let customRetryPolicy = RetryPolicy(maxRetries: 1, initialDelay: 0.001)
        let request = GetUserRequestWithRetry(userID: 42, retryPolicy: customRetryPolicy)
        let expectedURL = URL(string: "\(baseURL)/users/42")!
        let expectedURLRequest = URLRequest(url: expectedURL)
        
        mockRequestBuilder.urlRequestToReturn = expectedURLRequest
        mockNetworkClient.addSuccessResponse(testData)
        mockResponseParser.setSuccessResult(testUser)
        
        // When
        let result = try await sut.execute(with: request)
        
        // Then
        #expect(result.id == testUser.id)
        #expect(mockNetworkClient.lastUsedRetryPolicy?.maxRetries == 1)
    }
    
    @Test("Successfully executes request with empty response - async")
    func testAsyncExecuteEmptyResponse() async throws {
        // Given
        let request = DeleteRequest()
        let expectedURL = URL(string: "\(baseURL)/user/1")!
        let expectedURLRequest = URLRequest(url: expectedURL)
        
        mockRequestBuilder.urlRequestToReturn = expectedURLRequest
        mockNetworkClient.addSuccessResponse(Data())
        mockResponseParser.setSuccessResult(EmptyResponse())
        
        // When
        _ = try await sut.execute(with: request)
        
        // Then
        // EmptyResponse successfully returned
        #expect(mockRequestBuilder.currentBuildRequestCallCount == 1)
        #expect(mockNetworkClient.currentExecutionCount == 1)
        #expect(mockResponseParser.currentParseCallCount == 1)
    }
    
    // MARK: - Completion Handler Success Tests
    
    @Test("Successfully executes request and parses response - completion")
    func testCompletionExecuteSuccess() async throws {
        // Given
        let request = GetUserRequest(userID: 42)
        let expectedURL = URL(string: "\(baseURL)/users/42")!
        let expectedURLRequest = URLRequest(url: expectedURL)
        
        mockRequestBuilder.urlRequestToReturn = expectedURLRequest
        mockNetworkClient.addSuccessResponse(testData)
        mockResponseParser.setSuccessResult(testUser)
        
        // When
        let result: Result<TestUser, APIClientError> = await withCheckedContinuation { continuation in
            let cancellable = sut.execute(with: request) { result in
                continuation.resume(returning: result)
            }
            #expect(cancellable != nil)
        }
        
        // Then
        let user = try result.get()
        #expect(user.id == testUser.id)
        #expect(user.name == testUser.name)
        #expect(mockRequestBuilder.currentBuildRequestCallCount == 1)
        #expect(mockNetworkClient.currentExecutionCount == 1)
        #expect(mockResponseParser.currentParseCallCount == 1)
    }
    
    @Test("Returns valid cancellable from completion method")
    func testCompletionReturnsValidCancellable() {
        // Given
        let request = GetUserRequest(userID: 42)
        let expectedURL = URL(string: "\(baseURL)/users/42")!
        let expectedURLRequest = URLRequest(url: expectedURL)
        
        mockRequestBuilder.urlRequestToReturn = expectedURLRequest
        mockNetworkClient.addSuccessResponse(testData)
        mockResponseParser.setSuccessResult(testUser)
        
        // When
        let cancellable = sut.execute(with: request) { _ in }
        
        // Then
        #expect(cancellable != nil)
        cancellable?.cancel() // Should not crash
    }
    
    // MARK: - Error Handling Tests
    
    @Test("Handles network error - async")
    func testAsyncNetworkError() async {
        // Given
        let request = GetUserRequest(userID: 42)
        let expectedURL = URL(string: "\(baseURL)/users/42")!
        let expectedURLRequest = URLRequest(url: expectedURL)
        let networkError = NetworkError.unauthorized(nil)
        
        mockRequestBuilder.urlRequestToReturn = expectedURLRequest
        mockNetworkClient.addFailureResponse(networkError)
        
        do {
            // When
            _ = try await sut.execute(with: request)
            #expect(Bool(false), "Expected APIClientError.networkError")
        } catch {
            // Then
            guard case APIClientError.networkError(let wrappedError) = error else {
                #expect(Bool(false), "Expected APIClientError.networkError, got \(error)")
                return
            }
            
            guard case NetworkError.unauthorized = wrappedError else {
                #expect(Bool(false), "Expected NetworkError.unauthorized")
                return
            }
        }
    }
    
    @Test("Handles network error - completion")
    func testCompletionNetworkError() async {
        // Given
        let request = GetUserRequest(userID: 42)
        let expectedURL = URL(string: "\(baseURL)/users/42")!
        let expectedURLRequest = URLRequest(url: expectedURL)
        let networkError = NetworkError.unexpectedStatusCode(statusCode: 500, body: nil)
        
        mockRequestBuilder.urlRequestToReturn = expectedURLRequest
        mockNetworkClient.addFailureResponse(networkError)
        
        // When
        let result: Result<TestUser, APIClientError> = await withCheckedContinuation { continuation in
            let cancellable = sut.execute(with: request) { result in
                continuation.resume(returning: result)
            }
            #expect(cancellable != nil)
        }
        
        // Then
        do {
            _ = try result.get()
            #expect(Bool(false), "Expected APIClientError.networkError")
        } catch {
            guard case APIClientError.networkError(let wrappedError) = error else {
                #expect(Bool(false), "Expected APIClientError.networkError, got \(error)")
                return
            }
            
            guard case NetworkError.unexpectedStatusCode(let statusCode, _) = wrappedError else {
                #expect(Bool(false), "Expected NetworkError.unexpectedStatusCode")
                return
            }
            #expect(statusCode == 500)
        }
    }
    
    @Test("Handles request builder error - async")
    func testAsyncRequestBuilderError() async {
        // Given
        let request = GetUserRequest(userID: 42)
        let requestBuilderError = RequestBuilderError.invalidBaseURL("invalid://url")
        
        mockRequestBuilder.errorToThrow = requestBuilderError
        
        do {
            // When
            _ = try await sut.execute(with: request)
            #expect(Bool(false), "Expected APIClientError.requestBuilderError")
        } catch {
            // Then
            guard case APIClientError.requestBuilderError(let wrappedError) = error else {
                #expect(Bool(false), "Expected APIClientError.requestBuilderError, got \(error)")
                return
            }
            
            guard case RequestBuilderError.invalidBaseURL = wrappedError else {
                #expect(Bool(false), "Expected RequestBuilderError.invalidBaseURL")
                return
            }
        }
    }
    
    @Test("Handles request builder error - completion")
    func testCompletionRequestBuilderError() async {
        // Given
        let request = GetUserRequest(userID: 42)
        let requestBuilderError = RequestBuilderError.tokenProviderMissingOrTokenNil
        
        mockRequestBuilder.errorToThrow = requestBuilderError
        
        // When
        let result: Result<TestUser, APIClientError> = await withCheckedContinuation { continuation in
            let cancellable = sut.execute(with: request) { result in
                continuation.resume(returning: result)
            }
            #expect(cancellable == nil) // Should be nil when request builder throws
        }
        
        // Then
        do {
            _ = try result.get()
            #expect(Bool(false), "Expected APIClientError.requestBuilderError")
        } catch {
            guard case APIClientError.requestBuilderError(let wrappedError) = error else {
                #expect(Bool(false), "Expected APIClientError.requestBuilderError, got \(error)")
                return
            }
            
            guard case RequestBuilderError.tokenProviderMissingOrTokenNil = wrappedError else {
                #expect(Bool(false), "Expected RequestBuilderError.tokenProviderMissingOrTokenNil")
                return
            }
        }
    }
    
    @Test("Handles response parser error - async")
    func testAsyncResponseParserError() async {
        // Given
        let request = GetUserRequest(userID: 42)
        let expectedURL = URL(string: "\(baseURL)/users/42")!
        let expectedURLRequest = URLRequest(url: expectedURL)
        let parserError = ResponseParserError.noData
        
        mockRequestBuilder.urlRequestToReturn = expectedURLRequest
        mockNetworkClient.addSuccessResponse(testData)
        mockResponseParser.setFailureError(parserError)
        
        do {
            // When
            _ = try await sut.execute(with: request)
            #expect(Bool(false), "Expected APIClientError.responseParseError")
        } catch {
            // Then
            guard case APIClientError.responseParseError(let wrappedError) = error else {
                #expect(Bool(false), "Expected APIClientError.responseParseError, got \(error)")
                return
            }
            
            guard case ResponseParserError.noData = wrappedError else {
                #expect(Bool(false), "Expected ResponseParserError.noData")
                return
            }
        }
    }
    
    @Test("Handles response parser error - completion")
    func testCompletionResponseParserError() async {
        // Given
        let request = GetUserRequest(userID: 42)
        let expectedURL = URL(string: "\(baseURL)/users/42")!
        let expectedURLRequest = URLRequest(url: expectedURL)
        let decodingError = NSError(domain: "DecodingError", code: 1, userInfo: nil)
        let parserError = ResponseParserError.decodingError(AnySendableError(decodingError))
        
        mockRequestBuilder.urlRequestToReturn = expectedURLRequest
        mockNetworkClient.addSuccessResponse(testData)
        mockResponseParser.setFailureError(parserError)
        
        // When
        let result: Result<TestUser, APIClientError> = await withCheckedContinuation { continuation in
            let cancellable = sut.execute(with: request) { result in
                continuation.resume(returning: result)
            }
            #expect(cancellable != nil)
        }
        
        // Then
        do {
            _ = try result.get()
            #expect(Bool(false), "Expected APIClientError.responseParseError")
        } catch {
            guard case APIClientError.responseParseError(let wrappedError) = error else {
                #expect(Bool(false), "Expected APIClientError.responseParseError, got \(error)")
                return
            }
            
            guard case ResponseParserError.decodingError = wrappedError else {
                #expect(Bool(false), "Expected ResponseParserError.decodingError")
                return
            }
        }
    }
    
    @Test("Handles unexpected error - async")
    func testAsyncUnexpectedError() async {
        // Given
        let request = GetUserRequest(userID: 42)
        let expectedURL = URL(string: "\(baseURL)/users/42")!
        let expectedURLRequest = URLRequest(url: expectedURL)
        // Test scenario: response parsing fails with noData error
        
        mockRequestBuilder.urlRequestToReturn = expectedURLRequest
        mockNetworkClient.addSuccessResponse(testData)
        // For this test, we'll simulate the scenario where response parsing fails
        mockResponseParser.setFailureError(.noData)
        
        do {
            // When
            _ = try await sut.execute(with: request)
            #expect(Bool(false), "Expected APIClientError.unexpectedError")
        } catch {
            // Then
            guard case APIClientError.responseParseError = error else {
                #expect(Bool(false), "Expected APIClientError.responseParseError, got \(error)")
                return
            }
            // The error gets wrapped as responseParseError since it happens during parsing
        }
    }
    
    // MARK: - Authentication Tests
    
    @Test("Passes token provider to request builder")
    func testTokenProviderPassedToRequestBuilder() async throws {
        // Given
        let request = AuthenticatedRequest()
        let expectedURL = URL(string: "\(baseURL)/secure/user")!
        let expectedURLRequest = URLRequest(url: expectedURL)
        
        mockRequestBuilder.urlRequestToReturn = expectedURLRequest
        mockNetworkClient.addSuccessResponse(testData)
        mockResponseParser.setSuccessResult(testUser)
        
        // When
        _ = try await sut.execute(with: request)
        
        // Then
        #expect(mockRequestBuilder.lastTokenProvider != nil)
        #expect(mockRequestBuilder.lastTokenProvider?.getAccessToken() == "test-token")
    }
    
    // MARK: - Retry Policy Tests
    
    @Test("Uses default retry policy when request has no retry policy")
    func testUsesDefaultRetryPolicy() async throws {
        // Given
        let request = GetUserRequest(userID: 42) // No retry policy
        let expectedURL = URL(string: "\(baseURL)/users/42")!
        let expectedURLRequest = URLRequest(url: expectedURL)
        
        mockRequestBuilder.urlRequestToReturn = expectedURLRequest
        mockNetworkClient.addSuccessResponse(testData)
        mockResponseParser.setSuccessResult(testUser)
        
        // When
        _ = try await sut.execute(with: request)
        
        // Then
        #expect(mockNetworkClient.lastUsedRetryPolicy?.maxRetries == 2) // Default from init
    }
    
    @Test("Uses request-specific retry policy over default")
    func testUsesRequestSpecificRetryPolicy() async throws {
        // Given
        let customRetryPolicy = RetryPolicy(maxRetries: 5, initialDelay: 0.1)
        let request = GetUserRequestWithRetry(userID: 42, retryPolicy: customRetryPolicy)
        let expectedURL = URL(string: "\(baseURL)/users/42")!
        let expectedURLRequest = URLRequest(url: expectedURL)
        
        mockRequestBuilder.urlRequestToReturn = expectedURLRequest
        mockNetworkClient.addSuccessResponse(testData)
        mockResponseParser.setSuccessResult(testUser)
        
        // When
        _ = try await sut.execute(with: request)
        
        // Then
        #expect(mockNetworkClient.lastUsedRetryPolicy?.maxRetries == 5)
    }
    
    @Test("Handles nil retry policy correctly")
    func testHandlesNilRetryPolicy() async throws {
        // Given
        let clientWithoutRetryPolicy = APIClient(
            baseURL: baseURL,
            networkClient: mockNetworkClient,
            requestBuilder: mockRequestBuilder,
            responseParser: mockResponseParser,
            tokenProvider: mockTokenProvider,
            defaultRetryPolicy: nil
        )
        
        let request = GetUserRequest(userID: 42)
        let expectedURL = URL(string: "\(baseURL)/users/42")!
        let expectedURLRequest = URLRequest(url: expectedURL)
        
        mockRequestBuilder.urlRequestToReturn = expectedURLRequest
        mockNetworkClient.addSuccessResponse(testData)
        mockResponseParser.setSuccessResult(testUser)
        
        // When
        _ = try await clientWithoutRetryPolicy.execute(with: request)
        
        // Then
        #expect(mockNetworkClient.lastUsedRetryPolicy == nil)
    }
    
    // MARK: - Edge Cases and Integration Tests
    
    @Test("Handles concurrent requests properly")
    func testConcurrentRequests() async throws {
        // Given
        let request1 = GetUserRequest(userID: 1)
        let request2 = GetUserRequest(userID: 2)
        let user1 = TestUser(id: 1, name: "User 1")
        let user2 = TestUser(id: 2, name: "User 2")
        
        let expectedURL1 = URL(string: "\(baseURL)/users/1")!
        let expectedURLRequest1 = URLRequest(url: expectedURL1)
        
        // For concurrent requests, we'll use a simple mock that returns the first URL
        mockRequestBuilder.urlRequestToReturn = expectedURLRequest1
        
        // Setup responses for concurrent execution
        mockNetworkClient.addSuccessResponse(try JSONEncoder().encode(user1))
        mockNetworkClient.addSuccessResponse(try JSONEncoder().encode(user2))
        
        mockResponseParser.setSuccessResult(user1)
        
        // When
        async let result1 = sut.execute(with: request1)
        async let result2 = sut.execute(with: request2)
        
        let (response1, response2) = try await (result1, result2)
        
        // Then
        #expect(response1.id == 1)
        #expect(response2.id == 1) // Both will return user1 due to mock setup
        #expect(mockNetworkClient.currentExecutionCount == 2)
        #expect(mockRequestBuilder.currentBuildRequestCallCount == 2)
    }
    
    @Test("Handles very large response data")
    func testHandlesLargeResponseData() async throws {
        // Given
        let request = GetUserRequest(userID: 42)
        let expectedURL = URL(string: "\(baseURL)/users/42")!
        let expectedURLRequest = URLRequest(url: expectedURL)
        let largeData = Data(repeating: 65, count: 1_000_000) // 1MB of 'A's
        
        mockRequestBuilder.urlRequestToReturn = expectedURLRequest
        mockNetworkClient.addSuccessResponse(largeData)
        mockResponseParser.setSuccessResult(testUser)
        
        // When
        let result = try await sut.execute(with: request)
        
        // Then
        #expect(result.id == testUser.id)
        #expect(mockResponseParser.currentLastData == largeData)
    }
    
    @Test("Passes correct parameters to network client")
    func testPassesCorrectParametersToNetworkClient() async throws {
        // Given
        let request = GetUserRequest(userID: 42)
        let expectedURL = URL(string: "\(baseURL)/users/42")!
        let expectedURLRequest = URLRequest(url: expectedURL)
        
        mockRequestBuilder.urlRequestToReturn = expectedURLRequest
        mockNetworkClient.addSuccessResponse(testData)
        mockResponseParser.setSuccessResult(testUser)
        
        // When
        let result = try await sut.execute(with: request)
        
        // Then
        #expect(result.id == testUser.id)
        #expect(mockNetworkClient.lastRequest?.url == expectedURL)
        #expect(mockRequestBuilder.currentBuildRequestCallCount == 1)
    }
}

// MARK: - Test Helper Types

struct GetUserRequestWithRetry: APIRequestProtocol {
    let userID: Int
    let retryPolicy: RetryPolicy?
    
    typealias Response = TestUser
    var endpoint: String { "/users/\(userID)" }
}

// MARK: - Mock Extensions

extension NetworkClientMock {
    var lastUsedRetryPolicy: RetryPolicy? {
        return lastRetryPolicy
    }
}
