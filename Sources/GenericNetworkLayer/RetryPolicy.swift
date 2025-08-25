//
//  File.swift
//  GenericNetworkLayer
//
//

import Foundation

public struct RetryPolicy: Sendable {
    
    public let maxRetries: Int
    public let initialDelay: TimeInterval
    public let backoffFactor: Double
    public let shouldRetry: @Sendable (NetworkError) -> Bool
    
    public init(
        maxRetries: Int = 3,
        initialDelay: TimeInterval = 1.0,
        backoffFactor: Double = 2.0,
        shouldRetry: @escaping @Sendable (NetworkError) -> Bool = RetryPolicy.defaultShouldRetry
    ) {
        self.maxRetries = maxRetries
        self.initialDelay = initialDelay
        self.backoffFactor = backoffFactor
        self.shouldRetry = shouldRetry
    }
    
    public static let defaultShouldRetry: @Sendable (NetworkError) -> Bool = { error in
        switch error {
        case .unexpectedStatusCode(let statusCode, _):
            return (500...599).contains(statusCode)
        case .requestFailed(let underlyingError):
            return [
                NSURLErrorTimedOut,
                NSURLErrorCannotFindHost,
                NSURLErrorCannotConnectToHost,
                NSURLErrorNetworkConnectionLost,
                NSURLErrorNotConnectedToInternet,
            ].contains(underlyingError.code)
        default:
            return false
        }
    }
}
