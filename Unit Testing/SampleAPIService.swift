//
//  SampleAPIService.swift
//  Unit Testing
//
//  Created by Aaron DeGrow on 7/13/16.
//  Copyright © 2017 Vectorform. All rights reserved.
//

import UIKit

// Completion handler aliases
internal typealias BoolResult = (Bool) -> Void
internal typealias UserInfoResult = (Dictionary<String, String>?) -> Void
internal typealias DataTaskResult = (Data?, URLResponse?, Error?) -> Void

// Protocol to enable mocking of URLSessionDataTasks
internal protocol URLSessionDataTaskProtocol {
    func resume()
}

// Protocol to enable mocking of URLSessions
internal protocol URLSessionProtocol {
    func dataTaskWithRequest(_ request: URLRequest, completionHandler: @escaping DataTaskResult) -> URLSessionDataTaskProtocol
}

// Make NSURLSession and DatTask conform to the protocols
extension URLSessionDataTask: URLSessionDataTaskProtocol { }
extension URLSession: URLSessionProtocol {
    func dataTaskWithRequest(_ request: URLRequest, completionHandler: @escaping DataTaskResult) -> URLSessionDataTaskProtocol {
        return (dataTask(with: request, completionHandler: completionHandler) as URLSessionDataTask) as URLSessionDataTaskProtocol
    }
}


// Protocol to enable Dependency Injection of this service class
internal protocol SampleServiceProtocol {
    func login(_ username: String, password: String, completionHandler: @escaping BoolResult) -> Void
    func getUserInformation(_ completionHandler: @escaping UserInfoResult) -> Void
    func logout(_ completionHandler: @escaping BoolResult) -> Void
}

/**
 Describes a sample API used to get user information from a service.
*/
internal class SampleAPIService: SampleServiceProtocol {
    // MARK: Constants
    fileprivate let ServiceBaseURL = "https://www.example.com"
    fileprivate let LoginPath = "/login.asp"
    fileprivate let UserInformationPath = "/user_information.asp"
    fileprivate let LogoutPath = "/logout.asp"
    fileprivate let UserNameParameter = "user="
    fileprivate let PasswordParameter = "password="
    fileprivate let HTTPGetMethod = "GET"
    fileprivate let HTTPPostMethod = "POST"
    fileprivate let HTTPOkResult = 200
    // MARK: Properties
    fileprivate let urlSession: URLSessionProtocol
    fileprivate var cookies: [HTTPCookie]?
    
    // Note: Dependency Injection is used here
    init(session: URLSessionProtocol) {
        urlSession = session
    }
    
    // Note: Convenience init such that 'default' dependency doesn't need to be passed in
    convenience init() {
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.httpCookieAcceptPolicy = HTTPCookie.AcceptPolicy.onlyFromMainDocumentDomain
        sessionConfig.httpShouldSetCookies = true
        let session = URLSession(configuration: sessionConfig, delegate: nil, delegateQueue: nil)
        self.init(session: session)
    }
    
    /**
     Login to the service.
    
     - parameter username:          The username to login with.
     - parameter password:          The password to login with.
     - parameter completionHandler: The completion handler to run when the login is finished. Receives a Bool to indicate success.
    */
    internal func login(_ username: String, password: String, completionHandler: @escaping BoolResult) -> Void {
        // Build the URL request
        let requestURL = URL(string: ServiceBaseURL + LoginPath)
        let request = NSMutableURLRequest(url: requestURL!, cachePolicy: NSURLRequest.CachePolicy.reloadIgnoringCacheData, timeoutInterval: 10.0)
        request.httpMethod = HTTPPostMethod
        if let user = username.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed), let pass = password.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed) {
            let paramString = UserNameParameter + user + "&" + PasswordParameter + pass
            request.httpBody = paramString.data(using: String.Encoding.utf8)
            
            // Create the URL session task
            let task = urlSession.dataTaskWithRequest(request as URLRequest) { data, response, error in
                var success = false
                // Failure to cast as HTTP URL response or an error is a failure
                guard let httpResponse = response as? HTTPURLResponse, error == nil else {
                    completionHandler(success)
                    return
                }
                // Only HTTP 200 is a success
                switch httpResponse.statusCode {
                case self.HTTPOkResult:
                    // Cookie is required for success
                    if let fields = httpResponse.allHeaderFields as? [String : String], let url = response?.url, fields.count > 0 {
                        // The cookies in the response for a successful login must be stored for authentication of future requests
                        self.cookies = HTTPCookie.cookies(withResponseHeaderFields: fields, for: url)
                        if ((self.cookies?.count)! > 0) {
                            success = true
                        }
                    }
                default: break
                }
                completionHandler(success)
            }
            task.resume()
        }
    }
    
    /**
     Get user information from the service.
     
     - parameter completionHandler: The completion handler to run with the results of the request.
     */
    internal func getUserInformation(_ completionHandler: @escaping UserInfoResult) -> Void {
        // Build the URL request
        let requestURL = URL(string: ServiceBaseURL + UserInformationPath)
        let request = NSMutableURLRequest(url: requestURL!, cachePolicy: NSURLRequest.CachePolicy.reloadIgnoringCacheData, timeoutInterval: 10.0)
        // Auth cookie required
        guard let loginCookies = cookies else {
            completionHandler(nil)
            return
        }
        let headers = HTTPCookie.requestHeaderFields(with: loginCookies)
        request.allHTTPHeaderFields = headers
        request.httpMethod = HTTPGetMethod
        
        // Create the URL session task
        let task = urlSession.dataTaskWithRequest(request as URLRequest) { data, response, error in
            // Failure to cast as HTTP URL response or no data or an error is a failure
            guard let httpResponse = response as? HTTPURLResponse, let httpData = data, error == nil else {
                completionHandler(nil)
                return
            }
            var userInfo: Dictionary<String, String>?
            // Only HTTP 200 is a success
            if httpResponse.statusCode == self.HTTPOkResult {
                // Parse the user data as JSON
                do {
                    userInfo = try JSONSerialization.jsonObject(with: httpData, options: JSONSerialization.ReadingOptions()) as? Dictionary<String, String>
                } catch {
                    print("Error deserializing JSON!")
                }
            }
            completionHandler(userInfo)
        }
        task.resume()
    }
    
    /**
     Logout from the service.
     
     - parameter completionHandler: The completion handler to run when logout is complete. Receives a Bool to indicate success.
     */
    internal func logout(_ completionHandler: @escaping BoolResult) -> Void {
        // Build the URL request
        let requestURL = URL(string: ServiceBaseURL + LogoutPath)
        let request = NSMutableURLRequest(url: requestURL!, cachePolicy: NSURLRequest.CachePolicy.reloadIgnoringCacheData, timeoutInterval: 10.0)
        // Auth cookie required
        guard let loginCookies = cookies else {
            completionHandler(false)
            return
        }
        let headers = HTTPCookie.requestHeaderFields(with: loginCookies)
        request.allHTTPHeaderFields = headers
        request.httpMethod = HTTPGetMethod
        
        // Create the URL session task
        let task = urlSession.dataTaskWithRequest(request as URLRequest) { data, response, error in
            var success = false
            // Failure to cast as HTTP URL response or an error is a failure
            guard let httpResponse = response as? HTTPURLResponse, error == nil else {
                completionHandler(success)
                return
            }
            // Only HTTP 200 is a success
            if httpResponse.statusCode == self.HTTPOkResult {
                self.cookies = nil
                success = true
            }
            completionHandler(success)
        }
        task.resume()
    }
}
