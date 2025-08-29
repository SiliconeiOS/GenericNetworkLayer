//
//  ResponseParserTests.swift
//  GenericNetworkLayer
//
//  Created by Иван Дроботов on 8/29/25.
//

import Foundation
import Testing
@testable import GenericNetworkLayer

@Suite("ResponseParser Tests")
struct ResponseParserTests {
    
    private let sut = ResponseParser()
    
    // MARK: - Success Cases
    
    @Test("Successfully parses valid JSON data for Codable type")
    func testParseValidJSONSuccess() throws {
        // Given
        let user = TestUser(id: 42, name: "John Doe")
        let jsonData = try JSONEncoder().encode(user)
        let request = TestGetUserRequest(userID: 42)
        
        // When
        let result = sut.parse(request, data: jsonData)
        
        // Then
        let parsedUser = try result.get()
        #expect(parsedUser.id == user.id)
        #expect(parsedUser.name == user.name)
    }
    
    @Test("Successfully parses EmptyResponse regardless of data content")
    func testParseEmptyResponseSuccess() {
        // Given
        let request = DeleteRequest()
        let anyData = "some content".data(using: .utf8)!
        
        // When
        let result = sut.parse(request, data: anyData)
        
        // Then
        let _ = try! result.get()
        // EmptyResponse successfully parsed
    }
    
    @Test("Successfully parses EmptyResponse with empty data")
    func testParseEmptyResponseWithEmptyData() {
        // Given
        let request = DeleteRequest()
        let emptyData = Data()
        
        // When
        let result = sut.parse(request, data: emptyData)
        
        // Then
        let _ = try! result.get()
        // EmptyResponse successfully parsed
    }
    
    @Test("Successfully parses complex nested JSON structure")
    func testParseComplexJSONSuccess() throws {
        // Given
        let complexData = """
        {
            "users": [
                {"id": 1, "name": "Alice"},
                {"id": 2, "name": "Bob"}
            ],
            "metadata": {
                "total": 2,
                "page": 1
            }
        }
        """.data(using: .utf8)!
        
        let request = TestGetUsersListRequest()
        
        // When
        let result = sut.parse(request, data: complexData)
        
        // Then
        let response = try result.get()
        #expect(response.users.count == 2)
        #expect(response.users[0].name == "Alice")
        #expect(response.users[1].name == "Bob")
        #expect(response.metadata.total == 2)
    }
    
    @Test("Successfully parses array of primitives")
    func testParseArrayOfPrimitivesSuccess() throws {
        // Given
        let numbersData = "[1, 2, 3, 4, 5]".data(using: .utf8)!
        let request = TestGetNumbersRequest()
        
        // When
        let result = sut.parse(request, data: numbersData)
        
        // Then
        let numbers = try result.get()
        #expect(numbers == [1, 2, 3, 4, 5])
    }
    
    @Test("Successfully parses single string value")
    func testParseSingleStringSuccess() throws {
        // Given
        let stringData = "\"Hello, World!\"".data(using: .utf8)!
        let request = TestGetStringRequest()
        
        // When
        let result = sut.parse(request, data: stringData)
        
        // Then
        let parsedString = try result.get()
        #expect(parsedString == "Hello, World!")
    }
    
    // MARK: - Failure Cases
    
    @Test("Returns noData error when data is empty for non-EmptyResponse type")
    func testParseEmptyDataFailure() {
        // Given
        let emptyData = Data()
        let request = TestGetUserRequest(userID: 42)
        
        // When
        let result = sut.parse(request, data: emptyData)
        
        // Then
        switch result {
        case .success:
            #expect(Bool(false), "Expected noData error")
        case .failure(let error):
            guard case .noData = error else {
                #expect(Bool(false), "Expected noData error, got \(error)")
                return
            }
        }
    }
    
    @Test("Returns decodingError for invalid JSON syntax")
    func testParseInvalidJSONSyntaxFailure() {
        // Given
        let invalidJSONData = "{invalid json}".data(using: .utf8)!
        let request = TestGetUserRequest(userID: 42)
        
        // When
        let result = sut.parse(request, data: invalidJSONData)
        
        // Then
        switch result {
        case .success:
            #expect(Bool(false), "Expected decodingError")
        case .failure(let error):
            guard case .decodingError = error else {
                #expect(Bool(false), "Expected decodingError, got \(error)")
                return
            }
        }
    }
    
