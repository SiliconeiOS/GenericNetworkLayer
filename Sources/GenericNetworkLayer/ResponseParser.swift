//
//  File.swift
//  GenericNetworkLayer
//
//

import Foundation

/// A protocol for parsing HTTP response data into typed objects.
///
/// Implementations of this protocol handle the conversion from raw response data
/// to the expected response type defined by the API request.
public protocol ResponseParserProtocol: Sendable {
    /// Parses response data into the expected response type.
    ///
    /// - Parameters:
    ///   - request: The original API request (used for type information)
    ///   - data: The raw response data from the server
    /// - Returns: A Result containing either the parsed response or a parsing error
    func parse<R: APIRequestProtocol>(_ request: R, data: Data) -> Result<R.Response, ResponseParserError>
}

/// Default implementation of ResponseParserProtocol using JSONDecoder.
///
/// This parser handles JSON responses and includes special handling for empty responses
/// (when the expected response type is `EmptyResponse`).
public final class ResponseParser: ResponseParserProtocol {
    
    private let decoder: JSONDecoder
    
    /// Creates a ResponseParser with the specified JSONDecoder.
    ///
    /// - Parameter decoder: The JSONDecoder to use for parsing responses
    public init(decoder: JSONDecoder = JSONDecoder()) {
        self.decoder = decoder
    }
    
    public func parse<R: APIRequestProtocol>(_ request: R, data: Data) -> Result<R.Response, ResponseParserError> {
        guard !data.isEmpty else {
            return .failure(.noData)
        }
        
        do {
            let decodedResponse = try decoder.decode(R.Response.self, from: data)
            return .success(decodedResponse)
        } catch {
            return .failure(.decodingError(AnySendableError(error)))
        }
    }
    
    public func parse<R: APIRequestProtocol>(
        _ request: R,
        data: Data
    ) -> Result<R.Response, ResponseParserError> where R.Response == EmptyResponse {
        .success(EmptyResponse())
    }
}
