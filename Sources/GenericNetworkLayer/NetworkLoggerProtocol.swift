//
//  File.swift
//  GenericNetworkLayer
//
//

import Foundation
import os.log

public protocol NetworkLoggerProtocol: Sendable {
    func log(request: URLRequest)
    func log(response: URLResponse?, data: Data?, error: Error?, for request: URLRequest)
}

public final class DefaultNetworkLogger: NetworkLoggerProtocol {
    
    private let logger = Logger(subsystem: "com.net.GenericNetworkLayer", category: "Networking")
    
    private static var isLoggingEnabled: Bool {
        #if DEBUG
        return NSClassFromString("XCTestCase") == nil
        #else
        return false
        #endif
    }
    
    public func log(request: URLRequest) {
        guard DefaultNetworkLogger.isLoggingEnabled else { return }
        
        let urlString = request.url?.absoluteString ?? "N/A"
        let method = request.httpMethod ?? "N/A"
        let headers = request.allHTTPHeaderFields ?? [:]
        
        var bodyString: String = "None"
        if let bodyData = request.httpBody, !bodyData.isEmpty {
            bodyString = String(data: bodyData, encoding: .utf8) ?? "(\(bodyData.count) bytes of non-UTF8 data)"
        }
        
        let curl = request.curlString
        logger.debug("""
            
            --- [Request] --->
            URL: \(urlString, privacy: .public)
            Method: \(method, privacy: .public)
            Headers: \(headers.description, privacy: .private)
            Body: \(bodyString, privacy: .private)
            cURL: \(curl, privacy: .private)
            -------------------->
            """)
    }
    
    public func log(response: URLResponse?, data: Data?, error: Error?, for request: URLRequest) {
        guard DefaultNetworkLogger.isLoggingEnabled else { return }
        
        let requestURL = request.url?.absoluteString ?? "N/A"
        
        if let error {
            logger.error("""
                
                <--- [Response] ---
                Request URL: \(requestURL, privacy: .public)
                Error: \(error.localizedDescription, privacy: .public)
                <--------------------
                """)
            return
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            logger.warning("""
                
                <--- [Response] ---
                Request URL: \(requestURL, privacy: .public)
                Warning: Received a non-HTTP response.
                <--------------------
                """)
            return
        }
        
        let statusCode = httpResponse.statusCode
        let headers = httpResponse.allHeaderFields as? [String: Any] ?? [:]
        
        var bodyString: String = "None"
        if let responseData = data, !responseData.isEmpty {
            bodyString = String(data: responseData, encoding: .utf8) ?? "(\(responseData.count) bytes of non-UTF8 data)"
        }
        
        logger.debug("""
            
            <--- [Response] ---
            Request URL: \(requestURL, privacy: .public)
            Status Code: \(statusCode)
            Headers: \(headers.description, privacy: .private)
            Body: \(bodyString, privacy: .private)
            <--------------------
            """)
    }
}

private extension URLRequest {
    var curlString: String {
        guard let url = url else { return "[cURL] Invalid URL" }
        
        var baseCommand = "curl '\(url.absoluteString)'"
        
        if let httpMethod = httpMethod, httpMethod != "GET" {
            baseCommand += " -X \(httpMethod)"
        }
        
        allHTTPHeaderFields?.forEach { header in
            let escapedValue = header.value.replacingOccurrences(of: "'", with: "'\\''")
            baseCommand += " -H '\(header.key): \(escapedValue)'"
        }
        
        if let httpBody = httpBody, let bodyString = String(data: httpBody, encoding: .utf8) {
            let escapedBody = bodyString.replacingOccurrences(of: "'", with: "'\\''")
            baseCommand += " -d '\(escapedBody)'"
        }
        
        return baseCommand
    }
}
