//
//  AuthenticationClass.swift
//  Graph-iOS-Swift-Connect

import Foundation
import MSAL

class Authentication {
    
    var authenticationProvider = MSALPublicClientApplication.init()
    var accessToken: String = ""
    var lastInitError: String? = ""
    
    init () {
        
        do {
            
            //Get the MSAL client Id for this Azure app registration. We store it in the main bundle
            var redirectUrl: String = "";
            var myDict: NSDictionary?
            if let path = Bundle.main.path(forResource: "Info", ofType: "plist") {
                myDict = NSDictionary(contentsOfFile: path)
            }
            if let dict = myDict {
                let array: NSArray =  (dict.object(forKey: "CFBundleURLTypes") as? NSArray)!;
                redirectUrl = getRedirectUrlFromMSALArray(array: array);
            }
            //  var NSRange range = [redirectUrl rangeOfString:@"msal"];
            let range: Range<String.Index> = redirectUrl.range(of: "msal")!;
            let kClientId: String = redirectUrl.substring(from: range.upperBound);
            guard let authorityURL = URL(string: ApplicationConstants.kAuthority) else {
                return
            }
            let authority = try MSALAuthority(url: authorityURL)
            authenticationProvider = try MSALPublicClientApplication.init(clientId: kClientId, authority: authority)
//            authenticationProvider = try MSALPublicClientApplication.init(clientId: kClientId, keychainGroup: nil)
        } catch  let error as NSError  {
            self.lastInitError = error.userInfo.description
            authenticationProvider = MSALPublicClientApplication.init()
        }
    }
    /**
     Authenticates to Microsoft Graph.
     If a user has previously signed in before and not disconnected, silent log in
     will take place.
     If not, authentication will ask for credentials
     */
    
    func connectToGraphSliently(scopes: [String],
                                completion:@escaping (_ error: ApplicationConstants.MSGraphError?, _ accessToken: String) -> Bool) {
        
        do {
            if let initError = self.lastInitError {
                if initError.lengthOfBytes(using: String.Encoding.ascii) > 1 {
                    throw NSError.init(domain: initError, code: 0, userInfo: nil)
                }
            }
            // We check to see if we have a current logged in user. If we don't, then we need to sign someone in.
            // We throw an interactionRequired so that we trigger the interactive signin.
            
            if  try authenticationProvider.allAccounts().isEmpty {
                throw NSError.init(domain: "MSALErrorDomain", code: MSALErrorCode.interactionRequired.rawValue, userInfo: nil)
            } else {
                
                // Acquire a token for an existing user silently
                
                try authenticationProvider.acquireTokenSilent(forScopes: scopes, account: authenticationProvider.allAccounts()[0]) { (result, error) in
                    
                    if error == nil {
                        self.accessToken = (result?.accessToken)!
                        _ = completion(nil, self.accessToken);
                        
                    } else {
                        
                        //"Could not acquire token silently: \(error ?? "No error information" as! Error )"
                        var _ = completion(ApplicationConstants.MSGraphError.nsErrorType(error: error! as NSError), "");
                        
                    }
                }
            }
        }  catch let error as NSError {
            
            // interactionRequired means we need to ask the user to sign-in. This usually happens
            // when the user's Refresh Token is expired or if the user has changed their password
            // among other possible reasons.
            
            if error.code == MSALErrorCode.interactionRequired.rawValue {
                
                authenticationProvider.acquireToken(forScopes: scopes) { (result, error) in
                    if error == nil {
                        self.accessToken = (result?.accessToken)!
                        var _ = completion(nil, self.accessToken);
                    } else  {
                        var _ = completion(ApplicationConstants.MSGraphError.nsErrorType(error: error! as NSError), "");
                    }
                }
                
            } else {
                var _ = completion(ApplicationConstants.MSGraphError.nsErrorType(error: error as NSError), error.localizedDescription);
                
            }
            
        } catch {
            
            // This is the catch all error.
            
            
            var _ = completion(ApplicationConstants.MSGraphError.nsErrorType(error: error as NSError), error.localizedDescription);
            
        }
    }
    
    
    func connectToGraph(scopes: [String],
                        completion:@escaping (_ error: ApplicationConstants.MSGraphError?, _ accessToken: String) -> Bool)  {
        
        do {
            if let initError = self.lastInitError {
                if initError.lengthOfBytes(using: String.Encoding.ascii) > 1 {
                    throw NSError.init(domain: initError, code: 0, userInfo: nil)
                }
            }
            // We check to see if we have a current logged in user. If we don't, then we need to sign someone in.
            // We throw an interactionRequired so that we trigger the interactive signin.
            authenticationProvider.acquireToken(forScopes: scopes) { (result, error) in
                if error == nil {
                    self.accessToken = (result?.accessToken)!
                    var _ = completion(nil, self.accessToken);
                } else  {
                    var _ = completion(ApplicationConstants.MSGraphError.nsErrorType(error: error! as NSError), "");
                    
                }
            }
        }  catch let error as NSError {
            // interactionRequired means we need to ask the user to sign-in. This usually happens
            // when the user's Refresh Token is expired or if the user has changed their password
            // among other possible reasons.
                var _ = completion(ApplicationConstants.MSGraphError.nsErrorType(error: error as NSError), error.localizedDescription);

            
        } catch {
            
            // This is the catch all error.
            var _ = completion(ApplicationConstants.MSGraphError.nsErrorType(error: error as NSError), error.localizedDescription);
            
        }
    }
    
    func disconnect() -> Bool {
        var result = true
        do {
            try authenticationProvider.remove(authenticationProvider.allAccounts()[0])
        } catch _ {
           result = false
        }
        return result
    }
    
    // Get client id from bundle
    
    func getRedirectUrlFromMSALArray(array: NSArray) -> String {
        let arrayElement: NSDictionary = array.object(at: 0) as! NSDictionary;
        let redirectArray: NSArray = arrayElement.value(forKeyPath: "CFBundleURLSchemes") as! NSArray;
        let subString: NSString = redirectArray.object(at: 0) as! NSString;
        return subString as String;
    }
}
