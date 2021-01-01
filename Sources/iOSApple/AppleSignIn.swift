
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
        
    public override init() {
        super.init()
        button.delegate = self
    }
    
    // Call this periodically.
    func appleSignInIsAuthorized(completion: @escaping (_ authorized: Bool?)->()) {
        guard let credentials = credentials else {
            completion(nil)
            return
        }
        
        let provider = ASAuthorizationAppleIDProvider()
        provider.getCredentialState(forUserID: credentials.userId) { state, error in
            if let error = error {
                completion(nil)
                logger.error("getCredentialState: \(error)")
                return
            }
            
            switch state {
            case .authorized:
                // Credentials are valid. Don't do anything.
                completion(true)
                
            case .revoked, .notFound, .transferred:
                completion(false)
                logger.warning("User not authorized: \(state); signed out.")
                
            @unknown default:
                completion(nil)
                logger.warning("Unknown state: \(state)")
            }
        }
    }
    
    public func appLaunchSetup(userSignedIn: Bool, withLaunchOptions options: [UIApplication.LaunchOptionsKey : Any]?) {
        if userSignedIn {
            if let creds = credentials {
                appleSignInIsAuthorized() { [weak self] authorized  in
                    guard let self = self else { return }
                    
                    if let authorized = authorized, !authorized {
                        self.signUserOut()
                        return
                    }
                    
                    self.delegate?.haveCredentials(self, credentials: creds)
                    self.completeSignInProcess(autoSignIn: true)
                }
            }
            else {
                // Doesn't seem much point in keeping the user with signed-in status if we don't have creds.
                signUserOut()
            }
        }
    }
    
    func completeSignInProcess(autoSignIn:Bool) {
        button.buttonShowing = .signOut
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
        button.buttonShowing = .signIn
        
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
        signUserOut(cancelOnly: true)
    }
}

extension AppleSignIn: ASAuthorizationControllerPresentationContextProviding {
    public func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return ASPresentationAnchor()
    }
}

extension AppleSignIn: AppleSignInButtonDelegate {
    func signUserOut(_ button: AppleSignInButton) {
        signUserOut()
    }
    
    func signInStarted(_ button: AppleSignInButton) {
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.fullName, .email]
        
        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = self
        authorizationController.presentationContextProvider = self
        authorizationController.performRequests()
        
        delegate?.signInStarted(self)
    }
}
