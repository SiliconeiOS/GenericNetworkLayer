//
//  File.swift
//  GenericNetworkLayer
//
//

import Foundation

public protocol APIClientProtocol: Sendable { 
    @discardableResult
    func execute<R: APIRequestProtocol>(
        with request: R,
        completion: @escaping @Sendable (Result<R.Response, APIClientError>) -> Void
    ) -> Cancellable?
    
    func execute<R: APIRequestProtocol>(with request: R) async throws -> R.Response
}

public final class APIClient: APIClientProtocol {
    private let baseURL: String
    private let networkClient: NetworkClientProtocol
    private let requestBuilder: RequestBuilderProtocol
    private let responseParser: ResponseParserProtocol
    private let tokenProvider: TokenProviderProtocol?
    private let defaultRetryPolicy: RetryPolicy?
    
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

    public convenience init(
        baseURL: String,
        session: URLSession,
        decoder: JSONDecoder = JSONDecoder(),
        tokenProvider: TokenProviderProtocol? = nil,
        enableLogging: Bool = false, // <-- Используем только этот параметр
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
