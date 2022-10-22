//
//  SessionStore.swift
//  proxy_beta
//
//  Created by Erick Verleye on 7/5/22.
//

import SwiftUI
import Firebase
import GoogleSignIn
import FirebaseMessaging
import FBSDKLoginKit
import FirebaseAuth
import FirebaseFirestore
import CoreLocation

import Combine

enum SignInState {
    case signedIn
    case signedOut
    case loading
  }

/**
 Creates an instance of the users authentication state and other single instance attributes for the user's session
    - Parameters:
        -hadle: Connection to the user's auth state
        -user: User object containing information about the current user
        -signUpError: Text for any sign up errors that need to be displayed to the user
        -signInError: Text for any sign in error that need to be displayed to the user
        -isLoggedIn: The sign in state of the user
        -isTutorialCompleted: True if the user has completed the tutorial already
        -selectedProjects: The projects that the user has subscribed to and that will be displayed on the home screen
        -appleCredential: Auth credential created by the sign in with Apple api
        -googleCredential: Auth credential created by the sign in with Google api
        -facebookCredential: Auth credential created by the sign in with Facebook api
        -db: Connection to Firestore
        -loginManager: Facebook login manager
 */
class SessionStore : NSObject, ObservableObject {
    var handle: AuthStateDidChangeListenerHandle?
    @ObservedObject var user: User = User()
    @Published var signUpError: String = ""
    @Published var signInError: String = ""
    @Published var isLoggedIn: SignInState = .loading
    @Published var profileInformation: UserCardData? = nil
    
    private var db = Firestore.firestore()
    let loginManager = LoginManager()
    
    override init() {
        super.init()
        
        // Check to see if the user is authenticated
        if self.user.user != nil {
            
            // See if the user has completed the tutorial
            //self.getTutorialStatus()
            
            // See if the user's document is in the database
            if self.user.uid != nil {
                self.db.collection(Users.name).document(self.user.uid!).getDocument(
                    completion: {
                        data, error in
                        print("READ J")
                        if error == nil && data != nil {
                            
                            if self.profileInformation == nil || self.profileInformation!.uid != self.user.uid! {
                                self.profileInformation = UserCardData(uid: self.user.uid!, name: nil, age: nil, photoURL: nil, relationshipStatus: nil, occupation: nil, instagramUsername: nil)
                            }
                            
                            self.profileInformation?.syncReadProfileInfo()
                            
                            self.isLoggedIn = .signedIn
                        }
                        else {
                            // For some reason the users UID could not be resolved
                            do {
                                try Auth.auth().signOut()
                                self.isLoggedIn = .signedOut
                            }
                            catch {
                                // Don't do anything, there was no user
                            }
                        }
                    }
                )
            }
            
            // For some reason the users UID could not be resolved
            else {
                do {
                    try Auth.auth().signOut()
                    self.isLoggedIn = .signedOut
                }
                catch {
                    // Don't do anything, there was no user
                }
            }
        }
        
        // The user is not authenticated
        else {
            self.isLoggedIn = .signedOut
        }
    }
    
//    func getTutorialStatus() {
//        /// Reads whether the user has completed the tutorial, and udpates the observable object in the session
//
//        if self.user.uid != nil {
//            Firestore.firestore().collection(UserSettings.name).document(self.user.uid!).getDocument(
//                completion: { data, error in
//
//                    print("READ K")
//                    guard let data = data?.data() else {
//
//                        // Could not read the data, so just show the user the tutorial
//                        self.isTutorialCompleted = false
//                        return
//                    }
//
//                    if data[UserSettings.fields.TUTORIAL_COMPLETED] != nil {
//                    self.isTutorialCompleted = data[UserSettings.fields.TUTORIAL_COMPLETED] as? Bool ?? false
//                }
//                    else {
//                        // Could not read the data or it wasn't there. Show the user the tutorial
//                        self.isTutorialCompleted = false
//                    }
//                }
//            )
//        }
//
//        else {
//            self.isTutorialCompleted = false
//        }
//    }
    
    func signOut () {
        self.db.collection(Users.name).document(self.user.user!.uid).updateData(["tokens": FieldValue.arrayRemove([Messaging.messaging().fcmToken ?? ""])], completion: {
            error in
            if error == nil {
                self.deAuth()
            }
        })
    }
    
    func deAuth() {
        let locationManager = CLLocationManager()
        do {
            try Auth.auth().signOut()
            self.loginManager.logOut()
            self.isLoggedIn = .signedOut
            GIDSignIn.sharedInstance.signOut()
            UIApplication.shared.unregisterForRemoteNotifications()
            locationManager.stopMonitoringSignificantLocationChanges()
        }
        catch {
            self.db.collection(Users.name).document(self.user.user!.uid).updateData([Users.fields.TOKENS: FieldValue.arrayUnion([Messaging.messaging().fcmToken ?? ""])])
            self.isLoggedIn = .signedIn
            self.loginManager.logIn()
            locationManager.startMonitoringSignificantLocationChanges()
            UIApplication.shared.registerForRemoteNotifications()
        }
    }
    
