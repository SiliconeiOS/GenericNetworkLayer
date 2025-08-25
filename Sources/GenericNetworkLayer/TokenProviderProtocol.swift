//
//  File.swift
//  GenericNetworkLayer
//
//

import Foundation

public protocol TokenProviderProtocol: Sendable {
    func getAccessToken() -> String? 
}
