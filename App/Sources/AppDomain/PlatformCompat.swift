import SwiftUI

// MARK: - Cross-platform Color shims
//
// UIKit-based Color initialisers are unavailable on macOS.
// These static helpers pick the closest semantic equivalent per platform.

public extension Color {
    /// iOS: `UIColor.systemGroupedBackground`; macOS: `NSColor.windowBackgroundColor`
    static var platformGroupedBackground: Color {
        #if canImport(UIKit)
        Color(UIColor.systemGroupedBackground)
        #else
        Color(NSColor.windowBackgroundColor)
        #endif
    }

    /// iOS: `UIColor.secondarySystemGroupedBackground`; macOS: `NSColor.controlBackgroundColor`
    static var platformSecondaryGroupedBackground: Color {
        #if canImport(UIKit)
        Color(UIColor.secondarySystemGroupedBackground)
        #else
        Color(NSColor.controlBackgroundColor)
        #endif
    }

    /// iOS: `UIColor.tertiarySystemGroupedBackground`; macOS: `NSColor.underPageBackgroundColor`
    static var platformTertiaryGroupedBackground: Color {
        #if canImport(UIKit)
        Color(UIColor.tertiarySystemGroupedBackground)
        #else
        Color(NSColor.underPageBackgroundColor)
        #endif
    }
}

// MARK: - Cross-platform View modifiers

public extension View {
    /// Attaches a decimal keyboard on iOS; no-op on macOS (hardware keyboard only).
    @ViewBuilder func decimalKeyboard() -> some View {
        #if os(iOS)
        self.keyboardType(.decimalPad)
        #else
        self
        #endif
    }
}

// MARK: - Cross-platform View modifier helpers

public extension View {
    /// Applies `.navigationBarTitleDisplayMode(.inline)` on iOS; no-op on macOS.
    @ViewBuilder func inlineNavigationTitle() -> some View {
        #if os(iOS)
        self.navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }
}

// MARK: - Cross-platform ToolbarItemPlacement helpers

public extension ToolbarItemPlacement {
    /// Leading toolbar area on iOS (`topBarLeading`) and macOS (`navigation`).
    static var platformNavigationLeading: ToolbarItemPlacement {
        #if os(iOS)
        .topBarLeading
        #else
        .navigation
        #endif
    }

    /// Trailing toolbar area on iOS (`topBarTrailing`) and macOS (`primaryAction`).
    static var platformNavigationTrailing: ToolbarItemPlacement {
        #if os(iOS)
        .topBarTrailing
        #else
        .primaryAction
        #endif
    }
}
