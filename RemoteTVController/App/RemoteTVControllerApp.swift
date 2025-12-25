//
//  RemoteTVControllerApp.swift
//  RemoteTVController
//
//  Created for 5032 Remote TV Controller
//

import SwiftUI

@main
struct RemoteTVControllerApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @StateObject private var tvManager = TVConnectionManager.shared
    
    init() {
////        let mockServer = MockTVServer()
////        mockServer.start(port: 5555)
//        let emulatorDevice = TVDevice(
//            name: "Android TV Emulator",
//            ipAddress: "127.0.0.1", // здесь можно использовать идентификатор adb
//            brand: .tcl,
//            platform: .androidTV,
//            model: "Emulator-5554"
//        )
//        
//        // Добавляем его сразу в сохранённые устройства
//        TVConnectionManager.shared.addDevice(emulatorDevice)
        AnalyticsService.shared.initialize()
        SubscriptionManager.shared.initialize()
        AnalyticsService.shared.trackEvent(.appLaunched)
    }
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .environmentObject(subscriptionManager)
                .environmentObject(tvManager)
                .preferredColorScheme(.dark)
        }
    }
}


