//
//  ContentView.swift
//  proxy_beta
//
//  Created by Erick Verleye on 7/5/22.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var session: SessionStore
    @State var showHomeScreen: Bool? = nil
    
    var body: some View {
            if self.session.isLoggedIn == .loading {
                Text("Loading")
            }

            if self.session.isLoggedIn == .signedIn {
                Group {
                    switch showHomeScreen {
                        case nil :
                            Text("Loading")
                            .onAppear(perform: {
                                self.session.profileInformation!.syncReadProfileInfo()
                            })
                        
                        case true :
                            TabView {
                                ProfileView().environmentObject(self.session)
                                    .tabItem {
                                        Label("Profile", systemImage: "person.crop.circle.fill")
                                    }
                                
                                HomeView(closeUserData: CloseUserData(uid: self.session.user.uid)).environmentObject(self.session)
                                    .tabItem {
                                        Label("Nearby", systemImage: "location.circle")
                                    }
                                
                                SettingsView().environmentObject(self.session)
                                    .tabItem {
                                        Label("Settings", systemImage: "gearshape")
                                    }
                                }.accentColor(Color("Cyan"))
                        case false :
                            OnboardingView().environmentObject(self.session)
                        default :
                            Text("Loading")
                        }
                    }.onReceive(self.session.profileInformation!.$minimumInfoObtained, perform: {
                        minInfo in
                        self.showHomeScreen = minInfo
                    })
                }

            if self.session.isLoggedIn == .signedOut {
                SignInView().environmentObject(self.session)
            }
    }
}
