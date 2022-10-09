//
//  SignInView.swift
//  proxy_beta
//
//  Created by Erick Verleye on 7/5/22.
//

import SwiftUI
import Firebase
import GoogleSignIn
import FirebaseAuth
import CryptoKit
import AuthenticationServices
import UIKit
import AuthenticationServices
import Contacts

/** Contains sign in buttons and textual information to onboard the user
 - Parameters:
    -session: User' s current session object
 */
struct SignInView: View {
    @EnvironmentObject var session: SessionStore
    let TITLE = "Proxy"

    var body: some View {
        return NavigationView {
        GeometryReader { geometry in
            ZStack {
                // TODO: Add new logo here
                VStack {
                    // Show the app title
                    Text(TITLE).font(.system(size: 40)).bold().padding().foregroundColor(Color("Cyan"))
                    
                    // Show the sign up options
                    BottomScreen(width: geometry.size.width, height: geometry.size.height).environmentObject(self.session)
                }
            }
        }
        }.navigationViewStyle(StackNavigationViewStyle()).onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification), perform: { _ in
            // Remove all the messages and user text entries from the screen every time it appears
            self.session.signInError = ""
        })
    }
}


/**
 Displays the sign in option buttons and legal information
    - Parameters:
        -width: Parent view width
        -height: Parent view height
        -db: Connection to Firestore
        -showingFBLegalAlert: If True the legal accept alert will be shown
        -showingALegalAlert: If True the legal accept alert will be shown
        -showingAnonLegalAlert: If True the legal accept alert will be shown
        -showingGoogleLegalAlert: If True the legal accept alert will be shown
        -termsURLString: URL to terms of service document
        -privacyURLString: URL to privacy policy document
        -session: User's session instance
        -appleSignInDelegates: Sign in With Apple auth delegate
 */
struct BottomScreen: View {
    var width: CGFloat
    var height: CGFloat
    var db = Firestore.firestore()
    @Environment(\.window) var window: UIWindow?
    @Environment(\.colorScheme) var colorScheme
    @State var showingFBLegalAlert: Bool = false
    @State var showingALegalAlert: Bool = false
    @State var showingGoogleLegalAlert: Bool = false
    
    // TODO: Change to actual links
    @State var termsURLString: String = BACKUP_LEGAL_LINK
    @State var privacyURLString: String = BACKUP_LEGAL_LINK
    
    
    @EnvironmentObject var session: SessionStore
    @State var appleSignInDelegates: SignInWithAppleDelegates! = nil
    
    var body: some View {
        
        // Alert the user of legal info before they proceed
//        let FBlegalAlert =
//            Alert(title: Text(TERMS_AND_PRIVACY_POLICY), message: Text(USER_AGREEMENT_TEXT), primaryButton: .default(Text(CANCEL)), secondaryButton: .default(Text(CONTINUE), action: {
//                self.session.facebookLogin(authWorkflow: true)
//            }))
        
        // Alert the user of legal info before they proceed
        let AlegalAlert =
            Alert(title: Text(TERMS_AND_PRIVACY_POLICY), message: Text(USER_AGREEMENT_TEXT), primaryButton: .default(Text(CANCEL)), secondaryButton: .default(Text(CONTINUE), action: {
                showAppleLogin()
            }))
        
        // Alert the user of legal info before they proceed
//        let GoogleLegalAlert =
//            Alert(title: Text(TERMS_AND_PRIVACY_POLICY), message: Text(USER_AGREEMENT_TEXT), primaryButton: .default(Text(CANCEL)), secondaryButton: .default(Text(CONTINUE), action: {
//                self.session.googleLogin(authWorkflow: true)
//            }))
        
        VStack {
//            VStack {
                
                // Sign in with Apple
                Button(action: {self.showingALegalAlert = true}) {
                    SignInWithApple(style: self.colorScheme == .light ? .black : .white).aspectRatio(contentMode: .fit).frame(width: self.width * 0.80, height: self.height * 0.10, alignment: .center).id(self.colorScheme)
                }.alert(isPresented: $showingALegalAlert) {
                    AlegalAlert
                }
                
//                // Sign in with Google
//                Button(action: {self.showingGoogleLegalAlert = true}) {
//                Image("sign_in_with_google").resizable().cornerRadius(3.0).aspectRatio(contentMode: .fit).frame(width: self.width * 0.92, height: self.height * 0.10)
//                }.alert(isPresented: $showingGoogleLegalAlert) {
//                    GoogleLegalAlert
//                }
//
//                // Sign in with Facebook
//                Button(action: {self.showingFBLegalAlert = true}) {
//                    Image("facebook_login").resizable().cornerRadius(3.0).aspectRatio(contentMode: .fit).frame(width: self.width * 0.80)
//                }.alert(isPresented: $showingFBLegalAlert) {
//                    FBlegalAlert
//                }
//            }
            
            // Show the legal text and hyperlinks
            VStack {
            Text(USER_CONTINUE_LEGAL_TEXT).bold().font(.system(size: 17))
                HStack{
                    Link(TERMS_OF_SERVICE, destination: URL(string: self.termsURLString)!).foregroundColor(.blue).font(.system(size: 17))
            
            Text("and").bold().font(.system(size: 17))
                    Link(PRIVACY_POLICY, destination: URL(string: self.privacyURLString)!).foregroundColor(.blue).font(.system(size: 17))
                }
            }.frame(width: width, alignment: .center)
            
        }.frame(height: height).onAppear {
            // Read in the URLs for the Privacy Policy and Terms. Use website as backup link
            if self.termsURLString == BACKUP_LEGAL_LINK || self.privacyURLString == BACKUP_LEGAL_LINK {
                self.db.collection(AppSettings.name).document(AppSettings.documents.LINKS.name).getDocument {
                    docData, _ in
                    guard let data = docData?.data() else {return}
                    self.privacyURLString = data[AppSettings.documents.LINKS.fields.PRIVACY_POLICY] as? String ?? BACKUP_LEGAL_LINK
                    self.termsURLString = data[AppSettings.documents.LINKS.fields.TERMS_OF_SERVICE] as? String ?? BACKUP_LEGAL_LINK
                }
            }
        }
    }
    private func showAppleLogin() {
        appleSignInDelegates = SignInWithAppleDelegates(window: window, session: self.session)
      appleSignInDelegates.startSignInWithAppleFlow()
    }
}


