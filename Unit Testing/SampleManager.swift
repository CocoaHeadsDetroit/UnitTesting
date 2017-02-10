//
//  SampleManager.swift
//  Unit Testing
//
//  Created by Aaron DeGrow on 7/13/16.
//  Copyright © 2017 Vectorform. All rights reserved.
//

import UIKit

// Protocol to enable Dependency Injection of this manager class (not shown in this example)
internal protocol SampleManagerProtocol {
    func getUserInformation(_ username: String, password: String, completionHandler: @escaping (_ userInformation: Dictionary<String, String>?) -> Void)
}

/**
 Describes a manager that returns information about a user.
*/
internal class SampleManager: SampleManagerProtocol {
    // MARK: Properties
    fileprivate let apiService: SampleServiceProtocol
    fileprivate (set) var userInfoDictionary = [String: Dictionary<String, String>]()
    
    // Note: Dependency Injection is used here
    init(service: SampleServiceProtocol) {
        apiService = service
    }
    
    // Note: Convenience init such that 'default' dependency doesn't need to be passed in
    convenience init() {
        let service = SampleAPIService()
        self.init(service: service)
    }
    
    /**
     Get user information from the service.
     
     - parameter username:          The username to login with.
     - parameter password:          The password to login with.
     - parameter completionHandler: The completion handler to run with the results of the request.
     */
    internal func getUserInformation(_ username: String, password: String, completionHandler: @escaping (_ userInformation: Dictionary<String, String>?) -> Void) {
        // Try to lookup previously stored user info
        if let info = userInfoDictionary[username] {
            return completionHandler(info)
        }
        // Make a call to the service to get the user info
        apiService.login(username, password: password) { response in
            // If the login fails, abort the rest of the process
            guard response else {
                print("Unable to login!")
                completionHandler(nil)
                return
            }
            // Get the user info
            self.apiService.getUserInformation() { userInfo in
                // Attempt to logout no matter what result we get
                self.apiService.logout() { response in
                    guard response else {
                        print("Unable to logout!")
                        return
                    }
                    return
                }
                // Store whatever response we got and return it
                self.userInfoDictionary[username] = userInfo
                completionHandler(userInfo)
            }
        }
    }
}
