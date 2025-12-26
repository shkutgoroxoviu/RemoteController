//
//  AppDelegate.swift
//  RemoteTVController
//
//  Created by b on 26.12.2025.
//

import UIKit
import ApphudSDK
import AppTrackingTransparency
import AdSupport

class AppDelegate: NSObject, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {

        Apphud.start(apiKey: "app_kiuRNi9rcQpztPwTaD7Qx2ehCm1qBb")
        Apphud.setDeviceIdentifiers(idfa: nil, idfv: UIDevice.current.identifierForVendor?.uuidString)

        return true
    }
}
