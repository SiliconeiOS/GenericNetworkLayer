//
//  File.swift
//  GenericNetworkLayer
//
//

import Foundation

public protocol APIRequestProtocol: Sendable {
    associatedtype Response: Decodable
    
    var endpoint: String { get }
    var parameters: [URLQueryItem]? { get }
    var method: HTTPMethod { get }
    var headers: [String: String]? { get }
    var body: Data? { get throws }
    var retryPolicy: RetryPolicy? { get }
}

public enum HTTPMethod: String {
    case GET
    case POST
    case PUT
    case DELETE
}

public extension APIRequestProtocol {
    var parameters: [URLQueryItem]? { nil }
    var body: Data? { nil }
    var method: HTTPMethod { .GET }
    var headers: [String: String]? { nil }
    var retryPolicy: RetryPolicy? { nil }
}

public extension APIRequestProtocol where Self: Encodable {
    var body: Data? {
        try? JSONEncoder().encode(self)
    }
    
    var headers: [String: String]? {
        [.contentTypeHeader: .jsonContentType]
    }
}

private extension String {
    static var contentTypeHeader: String { "Content-Type" }
    static var jsonContentType: String { "application/json" }
}
