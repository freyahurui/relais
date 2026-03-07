//
//  Color+Hex.swift
//  Sortie
//
//  Created on 2025-02-15.
//

import SwiftUI

// MARK: - Color Hex Extension

extension Color {

    /// Initialize a Color from a hex string
    /// - Parameter hex: The hex string (e.g., "#FF6B6B" or "FF6B6B")
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)

        let r, g, b: UInt64
        switch hex.count {
        case 6: // RGB (no alpha)
            (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        case 8: // ARGB
            (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: 1.0
        )
    }

    /// Initialize a Color from hex components
    /// - Parameters:
    ///   - red: Red component (0-255)
    ///   - green: Green component (0-255)
    ///   - blue: Blue component (0-255)
    ///   - alpha: Alpha component (0-1)
    init(red: Int, green: Int, blue: Int, alpha: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double(red) / 255,
            green: Double(green) / 255,
            blue: Double(blue) / 255,
            opacity: alpha
        )
    }

    /// Convert Color to hex string
    var hexString: String {
        guard let components = UIColor(self).cgColor.components, components.count >= 3 else {
            return "#000000"
        }

        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])

        return String(format: "#%02lX%02lX%02lX",
                      lroundf(r * 255),
                      lroundf(g * 255),
                      lroundf(b * 255))
    }
}

// MARK: - Predefined Colors

extension Color {
    /// Sortie app predefined colors
    enum Sortie {
        static let primary = Color(hex: "#FF6B6B")
        static let secondary = Color(hex: "#4ECDC4")
        static let background = Color(hex: "#1A1A2E")
        static let cardBackground = Color(hex: "#2A2A4A")
        static let textPrimary = Color.white
        static let textSecondary = Color(hex: "#9CA3AF")
        static let divider = Color(hex: "#3A3A5A")
        static let success = Color(hex: "#10B981")
        static let warning = Color(hex: "#F59E0B")
        static let error = Color(hex: "#EF4444")
    }
}

// MARK: - Color Utilities

extension Color {
    /// Lighten a color by a percentage
    /// - Parameter percent: The percentage to lighten (0-1)
    /// - Returns: A lighter color
    func lighten(by percent: Double) -> Color {
        var hue: Double = 0
        var saturation: Double = 0
        var brightness: Double = 0
        var alpha: Double = 0

        UIColor(self).getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)

        return Color(
            hue: hue,
            saturation: saturation,
            brightness: min(brightness + percent, 1.0),
            opacity: alpha
        )
    }

    /// Darken a color by a percentage
    /// - Parameter percent: The percentage to darken (0-1)
    /// - Returns: A darker color
    func darken(by percent: Double) -> Color {
        var hue: Double = 0
        var saturation: Double = 0
        var brightness: Double = 0
        var alpha: Double = 0

        UIColor(self).getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)

        return Color(
            hue: hue,
            saturation: saturation,
            brightness: max(brightness - percent, 0.0),
            opacity: alpha
        )
    }

    /// Get the complementary color
    var complementary: Color {
        var hue: Double = 0
        var saturation: Double = 0
        var brightness: Double = 0
        var alpha: Double = 0

        UIColor(self).getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)

        return Color(
            hue: (hue + 0.5).truncatingRemainder(dividingBy: 1.0),
            saturation: saturation,
            brightness: brightness,
            opacity: alpha
        )
    }
}

// MARK: - Color View Extensions

extension View {
    /// Apply a shadow with a specific color
    func shadow(color: Color, radius: CGFloat, x: CGFloat = 0, y: CGFloat = 0) -> some View {
        self.shadow(color: UIColor(color).withAlphaComponent(0.3), radius: radius, x: x, y: y)
    }

    /// Apply a glow effect
    func glow(color: Color, radius: CGFloat = 20) -> some View {
        self
            .shadow(color: color, radius: radius / 3)
            .shadow(color: color, radius: radius / 3)
            .shadow(color: color, radius: radius / 3)
    }
}

// MARK: - UIColor Color Space Extension

extension UIColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)

        let r, g, b, a: UInt64
        switch hex.count {
        case 6: // RGB (no alpha)
            (r, g, b, a) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF, 255)
        case 8: // ARGB
            (r, g, b, a) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF, (int >> 24) & 0xFF)
        default:
            (r, g, b, a) = (0, 0, 0, 255)
        }

        self.init(
            red: CGFloat(r) / 255,
            green: CGFloat(g) / 255,
            blue: CGFloat(b) / 255,
            alpha: CGFloat(a) / 255
        )
    }

    convenience init(red: Int, green: Int, blue: Int, alpha: Int = 255) {
        self.init(
            red: CGFloat(red) / 255,
            green: CGFloat(green) / 255,
            blue: CGFloat(blue) / 255,
            alpha: CGFloat(alpha) / 255
        )
    }

    var hexString: String {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0

        getRed(&r, green: &g, blue: &b, alpha: &a)

        return String(format: "#%02lX%02lX%02lX",
                      lroundf(Float(r * 255)),
                      lroundf(Float(g * 255)),
                      lroundf(Float(b * 255)))
    }
}

// MARK: - Preview

struct ColorHex_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            // Predefined colors
            HStack(spacing: 16) {
                ColorBox(name: "Primary", color: .Sortie.primary)
                ColorBox(name: "Secondary", color: .Sortie.secondary)
                ColorBox(name: "Background", color: .Sortie.background)
            }

            // Custom hex colors
            HStack(spacing: 16) {
                ColorBox(name: "#FF6B6B", color: Color(hex: "#FF6B6B"))
                ColorBox(name: "#4ECDC4", color: Color(hex: "#4ECDC4"))
                ColorBox(name: "#45B7D1", color: Color(hex: "#45B7D1"))
            }

            // Lightened and darkened colors
            VStack(spacing: 8) {
                Text("Lightened/Darkened")
                    .font(.headline)
                    .foregroundColor(.white)

                HStack(spacing: 16) {
                    ColorBox(name: "Original", color: Color(hex: "#FF6B6B"))
                    ColorBox(name: "Lighter", color: Color(hex: "#FF6B6B").lighten(by: 0.2))
                    ColorBox(name: "Darker", color: Color(hex: "#FF6B6B").darken(by: 0.2))
                }

                HStack(spacing: 16) {
                    ColorBox(name: "Original", color: Color(hex: "#4ECDC4"))
                    ColorBox(name: "Complementary", color: Color(hex: "#4ECDC4").complementary)
                }
            }
        }
        .padding()
        .background(Color.Sortie.background)
    }
}

struct ColorBox: View {
    let name: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            color
                .frame(width: 60, height: 60)
                .cornerRadius(12)

            Text(name)
                .font(.caption)
                .foregroundColor(.Sortie.textSecondary)
        }
    }
}
