//
//  File.swift
//  GenericNetworkLayer
//
//

import Foundation

/// A protocol defining the interface for API clients that can execute network requests.
///
/// This protocol provides both async/await and callback-based methods for executing
/// API requests with type-safe response handling.
public protocol APIClientProtocol: Sendable { 
    /// Executes an API request using a completion handler.
    ///
    /// - Parameters:
    ///   - request: The API request to execute, conforming to `APIRequestProtocol`
    ///   - completion: Completion handler called with the result
    /// - Returns: A cancellable token, or nil if the request failed to start
    @discardableResult
    func execute<R: APIRequestProtocol>(
        with request: R,
        completion: @escaping @Sendable (Result<R.Response, APIClientError>) -> Void
    ) -> Cancellable?
    
    /// Executes an API request using async/await.
    ///
    /// - Parameter request: The API request to execute, conforming to `APIRequestProtocol`
    /// - Returns: The parsed response of type `R.Response`
    /// - Throws: `APIClientError` if the request fails at any stage
    func execute<R: APIRequestProtocol>(with request: R) async throws -> R.Response
}

/// A comprehensive network client for type-safe API requests with built-in retry logic.
///
/// `APIClient` provides a high-level interface for making HTTP requests with:
/// - Type-safe request/response handling
/// - Automatic retry with configurable policies
/// - Built-in authentication token handling  
/// - Comprehensive error handling and logging
/// - Support for both async/await and callback patterns
///
/// ## Usage
///
/// ### Basic Setup
/// ```swift
/// let client = APIClient(
///     baseURL: "https://api.example.com",
///     enableLogging: true
/// )
/// ```
///
/// ### Making Requests
/// ```swift
/// // Async/await
/// let response = try await client.execute(with: MyRequest())
///
/// // Callback-based
/// client.execute(with: MyRequest()) { result in
///     switch result {
///     case .success(let response):
///         // Handle success
///     case .failure(let error):
///         // Handle error
///     }
/// }
/// ```
///
/// ### With Authentication
/// ```swift
/// let client = APIClient(
///     baseURL: "https://api.example.com",
///     tokenProvider: MyTokenProvider()
/// )
/// ```
public final class APIClient: APIClientProtocol {
    private let baseURL: String
    private let networkClient: NetworkClientProtocol
    private let requestBuilder: RequestBuilderProtocol
    private let responseParser: ResponseParserProtocol
    private let tokenProvider: TokenProviderProtocol?
    private let defaultRetryPolicy: RetryPolicy?
    
    /// Creates an API client with custom dependencies.
    ///
    /// This initializer allows full customization of all client dependencies,
    /// useful for testing or advanced configurations.
    ///
    /// - Parameters:
    ///   - baseURL: The base URL for all API requests
    ///   - networkClient: The network client for executing requests
    ///   - requestBuilder: The request builder for creating URLRequests
    ///   - responseParser: The response parser for handling responses
    ///   - tokenProvider: Optional token provider for authentication
    ///   - defaultRetryPolicy: Optional default retry policy for failed requests
    public init(
        baseURL: String,
        networkClient: NetworkClientProtocol,
        requestBuilder: RequestBuilderProtocol,
        responseParser: ResponseParserProtocol,
        tokenProvider: TokenProviderProtocol? = nil,
        defaultRetryPolicy: RetryPolicy? = nil
    ) {
        self.baseURL = baseURL
        self.networkClient = networkClient
        self.requestBuilder = requestBuilder
        self.responseParser = responseParser
        self.tokenProvider = tokenProvider
        self.defaultRetryPolicy = defaultRetryPolicy
    }

    /// Creates an API client with common configuration options.
    ///
    /// This convenience initializer sets up the client with sensible defaults
    /// and commonly used configurations.
    ///
    /// - Parameters:
    ///   - baseURL: The base URL for all API requests
    ///   - session: URLSession to use for network requests
    ///   - decoder: JSONDecoder for parsing JSON responses
    ///   - tokenProvider: Optional token provider for authentication
    ///   - enableLogging: Whether to enable network request/response logging
    ///   - defaultRetryPolicy: Optional default retry policy for failed requests
    public convenience init(
        baseURL: String,
        session: URLSession,
        decoder: JSONDecoder = JSONDecoder(),
        tokenProvider: TokenProviderProtocol? = nil,
        enableLogging: Bool = false,
        defaultRetryPolicy: RetryPolicy? = nil
    ) {
        let logger: NetworkLoggerProtocol? = enableLogging ? DefaultNetworkLogger() : nil
        
        let baseNetworkClient = NetworkClient(session: session, logger: logger)
        let retryingNetworkClient = RetryingNetworkClient(client: baseNetworkClient)
        
        let requestBuilder = RequestBuilder()
        let responseParser = ResponseParser(decoder: decoder)
        self.init(
            baseURL: baseURL,
            networkClient: retryingNetworkClient,
            requestBuilder: requestBuilder,
            responseParser: responseParser,
            tokenProvider: tokenProvider,
            defaultRetryPolicy: defaultRetryPolicy
        )
    }
    
    @discardableResult
    public func execute<R>(
        with request: R,
        completion: @escaping @Sendable (Result<R.Response, APIClientError>) -> Void
    ) -> Cancellable? where R: APIRequestProtocol {
        do {
            let policy = request.retryPolicy ?? defaultRetryPolicy
            
            let urlRequest = try requestBuilder.buildRequest(from: request, baseURL: baseURL, tokenProvider: tokenProvider)
            
            return networkClient.execute(with: urlRequest, retryPolicy: policy) { [weak self] result in
                guard let self else { return }
                
                switch result {
                case .success(let data):
                    let parsingResult = self.responseParser.parse(request, data: data)
                    switch parsingResult {
                    case .success(let response):
                        completion(.success(response))
                    case .failure(let error):
                        completion(.failure(.responseParseError(error)))
                    }
                case .failure(let networkError):
                    completion(.failure(.networkError(networkError)))
                }
            }
        } catch let error as RequestBuilderError {
            completion(.failure(.requestBuilderError(error)))
            return nil
        } catch {
            completion(.failure(.unexpectedError(AnySendableError(error))))
            return nil
        }
    }
    
    public func execute<R>(
        with request: R
    ) async throws -> R.Response where R : APIRequestProtocol {
        do {
            let policy = request.retryPolicy ?? defaultRetryPolicy
            let urlRequest = try requestBuilder.buildRequest(from: request, baseURL: baseURL, tokenProvider: tokenProvider)
            let data = try await networkClient.execute(with: urlRequest, retryPolicy: policy)
            let parsingResult = responseParser.parse(request, data: data)
            return try parsingResult.get()
        } catch let error as RequestBuilderError {
            throw APIClientError.requestBuilderError(error)
        } catch let error as NetworkError {
            throw APIClientError.networkError(error)
        } catch let error as ResponseParserError {
            throw APIClientError.responseParseError(error)
        } catch {
            throw APIClientError.unexpectedError(AnySendableError(error))
        }
    }
}
