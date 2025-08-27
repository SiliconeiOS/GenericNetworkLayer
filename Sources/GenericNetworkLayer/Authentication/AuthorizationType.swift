//
//  File.swift
//  GenericNetworkLayer
//
//  Created by Иван Дроботов on 8/26/25.
//

import Foundation

/// Types of authentication supported by the network layer.
///
/// This enum defines different authentication methods that can be applied
/// to API requests. The request builder uses this information to determine
/// how to handle authentication headers.
public enum AuthorizationType: Sendable {
    /// No authentication required for this request
    case none
    
    /// Use Bearer token authentication (Authorization: Bearer <token>)
    case bearerToken
}
