//
//  File.swift
//  GenericNetworkLayer
//
//  Created by Иван Дроботов on 8/27/25.
//

import Foundation
import Testing
@testable import GenericNetworkLayer

@Suite("RequestBuilder Tests")
struct RequestBuilderTests {
    
    private let requestBuilder = RequestBuilder()
    private let baseURL = "https://api.test.com"
    
    //MARK: - Standard Requests Tests
    
    @Test("Correctly builds a simple GET request")
    func testBuildGetRequest() throws {
        // Given
        let getRequest = GetUserRequest(userID: 123)
        
        // When
        let urlRequest = try requestBuilder.buildRequest(from: getRequest, baseURL: baseURL)
        
        // Then
        #expect(urlRequest.url?.absoluteString == "https://api.test.com/users/123")
        #expect(urlRequest.httpMethod == HTTPMethod.GET.rawValue)
        #expect(urlRequest.httpBody == nil)
    }
    
    
    @Test("Correctly builds a POST request with JSON body")
    func testBuildPostRequest() throws {
        // Given
        let postRequest = CreateUserRequest(name: "John Dow")
        
        // When
        let urlRequest = try requestBuilder.buildRequest(from: postRequest, baseURL: baseURL)
        
        // Then
        #expect(urlRequest.url?.absoluteString == "\(baseURL)/users")
        #expect(urlRequest.httpMethod == HTTPMethod.POST.rawValue)
        #expect(urlRequest.value(forHTTPHeaderField: "Content-Type") == "application/json")
        
        let bodyData = try #require(urlRequest.httpBody)
        let bodyJson = try #require(JSONSerialization.jsonObject(with: bodyData) as? [String: String])
        #expect(bodyJson == ["name": "John Dow"])
    }
    
    @Test("Correctly builds a PUT request")
    func testBuildPutRequest() throws {
        // Given
        let request = UpdateUserRequest(userID: 456, name: "Updated Name")
        
        // When
        let urlRequest = try requestBuilder.buildRequest(from: request, baseURL: baseURL)
        
        // Then
        #expect(urlRequest.url?.absoluteString == "\(baseURL)/users/456")
        #expect(urlRequest.httpMethod == HTTPMethod.PUT.rawValue)
        #expect(urlRequest.value(forHTTPHeaderField: "Content-Type") == "application/json")
        
        let bodyData = try #require(urlRequest.httpBody)
        let bodyJson = try #require(JSONSerialization.jsonObject(with: bodyData) as? [String: Any])
        #expect(bodyJson["userID"] as? Int == 456)
        #expect(bodyJson["name"] as? String == "Updated Name")
    }
    
    @Test("Correctly builds a DELETE request")
    func testBuildDeleteRequest() throws {
        // Given
        let deleteRequest = DeleteRequest()
        
        // When
        let urlRequest = try requestBuilder.buildRequest(from: deleteRequest, baseURL: baseURL)
        
        // Then
        #expect(urlRequest.url?.absoluteString == "\(baseURL)/user/1")
        #expect(urlRequest.httpMethod == HTTPMethod.DELETE.rawValue)
    }
    
    
    @Test("Correctly authenticated requests with Bearer token")
    func testBuildAuthenticatedRequest() throws {
        // Given
        let tokenProvider = TokenProviderMock(token: "secret-token")
        let authRequest = AuthenticatedRequest()
        
        // When
        let urlRequest = try requestBuilder.buildRequest(from: authRequest, baseURL: baseURL, tokenProvider: tokenProvider)
        
        // Then
        #expect(urlRequest.value(forHTTPHeaderField: "Authorization") == "Bearer secret-token")
    }
    
    // MARK: - Query Parameters Tests
    
    @Test("Correctly builds request with query parameters")
    func testBuildRequestWithQueryParameters() throws {
        // Given
        let request = GetUserWithParamsRequest(userID: 123, limit: 10, offset: 20)
        
        // When
        let urlRequest = try requestBuilder.buildRequest(from: request, baseURL: baseURL)
        
        // Then
        let urlComponents = try #require(URLComponents(url: urlRequest.url!, resolvingAgainstBaseURL: false))
        let queryItems = try #require(urlComponents.queryItems)
        
        #expect(queryItems.contains(URLQueryItem(name: "limit", value: "10")))
        #expect(queryItems.contains(URLQueryItem(name: "offset", value: "20")))
        #expect(urlRequest.httpMethod == HTTPMethod.GET.rawValue)
        #expect(urlComponents.path == "/users/123")
    }
    
