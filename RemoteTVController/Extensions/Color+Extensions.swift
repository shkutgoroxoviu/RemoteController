//
//  Color+Extensions.swift
//  RemoteTVController
//

import SwiftUI

extension Color {
    static let appBackground = Color.black
    static let cardBackground = Color(white: 0.1)
    static let buttonBackground = Color(white: 0.15)
    
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
}

extension UIColor {
    /// Цвет от hex значения, пример UIColor(hexValue: 0xFFFFFF)
    /// - Parameter hexValue: цвет в x16 формате 0xFFFFFF
    /// - Description: UIColor(hexValue: 0xFFFFFF)
    convenience init(hexValue: UInt32) {
        let red: CGFloat = CGFloat((hexValue & 0x00FF0000) >> 16) / 255.0
        let green: CGFloat = CGFloat((hexValue & 0x0000FF00) >> 8) / 255.0
        let blue: CGFloat = CGFloat(hexValue & 0x000000FF) / 255.0
        self.init(red: red, green: green, blue: blue, alpha: 1.0)
    }
    
    convenience init(light: UIColor, dark: UIColor){
        self.init { trait in
            if case .dark = trait.userInterfaceStyle {
                return dark
            }
            return light
        }
    }
}


