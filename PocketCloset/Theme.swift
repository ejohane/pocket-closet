import SwiftUI

enum PCColor {
    static let primary = Color(red: 0.184, green: 0.463, blue: 0.337)
    static let primarySoft = Color(red: 0.89, green: 0.95, blue: 0.91)
    static let blue = Color(red: 0.33, green: 0.52, blue: 0.64)
    static let aqua = Color(red: 0.33, green: 0.63, blue: 0.61)
    static let yellow = Color(red: 0.74, green: 0.56, blue: 0.18)
    static let purple = Color(red: 0.51, green: 0.42, blue: 0.78)
    static let pink = Color(red: 0.72, green: 0.35, blue: 0.53)
    static let red = Color(red: 0.75, green: 0.23, blue: 0.15)

    static func token(_ token: String) -> Color {
        switch token {
        case "blue": blue
        case "aqua": aqua
        case "yellow": yellow
        case "purple": purple
        case "pink": pink
        case "red": red
        default: primary
        }
    }

    static let tokenCycle = ["green", "blue", "aqua", "yellow", "purple", "pink"]
}

extension ShapeStyle where Self == Color {
    static var pocketPrimary: Color { PCColor.primary }
}
