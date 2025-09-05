//
//  TestRequests.swift
//  GenericNetworkLayer
//
//  Created by Иван Дроботов on 8/27/25.
//

import Foundation
@testable import GenericNetworkLayer

// MARK: - Basic CRUD Operations

struct GetUserRequest: APIRequestProtocol {
    let userID: Int
    
    typealias Response = TestUser
    var endpoint: String { "/users/\(userID)" }
}

struct CreateUserRequest: APIRequestProtocol, Encodable {
    let name: String
    
    typealias Response = TestUser
    var endpoint: String { "/users" }
    var method: HTTPMethod { .POST }
}

struct UpdateUserRequest: APIRequestProtocol, Encodable {
    typealias Response = TestUser
    
    let userID: Int
    let name: String
    
    var endpoint: String { "/users/\(userID)" }
    var method: HTTPMethod { .PUT }
}

struct DeleteRequest: APIRequestProtocol {
    typealias Response = EmptyResponse
    var endpoint: String { "/user/1" }
    var method: HTTPMethod { .DELETE }
}

// MARK: - Authentication

struct AuthenticatedRequest: APIRequestProtocol {
    typealias Response = TestUser
    var endpoint: String { "secure/user" }
    var authType: AuthorizationType { .bearerToken }
}

struct QueryApiKeyRequest: APIRequestProtocol {
    typealias Response = TestUser
    var endpoint: String { "/weather" }
    var authType: AuthorizationType { .queryApiKey(keyName: "appid") }
}

struct QueryApiKeyWithCustomKeyNameRequest: APIRequestProtocol {
    typealias Response = TestUser
    var endpoint: String { "/data" }
    var authType: AuthorizationType { .queryApiKey(keyName: "api_key") }
}

struct QueryApiKeyWithExistingParamsRequest: APIRequestProtocol {
    typealias Response = TestUser
    
    let city: String
    let units: String
    
    var endpoint: String { "/weather" }
    var authType: AuthorizationType { .queryApiKey(keyName: "appid") }
    var parameters: [URLQueryItem]? {
        [
            URLQueryItem(name: "q", value: city),
            URLQueryItem(name: "units", value: units)
        ]
    }
}

// MARK: - Query Parameters

struct GetUserWithParamsRequest: APIRequestProtocol {
    typealias Response = TestUser
    
    let userID: Int
    let limit: Int
    let offset: Int
    
    var endpoint: String { "/users/\(userID)" }
    var parameters: [URLQueryItem]? {
        [
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "offset", value: "\(offset)")
        ]
    }
}

struct SearchRequest: APIRequestProtocol {
    typealias Response = TestUser
    
    let query: String
    let filter: String
    
    var endpoint: String { "/search" }
    var parameters: [URLQueryItem]? {
        [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "filter", value: filter)
        ]
    }
}

struct EmptyQueryRequest: APIRequestProtocol {
    typealias Response = TestUser
    var endpoint: String { "/test" }
    var parameters: [URLQueryItem]? { nil }
}

// MARK: - Headers Testing

struct RequestWithCustomHeaders: APIRequestProtocol {
    typealias Response = TestUser
    
    var endpoint: String { "/test" }
    var headers: [String: String]? {
        [
            "X-Custom-Header": "custom-value",
            "Accept": "application/json"
        ]
    }
}

struct CreateUserWithCustomHeadersRequest: APIRequestProtocol, Encodable {
    typealias Response = TestUser
    
    let name: String
    
    var endpoint: String { "/users" }
    var method: HTTPMethod { .POST }
    var headers: [String: String]? {
        [
            "Content-Type": "application/json",
            "X-Custom": "test"
        ]
    }
}

struct NilHeadersRequest: APIRequestProtocol {
    typealias Response = TestUser
    var endpoint: String { "/test" }
    var headers: [String: String]? { nil }
}

// MARK: - Body Testing

struct NilBodyRequest: APIRequestProtocol {
    typealias Response = TestUser
    var endpoint: String { "/test" }
    var body: Data? { nil }
}

struct FailingBodyRequest: APIRequestProtocol {
    typealias Response = TestUser
    
    var endpoint: String { "/test" }
    var method: HTTPMethod { .POST }
    
    var body: Data? {
        get throws {
            throw NSError(domain: "TestError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Body encoding failed"])
        }
    }
}

// MARK: - Edge Cases

struct EmptyEndpointRequest: APIRequestProtocol {
    typealias Response = TestUser
    var endpoint: String { "" }
}

struct EndpointWithoutSlashRequest: APIRequestProtocol {
    typealias Response = TestUser
    var endpoint: String { "users" }
}

struct SpecialCharactersRequest: APIRequestProtocol {
    typealias Response = TestUser
    var endpoint: String { "/user name/test@email.com" }
}

struct VeryLongEndpointRequest: APIRequestProtocol {
    typealias Response = TestUser
    var endpoint: String { "/very/long/endpoint/path/with/many/segments/that/could/potentially/cause/issues" }
}
