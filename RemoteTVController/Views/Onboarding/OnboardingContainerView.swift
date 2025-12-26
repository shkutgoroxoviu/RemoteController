//
//  OnboardingContainerView.swift
//  RemoteTVController
//

import SwiftUI

struct OnboardingContainerView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = OnboardingViewModel(
        startPage: UserDefaults.standard.integer(forKey: "onboarding_page")
    )
    @State private var showRestoreAlert: Bool = false
    @State private var restoreMessage: String = ""
    
    var body: some View {
        ZStack {
            TabView(selection: $viewModel.currentPage) {
                ForEach(viewModel.pages) { page in
                    OnboardingPageView(page: page).tag(page.id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.3), value: viewModel.currentPage)
            
            VStack {
                Spacer()

                HStack(spacing: 8) {
                    ForEach(0..<viewModel.pages.count, id: \.self) { i in
                        Circle()
                            .fill(i == viewModel.currentPage ? Color.white : Color.white.opacity(0.3))
                            .frame(width: 8, height: 8)
                    }
                }
                .padding(.bottom, 8)

                VStack(spacing: 24) {
                    OnboardingPageContent(page: viewModel.currentPageData)
                    
                    PrimaryButton(title: viewModel.currentPageData.buttonTitle, style: .filled) {
                        if viewModel.currentPage == 1 {
                            viewModel.requestIDFAPermission()
                        }
                        if viewModel.isLastPage {
                            viewModel.completeOnboarding()
                            appState.completeOnboarding()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                appState.triggerPaywall(for: .onboarding)
                            }
                        } else {
                            viewModel.nextPage()
                            appState.currentOnboardingPage = viewModel.currentPage
                        }
                    }
                    .padding(.horizontal, 24)
                    HStack(spacing: 4) {
                        Link("Terms of Use", destination: URL(string: "https://example.com/terms")!)
                        Text("|").foregroundColor(.white.opacity(0.3))
                        Link("Privacy Policy", destination: URL(string: "https://example.com/privacy")!)
                        Text("|").foregroundColor(.white.opacity(0.3))
                        Button("Restore") {
                            SubscriptionManager.shared.restorePurchases(completion: { isSucces, text in
                                restoreMessage = text ?? ""
                                showRestoreAlert = true
                            })
                        }
                    }
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.5))
                }
                .padding(.top, 32)
                .padding(.bottom, 40)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedCorner(radius: 24, corners: [.topLeft, .topRight])
                        .fill(Color(hex: "1F1E26"))
                )
            }
            .ignoresSafeArea()
        }
        .alert("Restore Purchase", isPresented: $showRestoreAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(restoreMessage)
        }
        .ignoresSafeArea()
    }
}

struct OnboardingPageContent: View {
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: 16) {
            Text(page.title)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)

            Text(page.description)
                .font(.system(size: 15))
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
        }
    }
}

struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        VStack {
            Spacer()
            illustration
                .ignoresSafeArea()
            Spacer()
        }
        .ignoresSafeArea()
    }

    @ViewBuilder
    private var illustration: some View {
        switch page.id {
        case 0: Image("welcome").resizable().ignoresSafeArea()
        case 1: Image("connecting").resizable().ignoresSafeArea()
        case 2: Image("find").resizable().ignoresSafeArea()
        case 3: Image("loved").resizable().ignoresSafeArea()
        default: EmptyView()
        }
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = 24
    var corners: UIRectCorner = [.topLeft, .topRight]

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
