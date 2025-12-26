//
//  SplashView.swift
//  RemoteTVController
//
//  Created by b on 26.12.2025.
//

import SwiftUI

struct SplashView: View {
    var body: some View {
        ZStack {
            Color(hex: "#15141C")
                .ignoresSafeArea()
            
            VStack {
                Spacer()
                
                Image(.splashIcon)
                
                Spacer()
                
                ProgressView()
                    .progressViewStyle(
                        CircularProgressViewStyle(tint: Color.blue)
                    )
                    .scaleEffect(1.1)
                    .padding(.bottom, 40)
            }
        }
    }
}

