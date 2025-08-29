//
//  File.swift
//  GenericNetworkLayer
//
//

import Foundation

/// Network-level errors that can occur during HTTP requests.
///
/// These errors represent various failure modes at the network layer,
/// including connectivity issues, invalid responses, and HTTP status code errors.
public enum NetworkError: LocalizedError, Sendable {
    /// The server response is not a valid HTTP response
    case invalidResponse
    
    /// HTTP 401 Unauthorized response
    case unauthorized(Data?)
    
    /// The underlying network request failed (connectivity, timeout, etc.)
    case requestFailed(AnySendableError)
    
    /// HTTP response with unexpected status code
    case unexpectedStatusCode(statusCode: Int, body: Data?)
    
    /// All retry attempts have been exhausted
    indirect case allRetriesFailed(lastError: NetworkError, totalAttempts: Int)
    
    public var errorDescription: String? {
        switch self {
        case .requestFailed(let error):
            return "Request failed: \(error.localizedDescription)"
        case .invalidResponse:
            return "Received an invalid response from the server."
        case .unauthorized:
            return "Unauthorized. Please check your API key."
        case .unexpectedStatusCode(let code, let body):
            return "Server returned an unexpected status code: \(code). \(bodyDescription(from: body))"
        case .allRetriesFailed(let lastError, let totalAttempts):
            return "All \(totalAttempts) retry attempts failed. Last error: \(lastError.localizedDescription)"
        }
    }
    
    private func bodyDescription(from data: Data?) -> String {
        guard let data = data, !data.isEmpty else {
            return ""
        }
        
        guard let bodyString = String(data: data, encoding: .utf8) else {
            return " Body: (\(data.count) non-UTF8 bytes)"
        }
        
        return " Body: \"\(bodyString)\""
    }
}

extension NetworkError {
    /// A fallback error to be used in the retry mechanism when all attempts fail
    /// but no specific last error was captured. This scenario is highly unlikely.
    static var allRetriesFailedFallback: NetworkError {
        let errorInfo = [
            NSLocalizedDescriptionKey: "All retry attempts failed, but no specific error was captured."
        ]
        
        let nsError = NSError(
            domain: "com.yourcompany.GenericNetworkLayer.RetryingError",
            code: -1,
            userInfo: errorInfo
        )
        
        return .requestFailed(AnySendableError(nsError))
    }
}
