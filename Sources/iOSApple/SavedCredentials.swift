
import Foundation
import AuthenticationServices
import iOSSignIn

// Fields from ASAuthorizationAppleIDCredential that we want to save in the keychain once the user is signed in.

class SavedCredentials: Codable {
    // This is needed by ServerAppleSignInAccount on the server.
    let authorizationCode: String
    
    // This is needed by the CredentialsAppleSignIn Kitura plugin on the server that does primary authentication.
    let identityToken: String
    
    // Apple's unique identifier for the user.
    let userIdentifier: String
    
    let firstName: String?
    let lastName: String?
    var fullName: String?
    
    let email: String?
    
    init(authorizationCode: String, identityToken: String, userIdentifier: String, firstName: String?, lastName: String?, fullName: String?, email: String?) {
        self.authorizationCode = authorizationCode
        self.identityToken = identityToken
        self.userIdentifier = userIdentifier
        self.firstName = firstName
        self.lastName = lastName
        self.email = email
        self.fullName = fullName
    }
}

extension SavedCredentials {
    enum SavedCredentialsError: Error {
        case badAuthorizationCode
        case badIdToken
    }
    
    // I'm getting nil username from the apple creds: https://stackoverflow.com/questions/57593070
    
    static func from(appleIDCredential: ASAuthorizationAppleIDCredential) throws -> SavedCredentials {
        let userIdentifier = appleIDCredential.user
        let nameComponents:PersonNameComponents? = appleIDCredential.fullName
        
        var fullName: String? = [nameComponents?.givenName, nameComponents?.familyName].compactMap {$0}.joined(separator: " ")
        if fullName?.count == 0 {
            fullName = nil
        }
        
        let email = appleIDCredential.email

        guard let authorizationCode = appleIDCredential.authorizationCode,
            let authorizationCodeString = String(data: authorizationCode, encoding: .utf8) else {
            throw SavedCredentialsError.badAuthorizationCode
        }
        
        guard let idToken = appleIDCredential.identityToken,
            let idTokenString = String(data: idToken, encoding: .utf8) else {
            throw SavedCredentialsError.badIdToken
        }
            
        return SavedCredentials(authorizationCode: authorizationCodeString, identityToken: idTokenString, userIdentifier: userIdentifier, firstName: nameComponents?.givenName, lastName: nameComponents?.familyName, fullName: fullName, email: email)
    }
}
