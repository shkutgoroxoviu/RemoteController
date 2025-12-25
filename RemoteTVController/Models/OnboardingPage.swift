//
//  OnboardingPage.swift
//  RemoteTVController
//

import Foundation

struct OnboardingPage: Identifiable {
    let id: Int
    let title: String
    let description: String
    let imageName: String
    let buttonTitle: String
    
    static let pages: [OnboardingPage] = [
        OnboardingPage(
            id: 0,
            title: "Welcome to Smart Remote",
            description: "Control any TV with your iPhone — quick & easy. Works with major TV brands.",
            imageName: "onboarding_welcome",
            buttonTitle: "CONTINUE"
        ),
        OnboardingPage(
            id: 1,
            title: "Connecting Your TV",
            description: "Ensure your iPhone and TV are connected to the same Wi-Fi.",
            imageName: "onboarding_wifi",
            buttonTitle: "CONTINUE"
        ),
        OnboardingPage(
            id: 2,
            title: "Find Your TV Automatically",
            description: "The app will scan your network and show available TVs.",
            imageName: "onboarding_search",
            buttonTitle: "CONTINUE"
        ),
        OnboardingPage(
            id: 3,
            title: "Loved by Our Users",
            description: "See what people are saying about their experience with Smart Remote.",
            imageName: "onboarding_reviews",
            buttonTitle: "GET STARTED"
        )
    ]
}


