//
//  PrimaryButton.swift
//  RemoteTVController
//

import SwiftUI

struct PrimaryButton: View {
    let title: String
    let style: Style
    var isLoading: Bool = false
    let action: () -> Void
    
    enum Style { case filled, outline, text }
    
    var body: some View {
        Button(action: action) {
            ZStack {
                if isLoading {
                    ProgressView().tint(textColor)
                } else {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(textColor)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(background)
            .cornerRadius(28)
            .overlay(RoundedRectangle(cornerRadius: 28).stroke(borderColor, lineWidth: style == .outline ? 1 : 0))
        }
        .disabled(isLoading)
    }
    
    private var background: Color {
        style == .filled ? .white : .clear
    }
    
    private var textColor: Color {
        style == .filled ? .black : .white
    }
    
    private var borderColor: Color {
        style == .outline ? .white.opacity(0.3) : .clear
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        VStack(spacing: 16) {
            PrimaryButton(title: "CONTINUE", style: .filled) {}
            PrimaryButton(title: "ADD TV", style: .outline) {}
        }.padding()
    }
}


