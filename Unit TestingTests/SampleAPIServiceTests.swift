//
//  SampleAPIServiceTests.swift
//  Unit Testing
//
//  Created by Aaron DeGrow on 7/13/16.
//  Copyright © 2017 Vectorform. All rights reserved.
//

import XCTest
@testable import Unit_Testing

// Mock the URLSessionDataTask to remove actual network calls
class MockURLSessionDataTask: URLSessionDataTaskProtocol {
    fileprivate (set) var resumeWasCalled = false
    
    func resume() {
        resumeWasCalled = true
    }
}

// Mock the URLSession to remove actual network calls
// Flatten the async calls by immediately calling the completion handler using variables to specify results
class MockURLSession: URLSessionProtocol {
    // This variable allows an external class (tests) to specify a URLSessionDataTask (a mocked one)
    var dataTask = MockURLSessionDataTask()
    // These variables allow an external class (tests) to specify the return result for the completion handler
    var data: Data?
    var urlResponse: URLResponse?
    var error: NSError?
    // Public read-only variable to allow external classes to verify the last used URLRequest
    fileprivate (set) var lastRequest: URLRequest?
    
    func dataTaskWithRequest(_ request: URLRequest, completionHandler: @escaping DataTaskResult) -> URLSessionDataTaskProtocol {
        // Store the request for others to use for verification
        lastRequest = request
        // Immediately call the completion handler (flattened async) with the specified results (from above)
        completionHandler(data, urlResponse, error)
        // Return the specified data task (from above)
        return dataTask
    }
}

class SampleAPIServiceTests: XCTestCase {
    var mockTask: MockURLSessionDataTask!
    var mockSession: MockURLSession!
    var service: SampleAPIService!
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
        // Create a mock URL task and session, and create a service object using the mock URL objects
        mockTask = MockURLSessionDataTask()
        mockSession = MockURLSession()
        mockSession.dataTask = mockTask
        service = SampleAPIService(session: mockSession)
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testLoginSuccess() {
        // Given
        mockSession.data = nil
        let headers: [String: String] = ["Set-Cookie": "Login=success"]
        let url = URL(string: "https://www.example.com")!
        mockSession.urlResponse = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: headers)
        mockSession.error = nil
        
