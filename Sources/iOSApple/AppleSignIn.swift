
import iOSSignIn
import ServerShared
import UIKit
import AuthenticationServices
import iOSShared
import PersistentValue

// Need NSObject inheritance to conform to ASAuthorizationControllerDelegate
// Much of this is adapted from Apple's example: https://developer.apple.com/documentation/authenticationservices/implementing_user_authentication_with_sign_in_with_apple

public class AppleSignIn: NSObject, GenericSignIn {
    var stickySignIn = false
    let button = AppleSignInButton()
    
    static private let credentialsData = try! PersistentValue<Data>(name: "AppleSignIn.data", storage: .keyChain)
    
    private var savedCreds:SavedCredentials? {
        set {
            if let newValue = newValue {
                let encoder = JSONEncoder()
                do {
                    Self.credentialsData.value = try encoder.encode(newValue)
                } catch let error {
                    logger.error("\(error)")
                }
            }
            else {
                Self.credentialsData.value = nil
            }
        }
        
        get {
            if let data = Self.credentialsData.value {
                do {
                    return try JSONDecoder().decode(SavedCredentials.self, from: data)
                } catch let error {
                    logger.error("\(error)")
                }
            }
            
            return nil
        }
    }
    
    public var credentials:GenericCredentials? {
        if let savedCreds = savedCreds {
            return AppleCredentials(savedCreds: savedCreds)
        }
        else {
            return nil
        }
    }
    
    public var signInName: String = "Apple"
    
    public var userType: UserType = .sharing
    
    public var cloudStorageType: CloudStorageType? // nil because this is non-owning
    
    public var delegate: GenericSignInDelegate?

    public var userIsSignedIn: Bool = false
        
    override init() {
        super.init()
        button.delegate = self
    }
    
    public func appLaunchSetup(userSignedIn: Bool, withLaunchOptions options: [UIApplication.LaunchOptionsKey : Any]?) {
        if userSignedIn {
            if let creds = credentials {
                delegate?.haveCredentials(self, credentials: creds)
                completeSignInProcess(autoSignIn: true)
            }
            else {
                // Doesn't seem much point in keeping the user with signed-in status if we don't have creds.
                signUserOut()
            }
        }
    }
    
    func completeSignInProcess(autoSignIn:Bool) {
        // signInOutButton?.buttonShowing = .signOut
        stickySignIn = true
        delegate?.signInCompleted(self, autoSignIn: autoSignIn)
    }
    
    public func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any]) -> Bool {
        return false
    }
    
    public func networkChangedState(networkIsOnline: Bool) {
    }
    
    public func signInButton(configuration: [String : Any]?) -> UIView? {
        return button
    }
    
    public func signUserOut() {
        signUserOut(cancelOnly: false)
    }
    
    private func signUserOut(cancelOnly: Bool) {
        stickySignIn = false
        
        savedCreds = nil
        
        #warning("I want the button to change state here. Not sure if Apple's does that.")
        
        if cancelOnly {
            delegate?.signInCancelled(self)
        }
        else {
            delegate?.userIsSignedOut(self)
        }
    }
}

extension AppleSignIn: ASAuthorizationControllerDelegate {
    public func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        switch authorization.credential {
        case let appleIDCredential as ASAuthorizationAppleIDCredential:
            // In Apple's example, they store the `ASAuthorizationAppleIDCredential` into the keychain. I'm assuming this means that we can't get this info otherwise.
            let savedCreds: SavedCredentials
            do {
                savedCreds = try SavedCredentials.from(appleIDCredential: appleIDCredential)
            }
            catch let error {
                logger.error("\(error)")
                return
            }
            
            self.savedCreds = savedCreds
            
            if let credentials = credentials {
                delegate?.haveCredentials(self, credentials: credentials)
            }
            
            completeSignInProcess(autoSignIn: false)

        default:
            logger.error("Did not get ASAuthorizationAppleIDCredential")
        }
    }

    public func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        logger.error("\(error)")
    }
}

extension AppleSignIn: ASAuthorizationControllerPresentationContextProviding {
    public func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return ASPresentationAnchor()
    }
}

extension AppleSignIn: AppleSignInButtonDelegate {
    func signInTapped(_ button: AppleSignInButton) {
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.fullName, .email]
        
        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = self
        authorizationController.presentationContextProvider = self
        authorizationController.performRequests()
    }
}
