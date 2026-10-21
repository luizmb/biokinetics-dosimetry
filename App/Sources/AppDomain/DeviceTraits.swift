import Foundation

/// What the screen the app is on is like: the facts a layout depends on, as values.
///
/// They come from the world (`World.deviceTraits`), are kept in state, and reach a view only as
/// what its projection makes of them. No view asks the device: a view is what its state says.
public struct DeviceTraits: Sendable, Equatable, Hashable {
    /// Drawn dark: the appearance the system reports.
    public var isDark: Bool
    /// A narrow width (a phone held upright, a pad in a small split).
    public var isCompactWidth: Bool
    /// A short height (a phone on its side).
    public var isCompactHeight: Bool

    public init(isDark: Bool, isCompactWidth: Bool, isCompactHeight: Bool) {
        self.isDark = isDark
        self.isCompactWidth = isCompactWidth
        self.isCompactHeight = isCompactHeight
    }

    /// Before the world has said anything: light, a phone held upright. What the first frame
    /// draws in until the first report arrives a moment later.
    public static let initial = DeviceTraits(isDark: false, isCompactWidth: true, isCompactHeight: false)
}
