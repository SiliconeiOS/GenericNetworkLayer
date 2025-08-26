//
//  File.swift
//  GenericNetworkLayer
//
//

import Foundation

/// A protocol for building URLRequests from API request objects.
///
/// Implementations of this protocol handle the conversion from high-level
/// API request objects to low-level URLRequest objects that can be executed
/// by the network layer.
public protocol RequestBuilderProtocol: Sendable {
    /// Builds a URLRequest from an API request object.
    ///
    /// - Parameters:
    ///   - apiRequest: The API request object containing request details
    ///   - baseURL: The base URL to prepend to the request endpoint
    ///   - tokenProvider: Optional token provider for authentication
    /// - Returns: A configured URLRequest ready for execution
    /// - Throws: `RequestBuilderError` if the request cannot be built
    func buildRequest<R: APIRequestProtocol>(
        from apiRequest: R,
        baseURL: String,
        tokenProvider: TokenProviderProtocol?
    ) throws -> URLRequest
}

/// Default implementation of RequestBuilderProtocol.
///
/// This builder constructs URLRequests by:
/// - Combining base URL with request endpoint
/// - Adding query parameters and headers
/// - Handling request body encoding
/// - Adding authentication headers when needed
public final class RequestBuilder: RequestBuilderProtocol {
    
    /// Creates a new RequestBuilder instance.
    public init() {}
    
    public func buildRequest<R>(
        from apiRequest: R,
        baseURL: String,
        tokenProvider: TokenProviderProtocol? = nil
    ) throws -> URLRequest where R: APIRequestProtocol {
        
        guard let base = URL(string: baseURL) else {
            throw RequestBuilderError.invalidBaseURL(baseURL)
        }
        
        let fullURL = base.appendingPathComponent(apiRequest.endpoint)
        
        guard var components = URLComponents(url: fullURL, resolvingAgainstBaseURL: true) else {
            throw RequestBuilderError.componentsCreationFailed(fullURL)
        }
        
        components.queryItems = apiRequest.parameters
        
        guard let finalURL = components.url else {
            throw RequestBuilderError.finalURLCreationFailed(components)
        }
        
        var urlRequest = URLRequest(url: finalURL)
        urlRequest.httpMethod = apiRequest.method.rawValue
        
        do {
            urlRequest.httpBody = try apiRequest.body
        } catch {
            throw RequestBuilderError.bodyEncodingFailed(AnySendableError(error))
        }
        
        var allHeaders = apiRequest.headers ?? [:]
        
        switch apiRequest.authType {
        case .none:
            break
        case .bearerToken:
            guard let tokenProvider, let token = tokenProvider.getAccessToken() else {
                throw RequestBuilderError.tokenProviderMissingOrTokenNil
            }
            allHeaders[.auth] = "\(String.bearer) \(token)"
        }
        
        urlRequest.allHTTPHeaderFields = allHeaders
        
        return urlRequest
    }
}

private extension String {
    static var auth: String { "Authorization" }
    static var bearer: String { "Bearer" }
}
