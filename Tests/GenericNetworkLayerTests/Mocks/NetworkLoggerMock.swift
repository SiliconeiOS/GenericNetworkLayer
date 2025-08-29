//
//  File.swift
//  GenericNetworkLayer
//
//  Created by Иван Дроботов on 8/28/25.
//

import Foundation
@testable import GenericNetworkLayer

final class NetworkLoggerMock: NetworkLoggerProtocol, @unchecked Sendable {
    
    private let lock = NSLock()

    private var _didLogRequest = false
    private var _didLogResponse = false
    
    private var _lastLoggedRequest: URLRequest?
    private var _lastLoggedResponse: URLResponse?
    private var _lastLoggedData: Data?
    private var _lastLoggedError: Error?

    var didLogRequest: Bool {
        lock.withLock { _didLogRequest }
    }
    
    var didLogResponse: Bool {
        lock.withLock { _didLogResponse }
    }
    
    var lastLoggedRequest: URLRequest? {
        lock.withLock { _lastLoggedRequest }
    }
    
    var lastLoggedResponse: URLResponse? {
        lock.withLock { _lastLoggedResponse }
    }
    
    var lastLoggedData: Data? {
        lock.withLock { _lastLoggedData }
    }
    
    var lastLoggedError: Error? {
        lock.withLock { _lastLoggedError }
    }
    
    //MARK: - NetworkLoggerProtocol Implementation
    
    func log(request: URLRequest) {
        lock.withLock {
            _didLogRequest = true
            _lastLoggedRequest = request
        }
    }

    func log(response: URLResponse?, data: Data?, error: Error?, for request: URLRequest) {
        lock.withLock {
            _didLogResponse = response != nil
            _lastLoggedResponse = response
            _lastLoggedData = data
            _lastLoggedError = error
        }
    }
}
