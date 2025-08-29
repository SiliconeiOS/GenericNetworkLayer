//
//  File.swift
//  GenericNetworkLayer
//
//  Created by Иван Дроботов on 8/28/25.
//

import Foundation
import Testing
@testable import GenericNetworkLayer

final class CompletionBox: @unchecked Sendable {
    var completionCalled = false
}

@Suite("NetworkClient Tests")
struct NetworkClientTests {
    private let sut: NetworkClient
    private let loggerMock: NetworkLoggerMock
    private let baseURL = "https://api.test.com"
    private let testPath = "/test"
    private var testURL: URL {
        URL(string: baseURL + testPath)!
    }
    
    init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolMock.self]
        let session = URLSession(configuration: configuration)
        loggerMock = NetworkLoggerMock()
        self.sut = NetworkClient(session: session, logger: loggerMock)
    }
    
    //MARK: - Async/Await Tests
    
    @Test("Succeeds with valid data for a 200 OK response", .tags(.structuredConcurrency))
    func testAsyncExecuteSuccessWithValidData() async throws {
        
        // Given
        let expectedData = try JSONEncoder().encode(TestUser(id: 0, name: "Jane Doe"))
        let request = makeMockURLRequest(url: testURL, statusCode: 200, data: expectedData)
        
        // When
        let receivedData = try await sut.execute(with: request)
        
        // Then
        #expect(receivedData == expectedData)
        #expect(loggerMock.didLogRequest)
        #expect(loggerMock.didLogResponse)
        #expect(loggerMock.lastLoggedError == nil)
        #expect(loggerMock.lastLoggedData == expectedData)
    }
    
    @Test("Succeeds with empty data for a 204 No Content response", .tags(.structuredConcurrency))
    func testAsyncExecuteSuccessWithEmptyData() async throws {
        
        // Given
        let request = makeMockURLRequest(url: testURL, statusCode: 204)
        
        // When
        let receivedData = try await sut.execute(with: request)
        
        // Then
        #expect(receivedData.isEmpty)
        #expect(loggerMock.didLogRequest)
        #expect(loggerMock.didLogResponse)
        let data = try #require(loggerMock.lastLoggedData)
        #expect(data.isEmpty)
    }
    
    @Test("Throws unauthorized error for a 401 response", .tags(.structuredConcurrency, .errorHandling))
    func testAsyncExecuteFailureUnauthorized() async {
        
        // Given
        let expectedData = "{\"error\":\"token_expired\"}".data(using: .utf8)
        let request = makeMockURLRequest(url: testURL, statusCode: 401, data: expectedData)
        
        do {
            // When
            try await sut.execute(with: request)
            #expect(Bool(false), "Expected to throw NetworkError.unauthorized")
            // Then
        } catch {
            guard case NetworkError.unauthorized(let receivedData) = error else {
                #expect(Bool(false), "Expected NetworkError.unauthorized, got \(error)")
                return
            }
            #expect(expectedData == receivedData, "Error data mismatch")
        }
        
        #expect(loggerMock.didLogRequest)
        #expect(loggerMock.didLogResponse)
        #expect(loggerMock.lastLoggedError is NetworkError)
    }
    
    @Test("Throws unauthorized error for a 401 response with no data", .tags(.structuredConcurrency, .errorHandling))
    func testAsyncExecuteFailureUnauthorizedWithNilData() async throws {
        // Given
        let request = makeMockURLRequest(url: testURL, statusCode: 401)
        var receivedData: Data?
        
        do {
            // When
            try await sut.execute(with: request)
            #expect(Bool(false), "Expected to throw")
            // Then
        } catch {
            guard case .unauthorized(let data) = error as? NetworkError else {
                #expect(Bool(false), "Expected NetworkError.unauthorized, got \(error)")
                return
            }
            receivedData = data
        }
        
        let data = try #require(receivedData)
        #expect(data.isEmpty)
    }
    
    @Test("Throws unexpectedStatusCode error for a 500 response", .tags(.structuredConcurrency, .errorHandling))
    func testAsyncExecuteFailureUnexpectedStatusCode() async {
        
        // Given
        let expectedCode = 500
        let request = makeMockURLRequest(url: testURL, statusCode: expectedCode)
        
        do {
            // When
            try await sut.execute(with: request)
            #expect(Bool(false), "Expected to throw NetworkError.unexpectedStatusCode")
            // Then
        } catch {
            guard case NetworkError.unexpectedStatusCode(let code, _) = error else {
                #expect(Bool(false), "Expected NetworkError.unexpectedStatusCode, got \(error)")
                return
            }
            #expect(code == expectedCode)
        }
        
        #expect(loggerMock.didLogRequest)
        #expect(loggerMock.didLogResponse)
        #expect(loggerMock.lastLoggedError is NetworkError)
    }
    
    @Test("Throws requestFailed for an underlying URLSession error", .tags(.structuredConcurrency, .errorHandling))
    func testAsyncExecuteFailureRequestFailed() async {
        
        // Given
        let underlyingError = NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet, userInfo: nil)
        let request = makeMockURLRequest(url: testURL, error: underlyingError)
        
        do {
            // When
            try await sut.execute(with: request)
            #expect(Bool(false), "Expected method to be throw NetworkError.requestFailed")
            // Then
        } catch {
            guard case NetworkError.requestFailed(let wrappedError) = error else {
                #expect(Bool(false), "Expected NetworkError.requestFailed, got \(error)")
                return
            }
            #expect(wrappedError.code == underlyingError.code)
            #expect(loggerMock.didLogRequest)
            #expect(!loggerMock.didLogResponse)
            #expect(loggerMock.lastLoggedError is NetworkError)
        }
    }
    
    @Test("Throws invalidResponse error for non-HTTP response", .tags(.structuredConcurrency, .errorHandling))
    func testAsyncExecuteInvalidResponse() async throws {
        
        // Given
        let request = makeNonHTTPMockURLRequest(url: testURL)

        do {
            // When
            try await sut.execute(with: request)
            #expect(Bool(false), "Expected method to be throw NetworkError.invalidResponse")
            // Then
        } catch {
            guard case NetworkError.invalidResponse = error else {
                #expect(Bool(false), "Expected NetworkError.invalidResponse, got \(error)")
                return
            }
        }
        
        #expect(loggerMock.didLogRequest)
        #expect(loggerMock.didLogResponse)
        #expect(loggerMock.lastLoggedError is NetworkError)
    }
    
    @Test("Throws CancellationError when async task is cancelled", .tags(.structuredConcurrency, .errorHandling))
    func testAsyncExecuteCancellation() async throws {
        
        // Given
        let request = makeMockURLRequest(url: testURL, statusCode: 200, data: Data())
        
        // When
        let task = Task {
            try await sut.execute(with: request)
        }
        task.cancel()
        
        // Then
        do {
            _ = try await task.value
            #expect(Bool(false), "Expected task to be cancelled and throw CancellationError")
        } catch {
            guard error is CancellationError else {
                #expect(Bool(false), "Expected CancellationError but got \(error)")
                return
            }
        }
        
        #expect(loggerMock.didLogRequest)
        #expect(!loggerMock.didLogResponse)
    }
    
    @Test("Handles 200 response with nil data", .tags(.structuredConcurrency, .edgeCases))
    func testAsyncExecuteWith200AndNilData() async throws {
        
        // Given
        let request = makeMockURLRequest(url: testURL, statusCode: 200, data: nil)
        
        // When
        let receivedData = try await sut.execute(with: request)
        
        // Then
        #expect(receivedData.isEmpty)
        #expect(loggerMock.didLogRequest)
        #expect(loggerMock.didLogResponse)
        let data = try #require(loggerMock.lastLoggedData)
        #expect(data.isEmpty)
    }
    
    @Test(
        "Handles various 2xx status codes",
        .tags(.structuredConcurrency, .edgeCases),
        arguments: [200, 201, 202, 204, 299]
    )
    func testAsyncExecuteWithVarious2xxCodes(_ statusCode: Int) async throws {
        
        // Given
        let expectedData = "Test data for \(statusCode)".data(using: .utf8)!
        let request = makeMockURLRequest(url: testURL, statusCode: statusCode, data: expectedData)
        
        // When
        let receivedData = try await sut.execute(with: request)
        
        // Then
        #expect(receivedData == expectedData, "Failed for status code \(statusCode)")
    }
    
    @Test(
        "Handles various 5xx status codes",
        .tags(.structuredConcurrency, .edgeCases, .errorHandling),
        arguments: [500, 502, 503, 504]
    )
    func testAsyncExecuteWithVarious5xxCodes(_ statusCode: Int) async throws {
        // Given
        let errorData = "Server error \(statusCode)".data(using: .utf8)
        let request = makeMockURLRequest(url: testURL, statusCode: statusCode, data: errorData)
        
        do {
            // When
            _ = try await sut.execute(with: request)
            #expect(Bool(false), "Expected error for status code \(statusCode)")
        } catch {
            // Then
            guard case .unexpectedStatusCode(let code, let body) = error as? NetworkError else {
                #expect(Bool(false), "Expected unexpectedStatusCode for \(statusCode), got \(error)")
                return
            }
            #expect(code == statusCode)
            #expect(body == errorData)
        }
    }
    
    //MARK: - Completion-Based Tests
    
    @Test("Completion handler receives success with valid data for 200 OK response", .tags(.completionHandler))
    func testCompletionExecuteSuccessWithValidData() async throws {
        
        // Given
        let expectedData = try JSONEncoder().encode(TestUser(id: 1, name: "John Doe"))
        let request = makeMockURLRequest(url: testURL, statusCode: 200, data: expectedData)
        
        // When
        let result: Result<Data, NetworkError> = await withCheckedContinuation { continuation in
            let cancellable = sut.execute(with: request) { result in
                continuation.resume(returning: result)
            }
            #expect(cancellable != nil)
        }
        
        // Then
        let receivedData = try result.get()
        #expect(receivedData == expectedData)
        #expect(loggerMock.didLogRequest)
        #expect(loggerMock.didLogResponse)
        #expect(loggerMock.lastLoggedError == nil)
        #expect(loggerMock.lastLoggedData == expectedData)
    }
    
    @Test("Completion handler receives success with empty data for 204 No Content response", .tags(.completionHandler))
    func testCompletionExecuteSuccessWithEmptyData() async throws {
        
        // Given
        let request = makeMockURLRequest(url: testURL, statusCode: 204)
        
        // When
        let result: Result<Data, NetworkError> = await withCheckedContinuation { continuation in
            sut.execute(with: request) { result in
                continuation.resume(returning: result)
            }
        }
        
        // Then
        let receivedData = try result.get()
        #expect(receivedData.isEmpty)
        #expect(loggerMock.didLogRequest)
        #expect(loggerMock.didLogResponse)
        let loggedData = try #require(loggerMock.lastLoggedData)
        #expect(loggedData.isEmpty)
    }
    
    @Test("Completion handler receives unauthorized error for 401 response", .tags(.completionHandler, .errorHandling))
    func testCompletionExecuteFailureUnauthorized() async throws {
        
        // Given
        let expectedData = "{\"error\":\"token_expired\"}".data(using: .utf8)
        let request = makeMockURLRequest(url: testURL, statusCode: 401, data: expectedData)
        
        // When
        let result: Result<Data, NetworkError> = await withCheckedContinuation { continuation in
            sut.execute(with: request) { result in
                continuation.resume(returning: result)
            }
        }
        
        // Then
        do {
            _ = try result.get()
            #expect(Bool(false), "Expected failure but got success")
        } catch {
            guard case .unauthorized(let data) = error else {
                #expect(Bool(false), "Expected unauthorized error, got \(error)")
                return
            }
            #expect(data == expectedData)
            #expect(loggerMock.didLogRequest)
            #expect(loggerMock.didLogResponse)
            #expect(loggerMock.lastLoggedError is NetworkError)
        }
    }
    
    @Test("Completion handler receives unexpectedStatusCode error for 500 response", .tags(.completionHandler, .errorHandling))
    func testCompletionExecuteFailureUnexpectedStatusCode() async throws {
        
        // Given
        let expectedCode = 500
        let request = makeMockURLRequest(url: testURL, statusCode: expectedCode)
        
        // When
        let result: Result<Data, NetworkError> = await withCheckedContinuation { continuation in
            sut.execute(with: request) { result in
                continuation.resume(returning: result)
            }
        }
        
        // Then
        do {
            _ = try result.get()
            #expect(Bool(false), "Expected failure but got success")
        } catch {
            guard case .unexpectedStatusCode(let code, _) = error else {
                #expect(Bool(false), "Expected unexpectedStatusCode error, got \(error)")
                return
            }
            #expect(code == expectedCode)
            #expect(loggerMock.didLogRequest)
            #expect(loggerMock.didLogResponse)
            #expect(loggerMock.lastLoggedError is NetworkError)
            let data = try #require(loggerMock.lastLoggedData)
            #expect(data.isEmpty)
        }
    }
    
    @Test("Completion handler receives requestFailed error for underlying URLSession error", .tags(.completionHandler, .errorHandling))
    func testCompletionExecuteFailureRequestFailed() async throws {
        
        // Given
        let underlyingError = NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet, userInfo: nil)
        let request = makeMockURLRequest(url: testURL, error: underlyingError)
        
        // When
        let result: Result<Data, NetworkError> = await withCheckedContinuation { continuation in
            sut.execute(with: request) { result in
                continuation.resume(returning: result)
            }
        }
        
        // Then
        do {
            _ = try result.get()
            #expect(Bool(false), "Expected failure but got success")
        } catch {
            guard case .requestFailed(let wrappedError) = error else {
                #expect(Bool(false), "Expected requestFailed error, got \(error)")
                return
            }
            #expect(wrappedError.code == underlyingError.code)
            #expect(loggerMock.didLogRequest)
            #expect(!loggerMock.didLogResponse)
            #expect(loggerMock.lastLoggedError is NetworkError)
        }
    }
    
    @Test("Completion handler receives invalidResponse error for non-HTTP response", .tags(.completionHandler, .errorHandling))
    func testCompletionExecuteInvalidResponse() async throws {
        
        // Given
        let request = makeNonHTTPMockURLRequest(url: testURL)
        
        // When
        let result: Result<Data, NetworkError> = await withCheckedContinuation { continuation in
            sut.execute(with: request) { result in
                continuation.resume(returning: result)
            }
        }
        
        // Then
        do {
            _ = try result.get()
            #expect(Bool(false), "Expected failure but got success")
        } catch {
            guard case .invalidResponse = error else {
                #expect(Bool(false), "Expected invalidResponse error, got \(error)")
                return
            }
            #expect(loggerMock.didLogRequest)
            #expect(loggerMock.didLogResponse)
            #expect(loggerMock.lastLoggedError is NetworkError)
            let data = try #require(loggerMock.lastLoggedData)
            #expect(data.isEmpty)
        }
    }
    
    @Test("Completion handler handles cancellation properly", .tags(.completionHandler, .errorHandling))
    func testCompletionExecuteCancellation() async throws {
        
        // Given
        let request = makeMockURLRequest(url: testURL, statusCode: 200, data: Data())
        let completionBox = CompletionBox()
        
        // When
        let cancellable = sut.execute(with: request) { _ in
            completionBox.completionCalled = true
        }
        
        cancellable?.cancel()
        
        // Then
        #expect(!completionBox.completionCalled, "Completion should not be called after cancellation")
        #expect(loggerMock.didLogRequest)
        #expect(!loggerMock.didLogResponse)
    }
    
    @Test("Handles various 4xx status codes", .tags(.structuredConcurrency, .edgeCases, .errorHandling))
    func testAsyncExecuteWithVarious4xxCodes() async throws {
        
        let testCases = [400, 403, 404, 422, 429]
        
        for statusCode in testCases {
            // Given
            let errorData = "Error \(statusCode)".data(using: .utf8)
            let request = makeMockURLRequest(url: testURL, statusCode: statusCode, data: errorData)
            
            do {
                // When
                _ = try await sut.execute(with: request)
                #expect(Bool(false), "Expected error for status code \(statusCode)")
            } catch {
                // Then
                guard case .unexpectedStatusCode(let code, let body) = error as? NetworkError else {
                    #expect(Bool(false), "Expected unexpectedStatusCode for \(statusCode), got \(error)")
                    continue
                }
                #expect(code == statusCode)
                #expect(body == errorData)
            }
        }
    }
    
    //MARK: - Logger Tests
    
    @Test("NetworkClient works without logger", .tags(.structuredConcurrency, .logging))
    func testNetworkClientWithoutLogger() async throws {
        
        // Given
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolMock.self]
        let session = URLSession(configuration: configuration)
        let clientWithoutLogger = NetworkClient(session: session, logger: nil)
        let expectedData = "Test data".data(using: .utf8)!
        let request = makeMockURLRequest(url: testURL, statusCode: 200, data: expectedData)
        
        // When
        let receivedData = try await clientWithoutLogger.execute(with: request)
        
        // Then
        #expect(receivedData == expectedData)
    }
    
    @Test("Logger captures request details properly", .tags(.structuredConcurrency, .logging))
    func testLoggerCapturesRequestDetails() async throws {
        
        // Given
        let testData = "Request body".data(using: .utf8)!
        var request = URLRequest(url: testURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = testData
        
        let mockedRequest = makeMockURLRequest(url: testURL, statusCode: 200, data: testData)
        // Copy important details to mocked request
        var finalRequest = mockedRequest
        finalRequest.httpMethod = "POST"
        finalRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        finalRequest.httpBody = testData
        
        // When
        try await sut.execute(with: finalRequest)
        
        // Then
        #expect(loggerMock.didLogRequest)
        let loggedRequest = try #require(loggerMock.lastLoggedRequest)
        #expect(loggedRequest.httpMethod == "POST")
        #expect(loggedRequest.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(loggedRequest.httpBody == testData)
    }
    
    @Test("Logger captures response details properly", .tags(.structuredConcurrency, .logging))
    func testLoggerCapturesResponseDetails() async throws {
        
        // Given
        let expectedData = "Response data".data(using: .utf8)!
        let request = makeMockURLRequest(url: testURL, statusCode: 201, data: expectedData)
        
        // When
        _ = try await sut.execute(with: request)
        
        // Then
        #expect(loggerMock.didLogResponse)
        let loggedResponse = try #require(loggerMock.lastLoggedResponse as? HTTPURLResponse)
        #expect(loggedResponse.statusCode == 201)
        #expect(loggerMock.lastLoggedData == expectedData)
        #expect(loggerMock.lastLoggedError == nil)
    }
    
    @Test("Logger captures error details properly", .tags(.structuredConcurrency, .logging, .errorHandling))
    func testLoggerCapturesErrorDetails() async throws {
        
        // Given
        let request = makeMockURLRequest(url: testURL, statusCode: 404)
        
        do {
            // When
            _ = try await sut.execute(with: request)
            #expect(Bool(false), "Expected error")
        } catch {
            // Then
            #expect(loggerMock.didLogRequest)
            #expect(loggerMock.didLogResponse)
            #expect(loggerMock.lastLoggedError != nil)
            
            if let networkError = loggerMock.lastLoggedError as? NetworkError,
               case .unexpectedStatusCode(let code, _) = networkError {
                #expect(code == 404)
            } else {
                #expect(Bool(false), "Expected NetworkError.unexpectedStatusCode")
            }
        }
    }
}

