//
//  File.swift
//  GenericNetworkLayer
//
//

import Foundation

/// Errors that can occur during response parsing.
///
/// These errors represent failures in converting raw response data
/// into the expected response type.
public enum ResponseParserError: LocalizedError, Sendable {
    /// No data received for a response type that requires data
    case noData
    
    /// Failed to decode the response data into the expected type
    case decodingError(AnySendableError)
    
    public var errorDescription: String? {
        switch self {
        case .noData:
            return "Data for non EmptyResponse is empty"
        case .decodingError(let error):
            return "Failed to decode data \(error.localizedDescription)"
        }
    }
}
