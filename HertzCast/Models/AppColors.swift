import SwiftUI

extension HertzSettings {
    // Bright accent — green in dark mode, red in light mode
    var schemeColor: Color {
        isLight ? Color(red: 1.00, green: 0.30, blue: 0.25)
                : Color(red: 0.18, green: 0.95, blue: 0.55)
    }

    // Mid tone
    var schemeMid: Color {
        isLight ? Color(red: 0.80, green: 0.15, blue: 0.12)
                : Color(red: 0.06, green: 0.73, blue: 0.51)
    }

    // Glow / shadow — absent in Light mode
    var schemeGlow: Color { isLight ? .clear : schemeMid.opacity(0.6) }

    // Very dark tinted gradient — active button/handle bg (top)
    var schemeDarkTop: Color {
        isLight ? Color(red: 0.18, green: 0.06, blue: 0.06)
                : Color(red: 0.07, green: 0.16, blue: 0.12)
    }

    // Very dark tinted gradient — active button/handle bg (bottom)
    var schemeDarkBottom: Color {
        isLight ? Color(red: 0.10, green: 0.03, blue: 0.03)
                : Color(red: 0.03, green: 0.09, blue: 0.07)
    }

    // Very dim — inactive LCD labels, borders, placeholders
    var schemeLcdDim: Color {
        isLight ? Color(red: 0.28, green: 0.10, blue: 0.10)
                : Color(red: 0.15, green: 0.35, blue: 0.22)
    }

    // MARK: — Theme-aware colors

    var appBackground: Color { isLight ? .white : Color(white: 0.08) }
    var appSurface: Color    { isLight ? Color(white: 0.96) : Color(white: 0.12) }
    var appDivider: Color    { isLight ? Color(white: 0.85) : Color(white: 0.18) }
    var appText: Color       { isLight ? Color(white: 0.10) : .white }
    var appTextDim: Color    { isLight ? Color(white: 0.50) : Color(white: 0.40) }
}
