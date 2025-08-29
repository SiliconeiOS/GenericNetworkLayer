//
//  File.swift
//  GenericNetworkLayer
//
//  Created by Иван Дроботов on 8/28/25.
//

import Foundation
import Testing

final class URLProtocolMock: URLProtocol {
    private static let requestHandlerKey = "com.mock.requestHandler"
    private static let nonHTTPRequestHandlerKey = "com.mock.nonHTTPRequestHandler"
    
    typealias RequestHandler = (URLRequest) throws -> (HTTPURLResponse, Data?)
    typealias NonHTTPRequestHandler = (URLRequest) throws -> (URLResponse, Data?)
    
    override class func canInit(with request: URLRequest) -> Bool {
        return URLProtocol.property(forKey: requestHandlerKey, in: request) != nil
        || URLProtocol.property(forKey: nonHTTPRequestHandlerKey, in: request) != nil
    }
    
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }
    
    override func startLoading() {
        if let nonHTTPHandler = URLProtocol.property(forKey: Self.nonHTTPRequestHandlerKey, in: request) as? NonHTTPRequestHandler {
            do {
                let (response, data) = try nonHTTPHandler(request)
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                if let data = data {
                    client?.urlProtocol(self, didLoad: data)
                }
                client?.urlProtocolDidFinishLoading(self)
            } catch {
                client?.urlProtocol(self, didFailWithError: error)
            }
            return
        }
        
        guard let handler = URLProtocol.property(forKey: Self.requestHandlerKey, in: request) as? RequestHandler else {
            #expect(Bool(false), "Can't find request handler")
            return
        }
        
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            if let data {
                client?.urlProtocol(self, didLoad: data)
            }
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }
    
    override func stopLoading() { }
    
    static func mock(_ request: URLRequest, with handler: @escaping RequestHandler) -> URLRequest {
        guard let nsRequest = (request as NSURLRequest).mutableCopy() as? NSMutableURLRequest else {
            #expect(Bool(false), "Can't convert URLRequest to NSMutableURLRequest")
            return request
        }
        URLProtocol.setProperty(handler, forKey: requestHandlerKey, in: nsRequest)
        return nsRequest as URLRequest
    }
    
    static func mockNonHTTP(_ request: URLRequest, with handler: @escaping NonHTTPRequestHandler) -> URLRequest {
        guard let nsRequest = (request as NSURLRequest).mutableCopy() as? NSMutableURLRequest else {
            #expect(Bool(false), "Can't convert URLRequest to NSMutableURLRequest")
            return request
        }
        URLProtocol.setProperty(handler, forKey: nonHTTPRequestHandlerKey, in: nsRequest)
        return nsRequest as URLRequest
    }
}
