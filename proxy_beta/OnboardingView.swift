//
//  OnboardingView.swift
//  proxy_beta
//
//  Created by Erick Verleye on 7/9/22.
//

import SwiftUI
import Firebase
import FirebaseFirestore

struct OnboardingView: View {
    @EnvironmentObject var session: SessionStore
    @State var name: String = ""
    var db = Firestore.firestore()
    
    var body: some View {
        VStack {
            Text("Welcome, please fill in some information about yourself")
            if self.session.profileInformation!.name == nil {
                TextField("First Name: ", text: $name).disableAutocorrection(true)
            }
            
            Text("Done").onTapGesture {
                if self.name != "" {
                    self.session.profileInformation!.writeNewStringValue(attribute: &self.session.profileInformation!.name, firebaseRep: UsersFields.DISPLAY_NAME, newValue: self.name)
                }
                else {
                    Text("Please fill in the name field")
                }
            }
        }
    }
}

struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView()
    }
}
