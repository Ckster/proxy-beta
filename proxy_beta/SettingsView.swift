//
//  SettingsView.swift
//  proxy_beta
//
//  Created by Erick Verleye on 10/4/22.
//

import SwiftUI
import FirebaseAuth

struct SettingsView: View {
    @EnvironmentObject var session: SessionStore
    @State var errorText: String = ""
    @State var showingSignOut: Bool = false
    
    var body: some View {
        let signOutAlert: Alert = Alert(title: Text("Sign Out"), message: Text("Sign Out?"), primaryButton: .default(Text("Sign Out"), action: {
            Auth.auth().currentUser?.reload(completion: { error in
                if error == nil {
                    self.session.signOut()
                }
                else {
                    self.errorText = error!.localizedDescription
                }
            })
        }), secondaryButton: .default(Text("Cancel")))
        
        GeometryReader {
            geometry in
            ZStack {
                // Sign out button
                Button(action: {
                    self.showingSignOut = true
                }) {
                    Text("Sign Out").font(.system(size: 25)).bold().frame(width: geometry.size.width * 0.50).padding()
                }.alert(isPresented: $showingSignOut) {
                   signOutAlert
                }.background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color("Cyan")))
                    .frame(width: geometry.size.width, height: geometry.size.height, alignment: .center)
                
                if self.errorText != "" {
                    ErrorView(errorText: $errorText)
                }
            }
        }
    }
}

/**
 Displays any errors to the user
    - Parameters:
        -errorText: The error to display
 */
struct ErrorView: View {
    @Binding var errorText: String
    
    var body: some View {
        Text(self.errorText).font(.system(size: 18)).padding().onAppear(perform: {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: {
                self.errorText = ""
            })
        })
    }
}

