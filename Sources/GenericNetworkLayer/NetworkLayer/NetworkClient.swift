//
//  File.swift
//  GenericNetworkLayer
//
//

import Foundation

/// Basic network client implementation using URLSession.
///
/// This class provides the fundamental network execution capabilities,
/// handling URLSession operations and basic response validation.
/// It supports optional logging and basic error handling.
public final class NetworkClient: NetworkClientProtocol {
    
    //MARK: - Dependencies
    
    private let session: URLSession
    private let logger: NetworkLoggerProtocol?
    
    //MARK: - Init
    
    /// Creates a NetworkClient with the specified URLSession and optional logger.
    ///
    /// - Parameters:
    ///   - session: The URLSession to use for network requests
    ///   - logger: Optional logger for debugging network activity
    public init(
        session: URLSession,
        logger: NetworkLoggerProtocol? = nil
    ) {
        self.session = session
        self.logger = logger
    }
    
    //MARK: - Implementation NetworkClientProtocol
    
    @discardableResult
    public func execute(
        with request: URLRequest,
        retryPolicy: RetryPolicy?,
        completion: @escaping @Sendable (Result<Data, NetworkError>) -> Void
    ) -> Cancellable? {
        logger?.log(request: request)
        let task = session.dataTask(with: request) { [weak self] data, response, error in
            guard let self else { return }
            
            if let sessionError = error {
                guard (sessionError as NSError).code != NSURLErrorCancelled else {
                    return
                }
                
                let networkError = NetworkError.requestFailed(AnySendableError(sessionError))
                logger?.log(response: response, data: data, error: networkError, for: request)
                completion(.failure(networkError))
                return
            }
            
            let validateResult = validate(data, response)
            
            var loggedError: NetworkError?
            if case .failure(let validationError) = validateResult {
                loggedError = validationError
            }
            logger?.log(response: response, data: data, error: loggedError, for: request)
            
            completion(validateResult)
        }
        
        task.resume()
        return task
    }
    
    public func execute(with request: URLRequest, retryPolicy: RetryPolicy?) async throws -> Data {
        logger?.log(request: request)
        
        var responseData: Data?
        var urlResponse: URLResponse?
        var responseError: Error?
        
        defer {
            logger?.log(response: urlResponse, data: responseData, error: responseError, for: request)
        }
        
        do {
            (responseData, urlResponse) = try await session.data(for: request, delegate: nil)
            return try validate(responseData, urlResponse).get()
        } catch is CancellationError {
            responseError = CancellationError()
            throw CancellationError()
        } catch let error as NetworkError {
            responseError = error
            throw error
        } catch {
            guard (error as NSError).code != NSURLErrorCancelled else {
                let cancellationError = CancellationError()
                responseError = cancellationError
                throw cancellationError
            }
            let wrappedError = NetworkError.requestFailed(AnySendableError(error))
            responseError = wrappedError
            throw wrappedError
        }
    }
    
    //MARK: - Private Section
    
    private func validate(_ data: Data?, _ response: URLResponse?) -> Result<Data, NetworkError> {
        
        guard let httpResponse = response as? HTTPURLResponse else {
            return .failure(.invalidResponse)
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            return httpResponse.statusCode == 401
            ? .failure(.unauthorized(data))
            : .failure(.unexpectedStatusCode(statusCode: httpResponse.statusCode, body: data))
        }
        
        return .success(data ?? Data())
    }
}
