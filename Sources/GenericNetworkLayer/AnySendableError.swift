//
//  File.swift
//  GenericNetworkLayer
//
//

import Foundation

public struct AnySendableError: Error, Sendable {
    public let localizedDescription: String
    public let code: Int
    public let domain: String
    
    public init(_ error: Error) {
        let nsError = error as NSError
        self.localizedDescription = error.localizedDescription
        self.code = nsError.code
        self.domain = nsError.domain
    }
}
