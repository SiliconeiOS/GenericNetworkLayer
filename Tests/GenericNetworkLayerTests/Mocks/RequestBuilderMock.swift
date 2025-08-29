//
//  RequestBuilderMock.swift
//  GenericNetworkLayer
//
//  Created by Иван Дроботов on 8/29/25.
//

import Foundation
@testable import GenericNetworkLayer

final class RequestBuilderMock: RequestBuilderProtocol, @unchecked Sendable {
    
    private let queue = DispatchQueue(label: "com.test.RequestBuilderMock")
    
    // MARK: - Configuration
    
    /// The URLRequest to return when buildRequest is called
    var urlRequestToReturn: URLRequest?
    
    /// The error to throw when buildRequest is called
    var errorToThrow: Error?
    
    // MARK: - Tracking
    
    private(set) var buildRequestCallCount = 0
    private(set) var lastAPIRequest: Any?
    private(set) var lastBaseURL: String?
    private(set) var lastTokenProvider: TokenProviderProtocol?
    
    // MARK: - RequestBuilderProtocol
    
    func buildRequest<R: APIRequestProtocol>(
        from apiRequest: R,
        baseURL: String,
        tokenProvider: TokenProviderProtocol?
    ) throws -> URLRequest {
        return try queue.sync {
            buildRequestCallCount += 1
            lastAPIRequest = apiRequest
            lastBaseURL = baseURL
            lastTokenProvider = tokenProvider
            
            if let error = errorToThrow {
                throw error
            }
            
            return urlRequestToReturn ?? URLRequest(url: URL(string: "https://mock.test")!)
        }
    }
    
    // MARK: - Helper Methods
    
    func reset() {
        queue.sync {
            urlRequestToReturn = nil
            errorToThrow = nil
            buildRequestCallCount = 0
            lastAPIRequest = nil
            lastBaseURL = nil
            lastTokenProvider = nil
        }
    }
    
    var currentBuildRequestCallCount: Int {
        queue.sync { buildRequestCallCount }
    }
    
    var currentLastBaseURL: String? {
        queue.sync { lastBaseURL }
    }
}
