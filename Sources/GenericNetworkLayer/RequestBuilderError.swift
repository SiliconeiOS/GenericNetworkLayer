//
//  File.swift
//  GenericNetworkLayer
//
//

import Foundation

public enum RequestBuilderError: LocalizedError, Sendable  {
    case invalidBaseURL(String)
    case componentsCreationFailed(URL)
    case finalURLCreationFailed(URLComponents)
    case bodyEncodingFailed(AnySendableError)
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
