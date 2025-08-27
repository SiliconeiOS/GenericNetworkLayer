//
//  File.swift
//  GenericNetworkLayer
//
//  Created by Иван Дроботов on 8/27/25.
//

import Foundation
@testable import GenericNetworkLayer

final class TokenProviderMock: TokenProviderProtocol {
    private let token: String?
    
    init(token: String?) {
        self.token = token
    }
    
    func getAccessToken() -> String? {
        token
    }
}
