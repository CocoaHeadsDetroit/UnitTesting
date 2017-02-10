//
//  SampleManagerTests.swift
//  Unit Testing
//
//  Created by Aaron DeGrow on 7/13/16.
//  Copyright © 2017 Vectorform. All rights reserved.
//

import XCTest
@testable import Unit_Testing

// Mock the API Service to remove actual network calls
// Flatten the async calls by immediately calling completion handlers using variables to specify results
class MockAPIService: SampleServiceProtocol {

    fileprivate var getUserInformationWasCalled = false
    // These variables allow an external class (tests) to specify the return result for each method
    var loginResult = false
    var getUserInformationResult: Dictionary<String, String>?
    var logoutResult = false

    func login(_ username: String, password: String, completionHandler: @escaping BoolResult) {
        completionHandler(loginResult)
    }
    
    func getUserInformation(_ completionHandler: @escaping UserInfoResult) -> Void {
        getUserInformationWasCalled = true
        completionHandler(getUserInformationResult)
    }
    
    func logout(_ completionHandler: @escaping BoolResult) -> Void {
        completionHandler(logoutResult)
    }
}

class SampleManagerTests: XCTestCase {
    var mockService: MockAPIService!
    var manager: SampleManager!
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
        // Create mock service, and create manager using mock service object
        mockService = MockAPIService()
        manager = SampleManager(service: mockService)
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testGetUserInformationSuccess() {
        let expectedInfo = ["real_name": "John Smith", "country": "United States"]
        mockService.loginResult = true
        mockService.getUserInformationResult = expectedInfo
        mockService.logoutResult = true
        
        manager.getUserInformation("good_username", password: "good_password") { userInfo in
            XCTAssertNotNil(userInfo, "User Information should not be Nil")
            if let info = userInfo {
                XCTAssertEqual(info, expectedInfo, "User Information should match expected dictionary")
            }
        }
    }
    
    func testGetUserInformationStoredReturnsWithoutAPICall() {
        // Perform initial request to populate the user info dictionary
        let expectedInfo = ["real_name": "John Smith", "country": "United States"]
        mockService.loginResult = true
        mockService.getUserInformationResult = expectedInfo
        mockService.logoutResult = true
        manager.getUserInformation("good_username", password: "good_password") { userInfo in }
        mockService.getUserInformationWasCalled = false
        
        // When
        manager.getUserInformation("good_username", password: "good_password") { userInfo in
            // Then
            XCTAssertNotNil(userInfo, "User Information should not be Nil")
            if let info = userInfo {
                XCTAssertEqual(info, expectedInfo, "User Information should match expected dictionary")
            }
        }
        XCTAssertNotNil(manager.userInfoDictionary, "Manager User Information should not be Nil")
        XCTAssertFalse(mockService.getUserInformationWasCalled, "Get User Information API should not have been called")
    }
    
    func testGetUserInformationLoginFailed() {
        // Given
        mockService.loginResult = false
        mockService.getUserInformationResult = nil
        mockService.logoutResult = false
        
        // When
        manager.getUserInformation("bad_username", password: "bad_password") { userInfo in
            // Then
            XCTAssertNil(userInfo, "User Information should be Nil")
        }
    }
    
    func testGetUserInformationReturnsNil() {
        mockService.loginResult = true
        mockService.getUserInformationResult = nil
        mockService.logoutResult = true
        
        manager.getUserInformation("good_username", password: "good_password") { userInfo in
            XCTAssertNil(userInfo, "User Information should be Nil")
        }
    }
    
    func testGetUserInformationLogoutFailed() {
        let expectedInfo = ["real_name": "John Smith", "country": "United States"]
        mockService.loginResult = true
        mockService.getUserInformationResult = expectedInfo
        mockService.logoutResult = false
        
        manager.getUserInformation("good_username", password: "good_password") { userInfo in
            XCTAssertNotNil(userInfo, "User Information should not be Nil")
            if let info = userInfo {
                XCTAssertEqual(info, expectedInfo, "User Information should match expected dictionary")
            }
        }
    }
}
