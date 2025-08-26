//
//  File.swift
//  GenericNetworkLayer
//
//

import Foundation

/// Errors that can occur during API client operations.
///
/// This error type wraps different categories of errors that can happen
/// during the request lifecycle, from building the request to parsing the response.
public enum APIClientError: LocalizedError, Sendable {
    /// Network-level error (connectivity, HTTP status codes, etc.)
    case networkError(NetworkError)
    
    /// Error building the URLRequest from APIRequestProtocol
    case requestBuilderError(RequestBuilderError)
    
    /// Error parsing the response data
    case responseParseError(ResponseParserError)
    
    /// Unexpected error that doesn't fit other categories
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
