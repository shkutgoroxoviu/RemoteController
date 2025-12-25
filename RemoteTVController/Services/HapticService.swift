//
//  HapticService.swift
//  RemoteTVController
//

import UIKit

final class HapticService {
    static let shared = HapticService()
    
    private let lightGenerator = UIImpactFeedbackGenerator(style: .light)
    private let mediumGenerator = UIImpactFeedbackGenerator(style: .medium)
    private let heavyGenerator = UIImpactFeedbackGenerator(style: .heavy)
    private let notificationGenerator = UINotificationFeedbackGenerator()
    
    private init() {
        lightGenerator.prepare()
        mediumGenerator.prepare()
        heavyGenerator.prepare()
        notificationGenerator.prepare()
    }
    
    func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        switch style {
        case .light: lightGenerator.impactOccurred(); lightGenerator.prepare()
        case .medium: mediumGenerator.impactOccurred(); mediumGenerator.prepare()
        case .heavy: heavyGenerator.impactOccurred(); heavyGenerator.prepare()
        default: mediumGenerator.impactOccurred()
        }
    }
    
    func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        notificationGenerator.notificationOccurred(type)
        notificationGenerator.prepare()
    }
    
    func remoteButtonPressed() { impact(.medium) }
    func remoteButtonSuccess() { notification(.success) }
    func remoteButtonError() { notification(.error) }
}