        // When
        service.login("good_username", password: "good_password") { success in
            // Then
            XCTAssertTrue(success, "Login should have been successful")
        }
        XCTAssertTrue(self.mockTask.resumeWasCalled, "Resume should have been called")
    }
    
    func testLoginNoCookie() {
        mockSession.data = nil
        let url = URL(string: "https://www.example.com")!
        mockSession.urlResponse = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)
        mockSession.error = nil
        
        service.login("good_username", password: "good_password") { success in
            XCTAssertFalse(success, "Login should have failed")
        }
        XCTAssertTrue(self.mockTask.resumeWasCalled, "Resume should have been called")
    }
    
    func testLoginNotFound() {
        mockSession.data = nil
        let url = URL(string: "https://www.example.com")!
        mockSession.urlResponse = HTTPURLResponse(url: url, statusCode: 404, httpVersion: nil, headerFields: nil)
        mockSession.error = nil
        
        service.login("good_username", password: "good_password") { success in
            XCTAssertFalse(success, "Login should have failed")
        }
        XCTAssertTrue(self.mockTask.resumeWasCalled, "Resume should have been called")
    }
    
    func testLoginBadCredentials() {
        mockSession.data = nil
        let url = URL(string: "https://www.example.com")!
        mockSession.urlResponse = HTTPURLResponse(url: url, statusCode: 401, httpVersion: nil, headerFields: nil)
        mockSession.error = nil
        
        service.login("bad_username", password: "bad_password") { success in
            XCTAssertFalse(success, "Login should have failed")
        }
        XCTAssertTrue(self.mockTask.resumeWasCalled, "Resume should have been called")
    }
    
    func testLoginNetworkError() {
        mockSession.data = nil
        // pass in a valid response just to ensure that the error triggers a failure
        let url = URL(string: "https://www.example.com")!
        mockSession.urlResponse = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)
        mockSession.error = NSError(domain: "Network Error", code: 0, userInfo: nil)
        
        service.login("good_username", password: "good_password") { success in
            XCTAssertFalse(success, "Login should have failed")
        }
        XCTAssertTrue(self.mockTask.resumeWasCalled, "Resume should have been called")
    }
    
    func testGetUserInformationSuccess() {
        // Login first (done this way because cookies variable of the service is private)
        mockSession.data = nil
        let headers: [String: String] = ["Set-Cookie": "Login=success"]
        let url = URL(string: "https://www.example.com")!
        mockSession.urlResponse = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: headers)
        mockSession.error = nil
        service.login("good_username", password: "good_password") { success in }
        // Create new task and response
        mockTask = MockURLSessionDataTask()
        mockSession.dataTask = mockTask
        let httpData = "{\"sample1\": \"John\", \"sample2\": \"Bob\"}".data(using: String.Encoding.utf8)!
        mockSession.data = httpData
        mockSession.urlResponse = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)
        mockSession.error = nil
        var expectedInfo = [String: String]()
        do {
            expectedInfo = try JSONSerialization.jsonObject(with: httpData, options: JSONSerialization.ReadingOptions()) as! Dictionary<String, String>
        } catch {
            print("Error deserializing JSON!")
        }
        
        service.getUserInformation() { userInfo in
            XCTAssertNotNil(userInfo, "User information should not be nil")
            if let info = userInfo {
                XCTAssertEqual(info, expectedInfo, "User information should match expected JSON object")
            }
        }
        
        XCTAssertTrue(self.mockTask.resumeWasCalled, "Resume should have been called")
    }
    
    func testGetUserInformationNoCookiesSet() {
        // Pass in valid data and response just to ensure that the lack of cookies triggers a failure
        let httpData = "{\"sample1\": \"John\", \"sample2\": \"Bob\"}".data(using: String.Encoding.utf8)!
        mockSession.data = httpData
        let url = URL(string: "https://www.example.com")!
        mockSession.urlResponse = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)
        mockSession.error = nil
        
        service.getUserInformation() { userInfo in
            XCTAssertNil(userInfo, "User information should be nil")
        }
        
        XCTAssertFalse(self.mockTask.resumeWasCalled, "Resume should not have been called")
    }
    
    func testGetUserInformationNetworkError() {
        // Login first (done this way because cookies variable is private)
        mockSession.data = nil
        let headers: [String: String] = ["Set-Cookie": "Login=success"]
        let url = URL(string: "https://www.example.com")!
        mockSession.urlResponse = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: headers)
        mockSession.error = nil
        service.login("good_username", password: "good_password") { success in }
        // Create new task and response
        mockTask = MockURLSessionDataTask()
        mockSession.dataTask = mockTask
        // Pass in valid data and response just to ensure that the error triggers a failure
        let httpData = "{\"sample1\": \"John\", \"sample2\": \"Bob\"}".data(using: String.Encoding.utf8)!
        mockSession.data = httpData
        mockSession.urlResponse = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)
        mockSession.error = NSError(domain: "Network Error", code: 0, userInfo: nil)
        
        service.getUserInformation() { userInfo in
            XCTAssertNil(userInfo, "User information should be nil")
        }
        
        XCTAssertTrue(self.mockTask.resumeWasCalled, "Resume should have been called")
    }
    
    func testGetUserInformationNotFound() {
        // Login first (done this way because cookies variable is private)
        mockSession.data = nil
        let headers: [String: String] = ["Set-Cookie": "Login=success"]
        let url = URL(string: "https://www.example.com")!
        mockSession.urlResponse = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: headers)
        mockSession.error = nil
        service.login("good_username", password: "good_password") { success in }
        // Create new task and response
        mockTask = MockURLSessionDataTask()
        mockSession.dataTask = mockTask
        // Pass in valid data and response just to ensure that the 404 triggers a failure
        let httpData = "{\"sample1\": \"John\", \"sample2\": \"Bob\"}".data(using: String.Encoding.utf8)!
        mockSession.data = httpData
        mockSession.urlResponse = HTTPURLResponse(url: url, statusCode: 404, httpVersion: nil, headerFields: nil)
        mockSession.error = nil
        
        service.getUserInformation() { userInfo in
            XCTAssertNil(userInfo, "User information should be nil")
        }
        
        XCTAssertTrue(self.mockTask.resumeWasCalled, "Resume should have been called")
    }
    
    
    func testGetUserInformationNoData() {
        // Login first (done this way because cookies variable is private)
        mockSession.data = nil
        let headers: [String: String] = ["Set-Cookie": "Login=success"]
        let url = URL(string: "https://www.example.com")!
        mockSession.urlResponse = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: headers)
        mockSession.error = nil
        service.login("good_username", password: "good_password") { success in }
        // Create new task and response
        mockTask = MockURLSessionDataTask()
        mockSession.dataTask = mockTask
        mockSession.data = Data()
        mockSession.urlResponse = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)
        mockSession.error = nil
        
        service.getUserInformation() { userInfo in
            XCTAssertNil(userInfo, "User information should be nil")
        }
        
        XCTAssertTrue(self.mockTask.resumeWasCalled, "Resume should have been called")
    }
    
    func testGetUserInformationBadData() {
        // Login first (done this way because cookies variable is private)
        mockSession.data = nil
        let headers: [String: String] = ["Set-Cookie": "Login=success"]
        let url = URL(string: "https://www.example.com")!
        mockSession.urlResponse = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: headers)
        mockSession.error = nil
        service.login("good_username", password: "good_password") { success in }
        // Create new task and response
        mockTask = MockURLSessionDataTask()
        mockSession.dataTask = mockTask
        let httpData = "{sample1: John, sample2: Bob}".data(using: String.Encoding.utf8)!
        mockSession.data = httpData
        mockSession.urlResponse = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)
        mockSession.error = nil
        
        service.getUserInformation() { userInfo in
            XCTAssertNil(userInfo, "User information should be nil")
        }
        
        XCTAssertTrue(self.mockTask.resumeWasCalled, "Resume should have been called")
    }
    
    func testLogoutSuccess() {
        // Login first (done this way because cookies variable is private)
        mockSession.data = nil
        let headers: [String: String] = ["Set-Cookie": "Login=success"]
        let url = URL(string: "https://www.example.com")!
        mockSession.urlResponse = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: headers)
        mockSession.error = nil
        service.login("good_username", password: "good_password") { success in }
        // Create new task and response
        mockTask = MockURLSessionDataTask()
        mockSession.dataTask = mockTask
        mockSession.data = nil
        mockSession.urlResponse = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)
        mockSession.error = nil
        
        service.logout() { success in
            XCTAssertTrue(success, "Logout should have been successful")
        }
        
        XCTAssertTrue(self.mockTask.resumeWasCalled, "Resume should have been called")
    }
    
    func testLogoutNoCookiesSet() {
        mockSession.data = nil
        // Pass in a valid response just to ensure that the lack of cookies triggers a failure
        let url = URL(string: "https://www.example.com")!
        mockSession.urlResponse = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)
        mockSession.error = nil
        
        service.logout() { success in
            XCTAssertFalse(success, "Logout should have failed")
        }
        
        XCTAssertFalse(self.mockTask.resumeWasCalled, "Resume should not have been called")
    }
    
    func testLogoutNetworkError() {
        // Login first (done this way because cookies variable is private)
        mockSession.data = nil
        let headers: [String: String] = ["Set-Cookie": "Login=success"]
        let url = URL(string: "https://www.example.com")!
        mockSession.urlResponse = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: headers)
        mockSession.error = nil
        service.login("good_username", password: "good_password") { success in }
        // Create new task and response
        mockTask = MockURLSessionDataTask()
        mockSession.dataTask = mockTask
        mockSession.data = nil
        // Pass in a valid response just to ensure that the error triggers a failure
        mockSession.urlResponse = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)
        mockSession.error = NSError(domain: "Network Error", code: 0, userInfo: nil)
        
        service.logout() { success in
            XCTAssertFalse(success, "Logout should have failed")
        }
        
        XCTAssertTrue(self.mockTask.resumeWasCalled, "Resume should have been called")
    }
    
    func testLogoutNotFound() {
        // Login first (done this way because cookies variable is private)
        mockSession.data = nil
        let headers: [String: String] = ["Set-Cookie": "Login=success"]
        let url = URL(string: "https://www.example.com")!
        mockSession.urlResponse = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: headers)
        mockSession.error = nil
        service.login("good_username", password: "good_password") { success in }
        // Create new task and response
        mockTask = MockURLSessionDataTask()
        mockSession.dataTask = mockTask
        mockSession.data = nil
        mockSession.urlResponse = HTTPURLResponse(url: url, statusCode: 404, httpVersion: nil, headerFields: nil)
        mockSession.error = nil
        
        service.logout() { success in
            XCTAssertFalse(success, "Logout should have failed")
        }
        
        XCTAssertTrue(self.mockTask.resumeWasCalled, "Resume should have been called")
    }

}
