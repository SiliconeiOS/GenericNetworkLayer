//
//  File.swift
//  GenericNetworkLayer
//
//

import Foundation

public protocol RequestBuilderProtocol: Sendable {
    func buildRequest<R: APIRequestProtocol>(
        from apiRequest: R,
        baseURL: String,
        tokenProvider: TokenProviderProtocol?
    ) throws -> URLRequest
}

public final class RequestBuilder: RequestBuilderProtocol {
    
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
        
        if apiRequest is (any AuthorizableRequestProtocol),
           let provider = tokenProvider,
           let token = provider.getAccessToken()
        {
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
