//
//  ProxyApp.swift
//  proxy_beta
//
//  Created by Erick Verleye on 7/16/22.
//

import Foundation
import SwiftUI


@main
struct ProxyApp: App {
    @UIApplicationDelegateAdaptor var delegate: AppDelegate
    
    var body: some Scene {
            WindowGroup {
                ContentView().environmentObject(SessionStore())
        }
    }
}
