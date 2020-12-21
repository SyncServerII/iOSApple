
import Foundation
import iOSSignIn
import ServerShared
import iOSShared

struct AccountDetails: Codable {
    public let firstName: String?
    public let lastName: String?
    public let fullName: String?
    public let email: String?
    
    init(firstName: String? = nil, lastName: String? = nil, fullName: String? = nil, email: String? = nil) {
        self.firstName = firstName
        self.lastName = lastName
        self.fullName = fullName
        self.email = email
    }
}

public class AppleCredentials : GenericCredentials {
    let savedCreds: SavedCredentials
    
    public var httpRequestHeaders: [String : String] {
        var result = [String : String]()
        
        // For CredentialsAppleSignIn
        result[ServerConstants.XTokenTypeKey] = "AppleSignInToken"
        result[ServerConstants.HTTPOAuth2AccessTokenKey] = savedCreds.identityToken
        
        // For ServerAppleSignInAccount
        result[ServerConstants.HTTPOAuth2AuthorizationCodeKey] = savedCreds.authorizationCode
        
        let accountDetails = AccountDetails(firstName: savedCreds.firstName, lastName: savedCreds.lastName, fullName: savedCreds.fullName, email: savedCreds.email)
        do {
            let encoded = try JSONEncoder().encode(accountDetails)
            let jsonString = String(data: encoded, encoding: .utf8)
            result[ServerConstants.HTTPAccountDetailsKey] = jsonString
        } catch let error {
            logger.error("\(error)")
        }
        
        return result
    }
    
    public var userId: String {
        return savedCreds.userIdentifier
    }
    
    public var username: String? {
        return savedCreds.fullName
    }
    
    public var uiDisplayName: String? {
        return savedCreds.email ?? savedCreds.fullName
    }
    
    init(savedCreds: SavedCredentials) {
        self.savedCreds = savedCreds
    }
    
    public func refreshCredentials(completion: @escaping (Error?) -> ()) {
        completion(nil)
    }
}

