
import Foundation
import UIKit
import AuthenticationServices

// See https://developer.apple.com/design/human-interface-guidelines/sign-in-with-apple/overview/buttons/

protocol AppleSignInButtonDelegate: AnyObject {
    func signInTapped(_ button: AppleSignInButton)
}

class AppleSignInButton: ASAuthorizationAppleIDButton {
    weak var delegate: AppleSignInButtonDelegate?
    
    private override init(authorizationButtonType type: ASAuthorizationAppleIDButton.ButtonType, authorizationButtonStyle style: ASAuthorizationAppleIDButton.Style) {
        super.init(authorizationButtonType: type, authorizationButtonStyle: style)
    }
    
    convenience init() {
        self.init(authorizationButtonType: .signIn, authorizationButtonStyle: .white)
        
        addTarget(self, action: #selector(buttonPress), for: .touchUpInside)
    }
    
    #warning("TODO: Need a sign-out. The UI needs to change to sign-out from sign-in and vice versa.")
    
    @objc func buttonPress() {
        delegate?.signInTapped(self)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
