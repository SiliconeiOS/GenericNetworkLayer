//
//  File.swift
//  GenericNetworkLayer
//
//

import Foundation

/// Errors that can occur during URLRequest construction.
///
/// These errors represent failures in building a valid URLRequest
/// from an API request object.
public enum RequestBuilderError: LocalizedError, Sendable  {
    /// The provided base URL string is malformed
    case invalidBaseURL(String)
    
    /// Failed to create URLComponents from the constructed URL
    case componentsCreationFailed(URL)
    
    /// Failed to create the final URL from URLComponents
    case finalURLCreationFailed(URLComponents)
    
    /// Failed to encode the request body
    case bodyEncodingFailed(AnySendableError)
    
    /// Failed to find token
    case tokenProviderMissingOrTokenNil
    
    public var errorDescription: String? {
        switch self {
        case .invalidBaseURL(let urlString):
            return "The provided base URL string is invalid: \(urlString) "
        case .componentsCreationFailed(let url):
            return "Failed to create URLComponents from a valid URL: \(url.absoluteString). This is unexpected."
        case .finalURLCreationFailed(let components):
            return "Failed to construct the final URL from URLComponents. Components: \(components)."
        case .bodyEncodingFailed(let error):
            return "Failed to encode the request body. Underlying error: \(error.localizedDescription)"
        case .tokenProviderMissingOrTokenNil:
            return "The request requires authorization, but the TokenProvider was not provided or it returned a nil token."
        }
    }
}