class SignInWithAppleDelegates: NSObject {
    fileprivate var currentNonce: String?
    private weak var window: UIWindow!
    var session: SessionStore
    
    init(window: UIWindow?, session: SessionStore) {
      self.window = window
      self.session = session
    }
    
    private func randomNonceString(length: Int = 32) -> String {
      precondition(length > 0)
      let charset: Array<Character> =
          Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
      var result = ""
      var remainingLength = length

      while remainingLength > 0 {
        let randoms: [UInt8] = (0 ..< 16).map { _ in
          var random: UInt8 = 0
          let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
          if errorCode != errSecSuccess {
            fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
          }
          return random
        }

        randoms.forEach { random in
          if remainingLength == 0 {
            return
          }

          if random < charset.count {
            result.append(charset[Int(random)])
            remainingLength -= 1
          }
        }
      }

      return result
    }

    @available(iOS 13, *)
    func startSignInWithAppleFlow() {
      print("STARTING WORKFLOW")
      let nonce = randomNonceString()
      currentNonce = nonce
      let appleIDProvider = ASAuthorizationAppleIDProvider()
      let request = appleIDProvider.createRequest()
      request.requestedScopes = [.fullName, .email]
      request.nonce = sha256(nonce)

      let authorizationController = ASAuthorizationController(authorizationRequests: [request])
      authorizationController.delegate = self
      authorizationController.presentationContextProvider = self
      authorizationController.performRequests()
      print("SENT REQUEST")
    }

    @available(iOS 13, *)
    private func sha256(_ input: String) -> String {
      let inputData = Data(input.utf8)
      let hashedData = SHA256.hash(data: inputData)
      let hashString = hashedData.compactMap {
        return String(format: "%02x", $0)
      }.joined()

      return hashString
    }
}


extension SignInWithAppleDelegates: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
          guard let nonce = currentNonce else {
            fatalError("Invalid state: A login callback was received, but no login request was sent.")
          }
          guard let appleIDToken = appleIDCredential.identityToken else {
            print("Unable to fetch identity token")
            return
          }
          guard let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
            print("Unable to serialize token string from data: \(appleIDToken.debugDescription)")
            return
          }
          // Initialize a Firebase credential.
          let credential = OAuthProvider.credential(withProviderID: "apple.com",
                                                    idToken: idTokenString,
                                                    rawNonce: nonce)
          self.session.firebaseAuthWorkflow(credential: credential)
        }
      }

      func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        // Handle error.
        print("Sign in with Apple errored: \(error)")
        
        // TODO : Alert user here?
        
      }
}

extension SignInWithAppleDelegates: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return self.window
    }
}

struct WindowKey: EnvironmentKey {
  struct Value {
    weak var value: UIWindow?
  }
  
  static let defaultValue: Value = .init(value: nil)
}

extension EnvironmentValues {
  var window: UIWindow? {
    get { return self[WindowKey.self].value }
    set { self[WindowKey.self] = .init(value: newValue) }
  }
}
