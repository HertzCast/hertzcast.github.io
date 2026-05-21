import SwiftUI

extension HertzSettings {
    // Bright accent — text, LED dot fill, active labels
    var schemeColor: Color {
        switch colorScheme {
        case "red":    return Color(red: 1.00, green: 0.30, blue: 0.25)
        case "orange": return Color(red: 1.00, green: 0.60, blue: 0.10)
        case "yellow": return Color(red: 1.00, green: 0.95, blue: 0.15)
        case "blue":   return Color(red: 0.25, green: 0.75, blue: 1.00)
        default:       return Color(red: 0.18, green: 0.95, blue: 0.55)
        }
    }

    // Mid tone — fills, bars, glow sources
    var schemeMid: Color {
        switch colorScheme {
        case "red":    return Color(red: 0.80, green: 0.15, blue: 0.12)
        case "orange": return Color(red: 0.80, green: 0.42, blue: 0.05)
        case "yellow": return Color(red: 0.75, green: 0.68, blue: 0.05)
        case "blue":   return Color(red: 0.10, green: 0.52, blue: 0.88)
        default:       return Color(red: 0.06, green: 0.73, blue: 0.51)
        }
    }

    // Glow / shadow
    var schemeGlow: Color { schemeMid.opacity(0.6) }

    // Very dark tinted gradient — active button/handle bg (top)
    var schemeDarkTop: Color {
        switch colorScheme {
        case "red":    return Color(red: 0.18, green: 0.06, blue: 0.06)
        case "orange": return Color(red: 0.18, green: 0.10, blue: 0.03)
        case "yellow": return Color(red: 0.17, green: 0.15, blue: 0.03)
        case "blue":   return Color(red: 0.05, green: 0.10, blue: 0.20)
        default:       return Color(red: 0.07, green: 0.16, blue: 0.12)
        }
    }

    // Very dark tinted gradient — active button/handle bg (bottom)
    var schemeDarkBottom: Color {
        switch colorScheme {
        case "red":    return Color(red: 0.10, green: 0.03, blue: 0.03)
        case "orange": return Color(red: 0.10, green: 0.06, blue: 0.02)
        case "yellow": return Color(red: 0.09, green: 0.08, blue: 0.02)
        case "blue":   return Color(red: 0.03, green: 0.06, blue: 0.12)
        default:       return Color(red: 0.03, green: 0.09, blue: 0.07)
        }
    }

    // Very dim — inactive LCD labels, borders, placeholders
    var schemeLcdDim: Color {
        switch colorScheme {
        case "red":    return Color(red: 0.28, green: 0.10, blue: 0.10)
        case "orange": return Color(red: 0.26, green: 0.14, blue: 0.06)
        case "yellow": return Color(red: 0.24, green: 0.22, blue: 0.06)
        case "blue":   return Color(red: 0.08, green: 0.14, blue: 0.30)
        default:       return Color(red: 0.15, green: 0.35, blue: 0.22)
        }
    }
}
