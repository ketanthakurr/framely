import SwiftUI

// MARK: - Brand

enum Brand {
    static let coral = Color(hex: "#FF8A7A")
    static let lavender = Color(hex: "#A18CD1")
    static let mint = Color(hex: "#6FD6C5")
    static let gold = Color(hex: "#FFD36E")
    static let ink = Color(hex: "#0E0F1A")

    static let gradient = LinearGradient(colors: [coral, lavender, mint], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let proGradient = LinearGradient(colors: [gold, coral], startPoint: .topLeading, endPoint: .bottomTrailing)

    /// Display titles. The size is the default; it follows the user's text size (capped, so
    /// accessibility sizes don't blow a 30pt title up to 100pt).
    static func title(_ size: CGFloat = 34) -> Font {
        let scaled = UIFontMetrics(forTextStyle: .title1).scaledValue(for: size)
        return .system(size: min(scaled, size * 1.5), weight: .bold, design: .rounded)
    }
    static let headline = Font.system(.headline, design: .rounded)
    static let body = Font.system(.body, design: .rounded)
    static let caption = Font.system(.caption, design: .rounded).weight(.medium)

    // Both settle without overshoot — motion should confirm a change, not show off.
    static let spring = Animation.spring(response: 0.35, dampingFraction: 0.9)
    static let bouncy = Animation.spring(response: 0.3, dampingFraction: 0.85)
}

// MARK: - Glass

/// Liquid Glass on iOS 26+, frosted material with a light rim on iOS 17–25.
struct GlassBackground<S: InsettableShape>: ViewModifier {
    var shape: S
    var interactive = false
    var tint: Color? = nil

    func body(content: Content) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            content.glassEffect(glass, in: shape)
        } else {
            fallback(content)
        }
        #else
        fallback(content)
        #endif
    }

    #if compiler(>=6.2)
    @available(iOS 26.0, *)
    private var glass: Glass {
        var g = Glass.regular
        if let tint { g = g.tint(tint.opacity(0.35)) }
        if interactive { g = g.interactive() }
        return g
    }
    #endif

    private func fallback(_ content: Content) -> some View {
        content
            .background {
                ZStack {
                    shape.fill(.ultraThinMaterial)
                    if let tint { shape.fill(tint.opacity(0.18)) }
                }
            }
            .overlay {
                shape.strokeBorder(
                    LinearGradient(colors: [.white.opacity(0.45), .white.opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 0.8
                )
            }
            .shadow(color: .black.opacity(0.12), radius: 16, y: 8)
    }
}

extension View {
    func glass(cornerRadius: CGFloat = 24, interactive: Bool = false, tint: Color? = nil) -> some View {
        modifier(GlassBackground(shape: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous), interactive: interactive, tint: tint))
    }

    func glassCapsule(interactive: Bool = false, tint: Color? = nil) -> some View {
        modifier(GlassBackground(shape: Capsule(), interactive: interactive, tint: tint))
    }

    func glassCircle(interactive: Bool = true) -> some View {
        modifier(GlassBackground(shape: Circle(), interactive: interactive))
    }
}

// MARK: - Buttons

/// Big gradient call-to-action with a subtle press.
struct PrimaryButtonStyle: ButtonStyle {
    var gradient: LinearGradient = Brand.gradient

    func makeBody(configuration: Configuration) -> some View {
        PrimaryButtonBody(configuration: configuration, gradient: gradient)
    }
}

/// Separate view so it can read `isEnabled`: a disabled button must look disabled.
private struct PrimaryButtonBody: View {
    let configuration: ButtonStyle.Configuration
    let gradient: LinearGradient
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        configuration.label
            .font(.system(.headline, design: .rounded))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
            .background(gradient, in: Capsule())
            .overlay { Capsule().strokeBorder(.white.opacity(0.3), lineWidth: 1) }
            .shadow(color: Brand.lavender.opacity(0.45), radius: configuration.isPressed ? 6 : 16, y: configuration.isPressed ? 3 : 8)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(isEnabled ? 1 : 0.45)
            .animation(Brand.bouncy, value: configuration.isPressed)
    }
}

/// Subtle press for cards and tiles.
struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .brightness(configuration.isPressed ? -0.03 : 0)
            .animation(Brand.bouncy, value: configuration.isPressed)
    }
}

// MARK: - Wordmark

/// The "Framely" logo text. Uses deep ink tones on light backgrounds and soft white on dark,
/// so it stays readable on the pastel/pink gradients (the bright brand gradient is kept for the icon).
struct Wordmark: View {
    var size: CGFloat = 38
    @Environment(\.colorScheme) private var scheme

