//
//  File.swift
//  GenericNetworkLayer
//
//

import Foundation

/// A protocol for objects that can be cancelled.
///
/// This protocol provides a common interface for cancelling operations,
/// allowing the network layer to work with different types of cancellable
/// operations in a uniform way.
public protocol Cancellable { 
    /// Cancels the operation.
    func cancel() 
}

/// URLSessionDataTask conforms to Cancellable for seamless integration.
extension URLSessionDataTask: Cancellable {}
