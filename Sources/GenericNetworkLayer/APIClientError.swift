//
//  File.swift
//  GenericNetworkLayer
//
//

import Foundation

public enum APIClientError: LocalizedError, Sendable {
    case networkError(NetworkError)
    case requestBuilderError(RequestBuilderError)
    case responseParseError(ResponseParserError)
    case unexpectedError(AnySendableError)
    
    public var errorDescription: String? {
        switch self {
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .requestBuilderError(let error):
            return "Request building error: \(error.localizedDescription)"
        case .responseParseError(let error):
            return "Response parsing error: \(error.localizedDescription)"
        case .unexpectedError(let error):
            return "Unexpected error: \(error.localizedDescription)"
        }
    }
}
