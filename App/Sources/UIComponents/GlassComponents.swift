import Style
import SwiftUI

// MARK: - GPill
// Capsule-shaped glass surface. Optional `action` makes it tappable.

public struct GPill<Content: View>: View {
    @Environment(\.glassTokens) private var g
    private let content: Content
    private let intensity: Double
    private let action: (() -> Void)?

    public init(
        intensity: Double = 1.0,
        action: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.intensity = intensity
        self.action = action
        self.content = content()
    }

    public var body: some View {
        Group {
            if let action {
                Button(action: action) { inner }
                    .buttonStyle(PlainButtonStyle())
            } else {
                inner
            }
        }
    }

    private var inner: some View {
        content
            .foregroundStyle(g.ink)
            .glassBackground(cornerRadius: 999, intensity: intensity)
    }
}

// MARK: - GCard
// Rounded-rect glass card.

public struct GCard<Content: View>: View {
    @Environment(\.glassTokens) private var g
    private let content: Content
    private let cornerRadius: CGFloat
    private let intensity: Double
    private let tintOverride: Color?

    public init(
        cornerRadius: CGFloat = 22,
        intensity: Double = 1.0,
        tint: Color? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.intensity = intensity
        self.tintOverride = tint
        self.content = content()
    }

    public var body: some View {
        content
            .foregroundStyle(g.ink)
            .background {
                ZStack {
                    // Material blur
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.ultraThinMaterial)
                    // Base tint
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(tintOverride ?? g.tintColor)
                    // Top gloss
                    LinearGradient(
                        stops: [
                            .init(color: Color.white.opacity(g.sheen * intensity), location: 0),
                            .init(color: Color.white.opacity(g.sheenMid * intensity), location: 0.60),
                            .init(color: .clear, location: 1),
                        ],
                        startPoint: .top, endPoint: .bottom
                    )
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    // Edge
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(g.edgeColor, lineWidth: 0.5)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: g.shadowColor, radius: g.shadowRadius * 0.6, y: g.shadowY * 0.6)
    }
}

// MARK: - GButton

public enum GButtonTone: Sendable { case accent, neutral }
public enum GButtonSize: Sendable { case sm, md, lg }

public struct GButton: View {
    @Environment(\.glassTokens) private var g
    private let title: String
    private let icon: Image?
    private let tone: GButtonTone
    private let size: GButtonSize
    private let isFullWidth: Bool
    private let isDisabled: Bool
    private let action: () -> Void

    public init(
        _ title: String,
        icon: Image? = nil,
        tone: GButtonTone = .accent,
        size: GButtonSize = .lg,
        fullWidth: Bool = false,
        disabled: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.tone = tone
        self.size = size
        self.isFullWidth = fullWidth
        self.isDisabled = disabled
        self.action = action
    }

    private var height: CGFloat { size == .lg ? 52 : size == .md ? 40 : 32 }
    private var fontSize: CGFloat { size == .lg ? 17 : size == .md ? 15 : 13 }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon { icon }
                Text(title)
            }
            .font(.system(size: fontSize, weight: .semibold))
            .foregroundStyle(tone == .accent ? Color.white : g.ink)
            .frame(maxWidth: isFullWidth ? .infinity : nil)
            .frame(height: height)
            .padding(.horizontal, 22)
            .background { buttonBackground }
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.75 : 1)
    }

    @ViewBuilder
    private var buttonBackground: some View {
        ZStack {
            if isDisabled {
                Capsule()
                    .fill(g.isDark
                          ? Color(white: 0.47, opacity: 0.30)
                          : Color(white: 0.47, opacity: 0.22))
            } else if tone == .accent {
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [g.accentTop, g.accent, g.accentBot],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.45), .clear],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .frame(maxHeight: .infinity)
                    .clipShape(Capsule())
                    .allowsHitTesting(false)
            } else {
                Capsule().fill(.ultraThinMaterial)
                Capsule().fill(g.tintColor)
                Capsule().strokeBorder(g.edgeColor, lineWidth: 0.5)
            }
        }
    }
}

