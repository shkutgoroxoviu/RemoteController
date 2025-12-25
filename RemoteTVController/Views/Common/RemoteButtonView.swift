//
//  RemoteButtonView.swift
//  RemoteTVController
//

import SwiftUI

struct RemoteButtonView: View {
    let button: RemoteButton
    let size: CGSize
    let action: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Rectangle()
                    .fill(button == .power ? Color.red.opacity(0.9) : Color(white: 0.2))
                    .frame(width: size.width, height: size.height)
                    .shadow(color: .black.opacity(0.3), radius: isPressed ? 2 : 4, y: isPressed ? 1 : 2)
                    .cornerRadius(40)
                
                Image(systemName: button.sfSymbol)
                    .font(.system(size: size.width * 0.4, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

struct NavigationPadView: View {
    let onButton: (RemoteButton) -> Void
    
    var body: some View {
        ZStack {
            Circle().fill(Color(hex: "1F1E26").opacity(0.35)).frame(width: 200, height: 200)
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [.gray, .gray.opacity(0.35)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
                .frame(width: 200, height: 200)
            
            Button { onButton(.ok) } label: {
                ZStack {
                    Circle().fill(Color(hex: "292830").opacity(0.35)).frame(width: 70, height: 70)
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [.gray, .gray.opacity(0.35)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                        .frame(width: 70, height: 70)
                    Text("OK").font(.system(size: 18, weight: .bold)).foregroundColor(.white)
                }
            }
            
            VStack {
                Button { onButton(.up) } label: {
                    Image(systemName: "chevron.up").font(.system(size: 24, weight: .semibold)).foregroundColor(.white).frame(width: 50, height: 50)
                }
                Spacer()
                Button { onButton(.down) } label: {
                    Image(systemName: "chevron.down").font(.system(size: 24, weight: .semibold)).foregroundColor(.white).frame(width: 50, height: 50)
                }
            }.frame(height: 200)
            
            HStack {
                Button { onButton(.left) } label: {
                    Image(systemName: "chevron.left").font(.system(size: 24, weight: .semibold)).foregroundColor(.white).frame(width: 50, height: 50)
                }
                Spacer()
                Button { onButton(.right) } label: {
                    Image(systemName: "chevron.right").font(.system(size: 24, weight: .semibold)).foregroundColor(.white).frame(width: 50, height: 50)
                }
            }.frame(width: 200)
        }
    }
}

