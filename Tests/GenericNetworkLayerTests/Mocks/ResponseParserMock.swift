//
//  ResponseParserMock.swift
//  GenericNetworkLayer
//
//  Created by Иван Дроботов on 8/29/25.
//

import Foundation
@testable import GenericNetworkLayer

final class ResponseParserMock: ResponseParserProtocol, @unchecked Sendable {
    
    private let queue = DispatchQueue(label: "com.test.ResponseParserMock")
    
    // MARK: - Configuration
    
    /// The result to return when parse is called
    var resultToReturn: Any?
    
    /// The error to return when parse is called
    var errorToReturn: ResponseParserError?
    
    // MARK: - Tracking
    
    private(set) var parseCallCount = 0
    private(set) var lastRequest: Any?
    private(set) var lastData: Data?
    
    // MARK: - ResponseParserProtocol
    
    func parse<R: APIRequestProtocol>(_ request: R, data: Data) -> Result<R.Response, ResponseParserError> {
        return queue.sync {
            parseCallCount += 1
            lastRequest = request
            lastData = data
            
            if let error = errorToReturn {
                return .failure(error)
            }
            
            if let result = resultToReturn as? R.Response {
                return .success(result)
            }
            
            // Default fallback for EmptyResponse
            if R.Response.self == EmptyResponse.self {
                return .success(EmptyResponse() as! R.Response)
            }
            
            // Default fallback error
            return .failure(.noData)
        }
    }
    
    // MARK: - Helper Methods
    
    func reset() {
        queue.sync {
            resultToReturn = nil
            errorToReturn = nil
            parseCallCount = 0
            lastRequest = nil
            lastData = nil
        }
    }
    
    func setSuccessResult<T>(_ result: T) {
        queue.sync {
            resultToReturn = result
            errorToReturn = nil
        }
    }
    
    func setFailureError(_ error: ResponseParserError) {
        queue.sync {
            resultToReturn = nil
            errorToReturn = error
        }
    }
    
    var currentParseCallCount: Int {
        queue.sync { parseCallCount }
    }
    
    var currentLastData: Data? {
        queue.sync { lastData }
    }
}
