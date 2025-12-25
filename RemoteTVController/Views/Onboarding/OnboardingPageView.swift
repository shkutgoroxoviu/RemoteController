//
//  OnboardingPageView.swift
//  RemoteTVController
//
//import SwiftUI
//
//struct OnboardingPageView: View {
//    let page: OnboardingPage
//
//    var body: some View {
//        VStack(spacing: 0) {
//            Spacer()
//            illustration
//                .ignoresSafeArea()
//            Spacer()
//
//            VStack {
//                Text(page.title)
//                    .font(.system(size: 24, weight: .bold))
//                    .foregroundColor(.white)
//                    .multilineTextAlignment(.center)
//                    .padding(.horizontal, 32)
//
//                Text(page.description)
//                    .font(.system(size: 15))
//                    .foregroundColor(.white.opacity(0.7))
//                    .multilineTextAlignment(.center)
//                    .padding(.horizontal, 32)
//                    .padding(.top, 12)
//            }
//            .padding(.vertical, 24)
//            .frame(maxWidth: .infinity)
//            .background(
//                RoundedRectangle(cornerRadius: 16)
//                    .fill(Color(hex: "1F1E26").opacity(0.35))
//            )
//            .overlay(
//                RoundedRectangle(cornerRadius: 16)
//                    .strokeBorder(
//                        LinearGradient(
//                            colors: [.gray, .gray.opacity(0.35)],
//                            startPoint: .leading,
//                            endPoint: .trailing
//                        ),
//                        lineWidth: 2
//                    )
//            )
//        }
//        .ignoresSafeArea()
//    }
//
//    @ViewBuilder
//    private var illustration: some View {
//        switch page.id {
//        case 0: Image("welcome").resizable().ignoresSafeArea()
//        case 1: Image("connecting").resizable().ignoresSafeArea()
//        case 2: Image("find").resizable().ignoresSafeArea()
//        case 3: Image("loved").resizable().ignoresSafeArea()
//        default: EmptyView()
//        }
//    }
//}