    @Test("Correctly builds request with special characters in query parameters")
    func testBuildRequestWithSpecialCharactersInQueryParams() throws {
        // Given
        let request = SearchRequest(query: "test query", filter: "name@domain.com")
        
        // When
        let urlRequest = try requestBuilder.buildRequest(from: request, baseURL: baseURL)
        
        // Then
        let urlComponents = try #require(URLComponents(url: urlRequest.url!, resolvingAgainstBaseURL: false))
        let queryItems = try #require(urlComponents.queryItems)
        
        #expect(queryItems.contains(URLQueryItem(name: "query", value: "test query")))
        #expect(queryItems.contains(URLQueryItem(name: "filter", value: "name@domain.com")))
    }
    
    @Test("Correctly builds request with empty query parameters")
    func testBuildRequestWithEmptyQueryParameters() throws {
        // Given
        let request = EmptyQueryRequest()
        
        // When
        let urlRequest = try requestBuilder.buildRequest(from: request, baseURL: baseURL)
        
        // Then
        let urlComponents = try #require(URLComponents(url: urlRequest.url!, resolvingAgainstBaseURL: false))
        #expect(urlComponents.queryItems == nil)
    }
    
    // MARK: - Headers Tests
    
    @Test("Correctly builds request with custom headers")
    func testBuildRequestWithCustomHeaders() throws {
        // Given
        let request = RequestWithCustomHeaders()
        
        // When
        let urlRequest = try requestBuilder.buildRequest(from: request, baseURL: baseURL)
        
        // Then
        #expect(urlRequest.value(forHTTPHeaderField: "X-Custom-Header") == "custom-value")
        #expect(urlRequest.value(forHTTPHeaderField: "Accept") == "application/json")
    }
    
    @Test("Correctly merges headers for Encodable requests")
    func testBuildEncodableRequestHeaders() throws {
        // Given
        let request = CreateUserWithCustomHeadersRequest(name: "John")
        
        // When
        let urlRequest = try requestBuilder.buildRequest(from: request, baseURL: baseURL)
        
        // Then
        #expect(urlRequest.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(urlRequest.value(forHTTPHeaderField: "X-Custom") == "test")
    }
    
    // MARK: - Error Cases Tests
    
    @Test("Throws invalidBaseURL error for malformed base URL")
    func testInvalidBaseURLError() throws {
        // Given
        let request = GetUserRequest(userID: 123)
        let invalidBaseURL = "https://my api test.com"
        
        do {
            // When
            _ = try requestBuilder.buildRequest(from: request, baseURL: invalidBaseURL)
            #expect(Bool(false), "Should throw an error")
            
            // Then
        } catch let error as RequestBuilderError {
            guard case .invalidBaseURL(let url) = error else {
                #expect(Bool(false), "Should throw invalidBaseURL error")
                return
            }
            #expect(url == invalidBaseURL)
        }
    }
    
    @Test("Throws tokenProviderMissingOrTokenNil when token provider is nil for authenticated request")
    func testMissingTokenProviderError() throws {
        // Given
        let request = AuthenticatedRequest()
        
        do {
            // When
            _ = try requestBuilder.buildRequest(from: request, baseURL: baseURL)
            #expect(Bool(false), "Should throw an error")
            
            // Then
        } catch let error as RequestBuilderError {
            guard case .tokenProviderMissingOrTokenNil = error else {
                #expect(Bool(false), "Should throw tokenProviderMissingOrTokenNil error")
                return
            }
        }
    }
    
