//
//  File.swift
//  GenericNetworkLayer
//
//

import Foundation

public protocol ResponseParserProtocol: Sendable {
    func parse<R: APIRequestProtocol>(_ request: R, data: Data) -> Result<R.Response, ResponseParserError>
}

public final class ResponseParser: ResponseParserProtocol {
    
    private let decoder: JSONDecoder
    
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