// MARK: - GSegmented

public struct GSegmented<Value: Hashable & Sendable>: View {
    @Environment(\.glassTokens) private var g
    private let options: [(label: String, value: Value)]
    @Binding private var selection: Value

    public init(
        selection: Binding<Value>,
        options: [(label: String, value: Value)]
    ) {
        self._selection = selection
        self.options = options
    }

    public var body: some View {
        HStack(spacing: 2) {
            ForEach(Array(options.enumerated()), id: \.0) { _, opt in
                let sel = opt.value == selection
                Button {
                    selection = opt.value
                } label: {
                    Text(opt.label)
                        .font(.system(size: 14, weight: sel ? .semibold : .medium))
                        .foregroundStyle(sel ? g.ink : g.muted)
                        .frame(maxWidth: .infinity)
                        .frame(height: 34)
                        .background {
                            if sel {
                                Capsule()
                                    .fill(g.isDark
                                          ? Color.white.opacity(0.16)
                                          : Color.white.opacity(0.92))
                                    .shadow(color: g.ringColor, radius: 3, y: 1)
                            }
                        }
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(3)
        .glassBackground(cornerRadius: 999, intensity: 0.85)
    }
}

// MARK: - GRadioList

public struct GRadioOption<Value: Hashable & Sendable>: Sendable {
    public let value: Value
    public let label: String
    public let detail: String?
    public init(value: Value, label: String, detail: String? = nil) {
        self.value = value; self.label = label; self.detail = detail
    }
}

public struct GRadioList<Value: Hashable & Sendable>: View {
    @Environment(\.glassTokens) private var g
    private let options: [GRadioOption<Value>]
    @Binding private var selection: Value

    public init(selection: Binding<Value>, options: [GRadioOption<Value>]) {
        self._selection = selection
        self.options = options
    }

    public var body: some View {
        GCard(cornerRadius: 16, intensity: 0.6) {
            VStack(spacing: 0) {
                ForEach(Array(options.enumerated()), id: \.0) { idx, opt in
                    if idx > 0 { GlassDivider() }
                    row(opt, isSelected: opt.value == selection)
                }
            }
        }
    }

    private func row(_ opt: GRadioOption<Value>, isSelected: Bool) -> some View {
        Button {
            selection = opt.value
        } label: {
            HStack(spacing: 12) {
                radioMark(isSelected: isSelected)
                Text(opt.label)
                    .font(.system(size: 16, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(g.ink)
                Spacer(minLength: 0)
                if let detail = opt.detail {
                    Text(detail)
                        .font(.system(size: 12.5, design: .monospaced))
                        .foregroundStyle(g.faint)
                }
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 13)
            .background(isSelected
                        ? (g.isDark ? Color.white.opacity(0.06) : Color.white.opacity(0.55))
                        : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
    }

    private func radioMark(isSelected: Bool) -> some View {
        ZStack {
            if isSelected {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [g.accentTop, g.accentBot],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .frame(width: 21, height: 21)
                    .shadow(color: g.accentGlow, radius: 5, y: 2)
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
            } else {
                Circle()
                    .strokeBorder(
                        g.isDark ? Color.white.opacity(0.35) : Color.black.opacity(0.28),
                        lineWidth: 1.5
                    )
                    .frame(width: 21, height: 21)
            }
        }
    }
}

// MARK: - GStepper

public struct GStepper: View {
    @Environment(\.glassTokens) private var g
    private let onDecrement: () -> Void
    private let onIncrement: () -> Void

    public init(onDecrement: @escaping () -> Void, onIncrement: @escaping () -> Void) {
        self.onDecrement = onDecrement
        self.onIncrement = onIncrement
    }

    public var body: some View {
        HStack(spacing: 0) {
            stepBtn(systemImage: "minus") { onDecrement() }
            GlassVDivider().frame(height: 18)
            stepBtn(systemImage: "plus")  { onIncrement() }
        }
        .frame(height: 38)
        .glassBackground(cornerRadius: 999, intensity: 0.7)
    }

    private func stepBtn(systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(g.ink)
                .frame(width: 52, height: 36)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
    }
}

// MARK: - GField

public struct GField: View {
    @Environment(\.glassTokens) private var g
    @Binding private var text: String
    private let suffix: String?
    private let isMono: Bool

    public init(_ text: Binding<String>, suffix: String? = nil, mono: Bool = true) {
        self._text = text
        self.suffix = suffix
        self.isMono = mono
    }

    public var body: some View {
        ZStack(alignment: .trailing) {
            GCard(cornerRadius: 12, intensity: 0.5) {
                TextField("", text: $text)
                    .font(.system(size: 16, design: isMono ? .monospaced : .default))
                    .foregroundStyle(g.ink)
                    .frame(height: 44)
                    .padding(.horizontal, 14)
                    .padding(.trailing, suffix != nil ? 36 : 0)
            }
            if let suffix {
                Text(suffix)
                    .font(.system(size: 14))
                    .foregroundStyle(g.faint)
                    .padding(.trailing, 14)
            }
        }
    }
}

// MARK: - GToggle

public struct GToggle: View {
    @Binding private var isOn: Bool
    public init(isOn: Binding<Bool>) { self._isOn = isOn }

    public var body: some View {
        Toggle("", isOn: $isOn)
            .labelsHidden()
            .toggleStyle(.switch)
    }
}

// MARK: - GChip

public struct GChip: View {
    @Environment(\.glassTokens) private var g
    private let color: Color
    private let label: String
    private let isActive: Bool
    private let action: () -> Void

    public init(color: Color, label: String, isActive: Bool = true, action: @escaping () -> Void) {
        self.color = color
        self.label = label
        self.isActive = isActive
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                RoundedRectangle(cornerRadius: 9)
                    .fill(color)
                    .frame(width: 18, height: 4)
                Text(label)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isActive ? g.ink : g.faint)
            }
            .padding(.leading, 9)
            .padding(.trailing, 12)
            .frame(height: 30)
            .glassBackground(cornerRadius: 999, intensity: 0.7)
            .opacity(isActive ? 1 : 0.5)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - GBanner

public enum GBannerTone: Sendable { case neutral, warn, danger }

public struct GBanner: View {
    @Environment(\.glassTokens) private var g
    private let tone: GBannerTone
    private let systemImage: String
    private let message: String

    public init(tone: GBannerTone = .neutral, systemImage: String, message: String) {
        self.tone = tone
        self.systemImage = systemImage
        self.message = message
    }

    private var fgColor: Color {
        switch tone {
        case .neutral: g.muted
        case .warn:    g.isDark ? Color(hex: 0xFFB55A) : Color(hex: 0xB8730A)
        case .danger:  g.isDark ? Color(hex: 0xFF8A7A) : Color(hex: 0xCC3322)
        }
    }

    private var bgColor: Color {
        switch tone {
        case .neutral: g.isDark ? Color.white.opacity(0.05) : Color.black.opacity(0.045)
        case .warn:    g.isDark ? Color(hex: 0xFF9628).opacity(0.12) : Color(hex: 0xF09614).opacity(0.13)
        case .danger:  g.isDark ? Color(hex: 0xFF503C).opacity(0.14) : Color(hex: 0xE63C28).opacity(0.12)
        }
    }

    public var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .medium))
            Text(message)
                .font(.system(size: 13.5, weight: .medium))
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(fgColor)
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(bgColor, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - GLabel (uppercase section header)

public struct GLabel: View {
    @Environment(\.glassTokens) private var g
    private let text: String
    public init(_ text: String) { self.text = text }

    public var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .kerning(0.5)
            .textCase(.uppercase)
            .foregroundStyle(g.faint)
            .padding(.horizontal, 4)
            .padding(.bottom, 8)
            .padding(.top, 2)
    }
}

// MARK: - GSheet (bottom sheet, iPhone-native)

public struct GSheet<Content: View>: View {
    @Environment(\.glassTokens) private var g
    @Binding private var isPresented: Bool
    private let title: String
    private let detent: PresentationDetent
    private let content: Content

    public init(
        isPresented: Binding<Bool>,
        title: String,
        detent: PresentationDetent = .fraction(0.75),
        @ViewBuilder content: () -> Content
    ) {
        self._isPresented = isPresented
        self.title = title
        self.detent = detent
        self.content = content()
    }

    public var body: some View {
        EmptyView()
            .sheet(isPresented: $isPresented) {
                VStack(alignment: .leading, spacing: 0) {
                    // Handle + title
                    HStack {
                        Text(title)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(g.ink)
                        Spacer()
                        Button {
                            isPresented = false
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(g.muted)
                                .frame(width: 30, height: 30)
                                .background(
                                    g.isDark ? Color.white.opacity(0.12) : Color.black.opacity(0.07),
                                    in: Circle()
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 8)

                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            content
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 32)
                    }
                }
                .background(
                    g.isDark ? Color(hex: 0x18191C).opacity(0.72) : Color(hex: 0xFCFDFF).opacity(0.70)
                )
                .background(.ultraThinMaterial)
                .presentationDetents([detent])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(26)
            }
    }
}

// MARK: - SwatchCluster

public struct SwatchCluster: View {
    @Environment(\.colorScheme) private var colorScheme
    private let tints: [CompartmentTint]
    private let maxShown: Int

    public init(tints: [CompartmentTint], maxShown: Int = 5) {
        self.tints = tints
        self.maxShown = maxShown
    }

    public var body: some View {
        HStack(spacing: -7) {
            ForEach(Array(tints.prefix(maxShown).enumerated()), id: \.0) { idx, tint in
                Circle()
                    .fill(tint.background(dark: colorScheme == .dark))
                    .overlay(
                        Circle()
                            .strokeBorder(
                                colorScheme == .dark ? Color(hex: 0x1A1B1E) : .white,
                                lineWidth: 1.5
                            )
                    )
                    .overlay(
                        Circle()
                            .strokeBorder(tint.border(dark: colorScheme == .dark), lineWidth: 0.5)
                    )
                    .frame(width: 22, height: 22)
                    .zIndex(Double(maxShown - idx))
            }
            if tints.count > maxShown {
                Text("+\(tints.count - maxShown)")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 6)
            }
        }
    }
}

// MARK: - GlassPanelRevealStrip (Xcode-style collapsed panel strip)

public struct GlassPanelRevealStrip: View {
    @Environment(\.glassTokens) private var g
    private let edge: HorizontalEdge
    private let action: () -> Void

    public init(edge: HorizontalEdge, action: @escaping () -> Void) {
        self.edge = edge
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Image(systemName: edge == .leading ? "chevron.right" : "chevron.left")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(g.accent)
                .frame(maxHeight: .infinity)
        }
        .buttonStyle(PlainButtonStyle())
        .frame(width: 26)
        .background(g.isDark ? Color.white.opacity(0.04) : Color.black.opacity(0.03))
    }
}

// MARK: - Linking flow banner

public struct GlassLinkingBanner: View {
    @Environment(\.glassTokens) private var g
    private let message: String
    private let onCancel: () -> Void

    public init(message: String, onCancel: @escaping () -> Void) {
        self.message = message
        self.onCancel = onCancel
    }

    public var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(g.accent)
            Text(message)
                .font(.system(size: 14.5, weight: .semibold))
                .foregroundStyle(g.ink)
            Spacer(minLength: 0)
            Button("Cancel", action: onCancel)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(g.accent)
                .buttonStyle(PlainButtonStyle())
                .padding(.horizontal, 8)
        }
        .padding(.leading, 14)
        .padding(.vertical, 12)
        .glassBackground(cornerRadius: 999, intensity: 0.9)
        .padding(.horizontal, 12)
    }
}
