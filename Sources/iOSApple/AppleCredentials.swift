
import Foundation
import iOSSignIn
import ServerShared

public class AppleCredentials : GenericCredentials {
    let savedCreds: SavedCredentials
    
    public var httpRequestHeaders: [String : String] {
        var result = [String : String]()
        
        // For CredentialsAppleSignIn
        result[ServerConstants.XTokenTypeKey] = "AppleSignInToken"
        result[ServerConstants.HTTPOAuth2AccessTokenKey] = savedCreds.identityToken
        
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
    }
}

