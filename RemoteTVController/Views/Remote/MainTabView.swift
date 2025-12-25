//
//  MainTabView.swift
//  RemoteTVController
//

import SwiftUI

struct MainTabView: View {
    @State private var selectedTab: Tab = .remote
    
    enum Tab { case remote, devices, settings }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack { RemoteView() }
                .tabItem {
                    Image(systemName: "appletvremote.gen4")
                    Text("Remote")
                }
                .tag(Tab.remote)
            
            NavigationStack { DevicesListView() }
                .tabItem {
                    Image(systemName: "tv")
                    Text("Devices")
                }
                .tag(Tab.devices)
            
            NavigationStack { SettingsView() }
                .tabItem {
                    Image(systemName: "gearshape")
                    Text("Settings")
                }
                .tag(Tab.settings)
        }
        .tint(.white)
    }
}


