//
//  File.swift
//  GenericNetworkLayer
//
//

import Foundation

public enum ResponseParserError: LocalizedError, Sendable {
    case noData
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