    @Test("Throws tokenProviderMissingOrTokenNil when token provider returns nil")
    func testNilTokenError() throws {
        // Given
        let request = AuthenticatedRequest()
        let nilTokenProvider = TokenProviderMock(token: nil)
        
        do {
            // When
            _ = try requestBuilder.buildRequest(from: request, baseURL: baseURL, tokenProvider: nilTokenProvider)
            #expect(Bool(false), "Should throw an error")
            
            // Then
        } catch let error as RequestBuilderError {
            guard case .tokenProviderMissingOrTokenNil = error else {
                #expect(Bool(false), "Should throw tokenProviderMissingOrTokenNil error")
                return
            }
        }
    }
    
    @Test("Throws bodyEncodingFailed error when request body encoding fails")
    func testBodyEncodingFailedError() throws {
        // Given
        let request = FailingBodyRequest()
        
        do {
            // When
            _ = try requestBuilder.buildRequest(from: request, baseURL: baseURL)
            #expect(Bool(false), "Should throw an error")
            
            // Then
        } catch let error as RequestBuilderError {
            guard case .bodyEncodingFailed = error else {
                #expect(Bool(false), "Should throw bodyEncodingFailed error")
                return
            }
        }
    }
    
    // MARK: - Edge Cases Tests
    
    @Test("Correctly builds request with empty endpoint")
    func testEmptyEndpoint() throws {
        // Given
        let request = EmptyEndpointRequest()
        
        // When
        let urlRequest = try requestBuilder.buildRequest(from: request, baseURL: baseURL)
        
        // Then
        #expect(urlRequest.url?.absoluteString == "\(baseURL)/")
    }
    
    @Test("Correctly builds request with special characters in endpoint")
    func testSpecialCharactersInEndpoint() throws {
        // Given
        let request = SpecialCharactersRequest()
        
        // When
        let urlRequest = try requestBuilder.buildRequest(from: request, baseURL: baseURL)
        
        // Then
        #expect(urlRequest.url?.absoluteString == "\(baseURL)/user%20name/test@email.com")
    }
    
    @Test("Correctly handles request with no authentication when not required")
    func testNoAuthenticationWhenNotRequired() throws {
        // Given
        let request = GetUserRequest(userID: 123)
        
        // When
        let urlRequest = try requestBuilder.buildRequest(from: request, baseURL: baseURL)
        
        // Then
        #expect(urlRequest.value(forHTTPHeaderField: "Authorization") == nil)
    }
    
    @Test("Correctly builds request with nil body")
    func testNilBody() throws {
        // Given
        let request = NilBodyRequest()
        
        // When
        let urlRequest = try requestBuilder.buildRequest(from: request, baseURL: baseURL)
        
        // Then
        #expect(urlRequest.httpBody == nil)
    }
    
    @Test("Correctly builds request with baseURL containing trailing slash")
    func testBaseURLWithTrailingSlash() throws {
        // Given
        let request = GetUserRequest(userID: 123)
        let baseURLWithSlash = "https://api.test.com/"
        
        // When
        let urlRequest = try requestBuilder.buildRequest(from: request, baseURL: baseURLWithSlash)
        
        // Then
        #expect(urlRequest.url?.absoluteString == "https://api.test.com/users/123")
    }
    
    @Test("Correctly builds request with endpoint without leading slash")
    func testEndpointWithoutLeadingSlash() throws {
        // Given
        let request = EndpointWithoutSlashRequest()
        
        // When
        let urlRequest = try requestBuilder.buildRequest(from: request, baseURL: baseURL)
        
        // Then
        #expect(urlRequest.url?.absoluteString == "\(baseURL)/users")
    }
    
    @Test("Correctly builds request with very long endpoint")
    func testVeryLongEndpoint() throws {
        // Given
        let request = VeryLongEndpointRequest()
        
        // When
        let urlRequest = try requestBuilder.buildRequest(from: request, baseURL: baseURL)
        
        // Then
        #expect(urlRequest.url != nil)
        #expect(urlRequest.url?.absoluteString.contains("/very/long/endpoint/path") == true)
    }
    
    @Test("Correctly builds request with nil headers when explicitly set")
    func testNilHeadersExplicitly() throws {
        // Given
        let request = NilHeadersRequest()
        
        // When
        let urlRequest = try requestBuilder.buildRequest(from: request, baseURL: baseURL)
        
        // Then
        #expect(urlRequest.allHTTPHeaderFields?.isEmpty == true)
    }
}