private func makeNonHTTPMockURLRequest(url: URL) -> URLRequest {
    let request = URLRequest(url: url)
    return URLProtocolMock.mockNonHTTP(request) { _ in
        let nonHTTPResponse = URLResponse(
            url: url,
            mimeType: "text/plain",
            expectedContentLength: 0,
            textEncodingName: nil
        )
        return (nonHTTPResponse, nil)
    }
}

private func makeMockURLRequest(
    url: URL,
    statusCode: Int? = nil,
    data: Data? = nil,
    error: Error? = nil
) -> URLRequest {
    let request = URLRequest(url: url)
    return URLProtocolMock.mock(request) { _ in
        
        if let error {
            throw error
        }
        
        guard let statusCode else {
            #expect(Bool(false), "Unexpected statusCode equals nil")
            throw NetworkError.invalidResponse
        }
        
        guard let response = HTTPURLResponse(
            url: url,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        ) else {
            #expect(Bool(false), "Unexpected failed response constructed")
            throw NetworkError.invalidResponse
        }
        
        return (response, data)
    }
}

extension Tag {
    @Tag static var structuredConcurrency: Self
    @Tag static var errorHandling: Self
    @Tag static var completionHandler: Self
    @Tag static var retryPolicy: Self
    @Tag static var edgeCases: Self
    @Tag static var logging: Self
}