    @Test("Returns decodingError for mismatched JSON structure")
    func testParseMismatchedStructureFailure() {
        // Given
        let mismatchedData = """
        {
            "wrongField": "value",
            "anotherWrongField": 123
        }
        """.data(using: .utf8)!
        let request = TestGetUserRequest(userID: 42)
        
        // When
        let result = sut.parse(request, data: mismatchedData)
        
        // Then
        switch result {
        case .success:
            #expect(Bool(false), "Expected decodingError")
        case .failure(let error):
            guard case .decodingError = error else {
                #expect(Bool(false), "Expected decodingError, got \(error)")
                return
            }
        }
    }
    
    @Test("Returns decodingError for wrong data type")
    func testParseWrongDataTypeFailure() {
        // Given
        let wrongTypeData = """
        {
            "id": "not_a_number",
            "name": "John Doe"
        }
        """.data(using: .utf8)!
        let request = TestGetUserRequest(userID: 42)
        
        // When
        let result = sut.parse(request, data: wrongTypeData)
        
        // Then
        switch result {
        case .success:
            #expect(Bool(false), "Expected decodingError")
        case .failure(let error):
            guard case .decodingError = error else {
                #expect(Bool(false), "Expected decodingError, got \(error)")
                return
            }
        }
    }
    
    @Test("Returns decodingError for missing required fields")
    func testParseMissingFieldsFailure() {
        // Given
        let incompleteData = """
        {
            "id": 42
        }
        """.data(using: .utf8)!
        let request = TestGetUserRequest(userID: 42)
        
        // When
        let result = sut.parse(request, data: incompleteData)
        
        // Then
        switch result {
        case .success:
            #expect(Bool(false), "Expected decodingError")
        case .failure(let error):
            guard case .decodingError = error else {
                #expect(Bool(false), "Expected decodingError, got \(error)")
                return
            }
        }
    }
    
    @Test("Returns decodingError for non-UTF8 data")
    func testParseNonUTF8DataFailure() {
        // Given
        let nonUTF8Data = Data([0xFF, 0xFE]) // Invalid UTF-8 sequence
        let request = TestGetUserRequest(userID: 42)
        
        // When
        let result = sut.parse(request, data: nonUTF8Data)
        
        // Then
        switch result {
        case .success:
            #expect(Bool(false), "Expected decodingError")
        case .failure(let error):
            guard case .decodingError = error else {
                #expect(Bool(false), "Expected decodingError, got \(error)")
                return
            }
        }
    }
    
    // MARK: - Custom Decoder Tests
    
    @Test("Uses custom JSONDecoder configuration")
    func testCustomDecoderConfiguration() throws {
        // Given
        let customDecoder = JSONDecoder()
        customDecoder.dateDecodingStrategy = .iso8601
        let parser = ResponseParser(decoder: customDecoder)
        
        let dateData = """
        {
            "id": 1,
            "createdAt": "2023-08-29T12:00:00Z"
        }
        """.data(using: .utf8)!
        
        let request = TestGetUserWithDateRequest()
        
        // When
        let result = parser.parse(request, data: dateData)
        
        // Then
        let user = try result.get()
        #expect(user.id == 1)
        // Date was successfully parsed
    }
    
    @Test("Uses custom JSONDecoder with snake_case conversion")
    func testCustomDecoderSnakeCase() throws {
        // Given
        let customDecoder = JSONDecoder()
        customDecoder.keyDecodingStrategy = .convertFromSnakeCase
        let parser = ResponseParser(decoder: customDecoder)
        
        let snakeCaseData = """
        {
            "user_id": 42,
            "full_name": "John Doe"
        }
        """.data(using: .utf8)!
        
        let request = TestGetUserSnakeCaseRequest()
        
        // When
        let result = parser.parse(request, data: snakeCaseData)
        
        // Then
        let user = try result.get()
        #expect(user.userId == 42)
        #expect(user.fullName == "John Doe")
    }
    
    // MARK: - Edge Cases
    
    @Test("Handles very large JSON data")
    func testParseLargeJSONData() throws {
        // Given
        var largeUserArray: [TestUser] = []
        for i in 0..<1000 {
            largeUserArray.append(TestUser(id: i, name: "User \(i)"))
        }
        
        let largeData = try JSONEncoder().encode(largeUserArray)
        let request = TestGetLargeUserArrayRequest()
        
        // When
        let result = sut.parse(request, data: largeData)
        
        // Then
        let users = try result.get()
        #expect(users.count == 1000)
        #expect(users.first?.name == "User 0")
        #expect(users.last?.name == "User 999")
    }
    
    @Test("Handles JSON with null values")
    func testParseJSONWithNullValues() throws {
        // Given
        let nullableData = """
        {
            "id": 42,
            "name": null,
            "email": "test@example.com"
        }
        """.data(using: .utf8)!
        
        let request = TestGetNullableUserRequest()
        
        // When
        let result = sut.parse(request, data: nullableData)
        
        // Then
        let user = try result.get()
        #expect(user.id == 42)
        #expect(user.name == nil)
        #expect(user.email == "test@example.com")
    }
    