    private var textStyle: LinearGradient {
        scheme == .dark
            ? LinearGradient(colors: [.white, Color(hex: "#E4DDFF")], startPoint: .top, endPoint: .bottom)
            : LinearGradient(colors: [Color(hex: "#1F1638"), Color(hex: "#4B2E8A")], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var body: some View {
        HStack(spacing: size * 0.28) {
            ArchMark(height: size * 1.25)
                .shadow(color: Brand.ink.opacity(0.3), radius: 6, y: 3)

            Text("Framely")
                .font(.system(size: size, weight: .heavy, design: .rounded))
                .tracking(-0.5)
                .foregroundStyle(textStyle)
                // A soft halo separates the letters from busy, bright backgrounds.
                .shadow(color: (scheme == .dark ? Color.black : Color.white).opacity(0.7), radius: 6)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Framely")
        .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Arch mark (the app icon, drawn as vectors)

/// Arch with a round top and softly rounded bottom corners — the shape of the app icon's frame.
struct ArchShape: Shape {
    /// Bottom corner radius as a fraction of the width.
    var corner: CGFloat = 0.095

    func path(in r: CGRect) -> Path {
        let rad = r.width / 2
        let c = r.width * corner
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY + rad))
        p.addArc(center: CGPoint(x: r.midX, y: r.minY + rad), radius: rad, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY - c))
        p.addQuadCurve(to: CGPoint(x: r.maxX - c, y: r.maxY), control: CGPoint(x: r.maxX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX + c, y: r.maxY))
        p.addQuadCurve(to: CGPoint(x: r.minX, y: r.maxY - c), control: CGPoint(x: r.minX, y: r.maxY))
        p.closeSubpath()
        return p
    }
}

/// The Framely logo: a cream arch frame around a sunset. Geometry matches `Design/make-icon.swift`.
struct ArchMark: View {
    var height: CGFloat
    /// 0 = sun hidden behind the hills, 1 = fully risen. Animatable for the splash.
    var sunProgress: CGFloat = 1

    private static let aspect: CGFloat = 420.0 / 640.0
    private static let sky = LinearGradient(
        stops: [
            .init(color: Color(hex: "#FF9E7D"), location: 0),
            .init(color: Color(hex: "#FF8A7A"), location: 0.35),
            .init(color: Color(hex: "#F27F9C"), location: 0.62),
            .init(color: Color(hex: "#B58BD6"), location: 1),
        ],
        startPoint: .top, endPoint: .bottom
    )

    var body: some View {
        let w = height * Self.aspect
        let inset = w * 32 / 420
        ZStack {
            ArchShape().fill(Color(hex: "#FBF6EE"))
            scene
                .clipShape(ArchShape(corner: 0.04))
                .padding(inset)
        }
        .frame(width: w, height: height)
        .accessibilityHidden(true)
    }

    private var scene: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let sunR = w * 0.208
            ZStack(alignment: .topLeading) {
                Self.sky
                Circle()
                    .fill(RadialGradient(colors: [Color(hex: "#FFE6A3").opacity(0.55), .clear], center: .center, startRadius: sunR * 0.8, endRadius: sunR * 2))
                    .frame(width: sunR * 4, height: sunR * 4)
                    .position(x: w / 2, y: h * 0.566 + (1 - sunProgress) * h * 0.4)
                    .opacity(sunProgress)
                Circle()
                    .fill(Color(hex: "#FFD36E"))
                    .frame(width: sunR * 2, height: sunR * 2)
                    .position(x: w / 2, y: h * 0.566 + (1 - sunProgress) * h * 0.4)
                Hill(start: 0.743, end: 0.677, c1: CGPoint(x: 0.185, y: 0.613), c2: CGPoint(x: 0.635, y: 0.8125))
                    .fill(Color(hex: "#8E7BC8"))
                Hill(start: 0.830, end: 0.8125, c1: CGPoint(x: 0.382, y: 0.934), c2: CGPoint(x: 0.635, y: 0.726))
                    .fill(LinearGradient(colors: [Color(hex: "#7FE0CF"), Color(hex: "#4FB9B0")], startPoint: .top, endPoint: .bottom))
            }
        }
    }

    /// A hill filled to the bottom edge; points are in unit coordinates of the window.
    private struct Hill: Shape {
        var start: CGFloat, end: CGFloat, c1: CGPoint, c2: CGPoint
        func path(in r: CGRect) -> Path {
            func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: r.minX + x * r.width, y: r.minY + y * r.height) }
            var p = Path()
            p.move(to: pt(0, start))
            p.addCurve(to: pt(1, end), control1: pt(c1.x, c1.y), control2: pt(c2.x, c2.y))
            p.addLine(to: pt(1, 1))
            p.addLine(to: pt(0, 1))
            p.closeSubpath()
            return p
        }
    }
}

// MARK: - Small components

struct ProBadge: View {
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "crown.fill")
            Text("PRO")
        }
        .font(.system(.caption2, design: .rounded).weight(.heavy))
        .foregroundStyle(.black.opacity(0.75))
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Brand.proGradient, in: Capsule())
    }
}

struct SectionHeader: View {
    let title: String
    var subtitle: String? = nil
    var trailing: AnyView? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(.title3, design: .rounded).weight(.bold))
                if let subtitle {
                    Text(subtitle).font(Brand.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            trailing
        }
    }
}

/// Chip used in horizontal pickers (intervals, frames, filters).
struct ChoiceChip: View {
    let title: String
    var symbol: String? = nil
    let selected: Bool
    var locked = false

    var body: some View {
        HStack(spacing: 6) {
            if let symbol { Image(systemName: symbol).font(.system(size: 13, weight: .semibold)) }
            Text(title).font(.system(.subheadline, design: .rounded).weight(.semibold))
            if locked { Image(systemName: "lock.fill").font(.caption2).opacity(0.7) }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(minHeight: 44)
        .foregroundStyle(selected ? .white : .primary)
        .background {
            if selected {
                Capsule().fill(Brand.gradient)
                    .shadow(color: Brand.lavender.opacity(0.5), radius: 8, y: 4)
            }
        }
        .glassCapsule(interactive: true)
        .animation(Brand.spring, value: selected)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityHint(locked ? "Requires Framely Pro" : "")
    }
}
