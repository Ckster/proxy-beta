//
//  SignInWithApple.swift
//  proxy_beta
//
//  Created by Erick Verleye on 7/5/22.
//

import SwiftUI
import AuthenticationServices


struct SignInWithApple: UIViewRepresentable {
    var style: ASAuthorizationAppleIDButton.Style

      func makeUIView(context: Context) -> ASAuthorizationAppleIDButton {
        let appleButton = ASAuthorizationAppleIDButton(type: .continue, style: style)
        
        return appleButton
      }

      func updateUIView(_ uiView: ASAuthorizationAppleIDButton, context: Context) {}
}