    @Test("Handles deeply nested JSON structure")
    func testParseDeeplyNestedJSON() throws {
        // Given
        let nestedData = """
        {
            "level1": {
                "level2": {
                    "level3": {
                        "level4": {
                            "value": "deeply nested"
                        }
                    }
                }
            }
        }
        """.data(using: .utf8)!
        
        let request = TestGetNestedStructureRequest()
        
        // When
        let result = sut.parse(request, data: nestedData)
        
        // Then
        let nested = try result.get()
        #expect(nested.level1.level2.level3.level4.value == "deeply nested")
    }
    
    @Test("Handles JSON with special characters and unicode")
    func testParseJSONWithSpecialCharacters() throws {
        // Given
        let specialData = """
        {
            "id": 1,
            "name": "John \\"Doe\\" 🚀",
            "description": "Some description",
            "unicode": "Héllo Wörld! 你好世界"
        }
        """.data(using: .utf8)!
        
        let request = TestGetSpecialCharUserRequest()
        
        // When
        let result = sut.parse(request, data: specialData)
        
        // Then
        let user = try result.get()
        #expect(user.id == 1)
        #expect(user.name == "John \"Doe\" 🚀")
        #expect(user.description == "Some description")
        #expect(user.unicode == "Héllo Wörld! 你好世界")
    }
    
    // MARK: - Error Message Tests
    
    @Test("ResponseParserError provides meaningful error descriptions")
    func testErrorDescriptions() {
        // Test noData error
        let noDataError = ResponseParserError.noData
        #expect(noDataError.errorDescription == "Data for non EmptyResponse is empty")
        
        // Test decodingError
        let underlyingError = NSError(domain: "TestError", code: 123, userInfo: [NSLocalizedDescriptionKey: "Test error"])
        let decodingError = ResponseParserError.decodingError(AnySendableError(underlyingError))
        #expect(decodingError.errorDescription?.contains("Failed to decode data") == true)
        #expect(decodingError.errorDescription?.contains("Test error") == true)
    }
}

// MARK: - Test Request Types

struct TestGetUserRequest: APIRequestProtocol {
    typealias Response = TestUser
    let userID: Int
    var endpoint: String { "/users/\(userID)" }
}

struct TestGetUsersListRequest: APIRequestProtocol {
    typealias Response = UsersListResponse
    var endpoint: String { "/users" }
}

struct TestGetNumbersRequest: APIRequestProtocol {
    typealias Response = [Int]
    var endpoint: String { "/numbers" }
}

struct TestGetStringRequest: APIRequestProtocol {
    typealias Response = String
    var endpoint: String { "/string" }
}

struct TestGetUserWithDateRequest: APIRequestProtocol {
    typealias Response = UserWithDate
    var endpoint: String { "/users/with-date" }
}

struct TestGetUserSnakeCaseRequest: APIRequestProtocol {
    typealias Response = UserSnakeCase
    var endpoint: String { "/users/snake-case" }
}

struct TestGetLargeUserArrayRequest: APIRequestProtocol {
    typealias Response = [TestUser]
    var endpoint: String { "/users/large" }
}

struct TestGetNullableUserRequest: APIRequestProtocol {
    typealias Response = NullableUser
    var endpoint: String { "/users/nullable" }
}

struct TestGetNestedStructureRequest: APIRequestProtocol {
    typealias Response = NestedStructure
    var endpoint: String { "/nested" }
}

struct TestGetSpecialCharUserRequest: APIRequestProtocol {
    typealias Response = SpecialCharUser
    var endpoint: String { "/users/special" }
}

// MARK: - Test Response Types

struct UsersListResponse: Codable {
    let users: [TestUser]
    let metadata: Metadata
    
    struct Metadata: Codable {
        let total: Int
        let page: Int
    }
}

struct UserWithDate: Codable {
    let id: Int
    let createdAt: Date
}

struct UserSnakeCase: Codable {
    let userId: Int
    let fullName: String
}

struct NullableUser: Codable {
    let id: Int
    let name: String?
    let email: String
}

struct NestedStructure: Codable {
    let level1: Level1
    
    struct Level1: Codable {
        let level2: Level2
        
        struct Level2: Codable {
            let level3: Level3
            
            struct Level3: Codable {
                let level4: Level4
                
                struct Level4: Codable {
                    let value: String
                }
            }
        }
    }
}

struct SpecialCharUser: Codable {
    let id: Int
    let name: String
    let description: String
    let unicode: String
}