    func facebookLogin(authWorkflow: Bool) {
        self.loginManager.logIn(permissions: ["email"], from: nil) { (loginResult, error) in
            self.signInError = error?.localizedDescription ?? ""
            if error == nil {
                if loginResult?.isCancelled == false {
                    let credential = FacebookAuthProvider.credential(withAccessToken: AccessToken.current!.tokenString)
                    if authWorkflow {
                        self.firebaseAuthWorkflow(credential: credential)
                    }
                }
            }
            else {
                // There was an error signing in
            }
        }
    }
    
    func googleLogin(authWorkflow: Bool) {
        guard let clientID = FirebaseApp.app()?.options.clientID else { return }
        
        // Create Google Sign In configuration object.
        let config = GIDConfiguration(clientID: clientID)
        
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        guard let rootViewController = windowScene.windows.first?.rootViewController else { return }
        
        // Start the sign in flow!
        GIDSignIn.sharedInstance.signIn(with: config, presenting: rootViewController) { [unowned self] user, error in

          if let error = error {
              self.signInError = error.localizedDescription
              return
          }

          guard
            let authentication = user?.authentication,
            let idToken = authentication.idToken
          else {
              return
          }
            let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: authentication.accessToken)
            if authWorkflow {
                firebaseAuthWorkflow(credential: credential)
            }
          return
        }
    }
        
    func firebaseAuthWorkflow(credential: FirebaseAuth.AuthCredential) {
        Auth.auth().signIn(with: credential) { (authResult, error) in
            if error == nil && authResult != nil {
                    UIApplication.shared.registerForRemoteNotifications()
                    self.signInError = error?.localizedDescription ?? ""
                    let user = authResult!.user
                    let docRef = self.db.collection(Users.name).document(user.uid)
                    docRef.getDocument { (document, docError) in
                            print("READ N")
                    
                    // Set the user profile data initialized to nil
                    self.profileInformation = UserCardData(
                        uid: self.user.uid!,
                        name: nil,
                        age: nil,
                        photoURL: nil,
                        relationshipStatus: nil,
                        occupation: nil,
                        instagramUsername: nil
                    )
                    
                    // User already exists
                    if let document = document, document.exists {
                        // Sync the existing user information
                        self.profileInformation?.syncReadProfileInfo()
                        
                        // Show the user the home screen
                        self.isLoggedIn = .signedIn
                        self.addToken()
                    }
                        
                    // User's settings need to be initialized in the Firebase
                    else {
                        print("Creating new User")
                        let user_settings = self.db.collection(Users.name).document(String(user.uid))
                        
                        // Update session to show tutorial completed is false
                        //self.isTutorialCompleted = false
                        
                        // Set the initial datafields
                        user_settings.setData([
                            Users.fields.TUTORIAL_COMPLETED: false,
                            Users.fields.LEGAL_AGREEMENT: Timestamp.init(),
                            Users.fields.TOKENS: [Messaging.messaging().fcmToken ?? ""]
                        ])
        
                        // Finally, show the user the home screen
                        self.isLoggedIn = .signedIn
                    
                    }
                }
            }
        }
    }
    
    func unbind () {
            if let handle = handle {
                Auth.auth().removeStateDidChangeListener(handle)
            }
        }
        
    deinit {
        unbind()
    }
    
    func addToken() {
        let token = Messaging.messaging().fcmToken ?? ""
        if token != "" && self.isLoggedIn == .signedIn && self.user.uid != nil {
        self.db.collection(Users.name).document(String(self.user.uid!)).updateData([Users.fields.TOKENS: FieldValue.arrayUnion([token])])
        }
    }
}

/**
 Contains all of the users unique information so that authentication can be checked and the user can configure their settings in firebase
     - Parameters:
        -db: Connection to Firestore
        -uid:User's firebase defined unique identifier
        -user: The firebase User object
 */
class User: ObservableObject {
    @Published var uid: String? = nil
    @Published var user: FirebaseAuth.User? = Auth.auth().currentUser ?? nil
    
    init() {
        self.user?.reload(completion: {error in })
        
        if self.user != nil {
            self.uid = self.user?.uid
        }
        
        else {
            self.user = nil
            self.uid = nil
        }
        
        Auth.auth().addStateDidChangeListener { auth, user in
            if let user = user {
                self.user = user
                self.uid = user.uid
            }
            
            else {
                self.user = nil
                self.uid = nil
            }
        }
    }
}
