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

    static func title(_ size: CGFloat = 34) -> Font { .system(size: size, weight: .bold, design: .rounded) }
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
        configuration.label
            .font(.system(.headline, design: .rounded))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
            .background(gradient, in: Capsule())
            .overlay(Capsule().strokeBorder(.white.opacity(0.3), lineWidth: 1))
            .shadow(color: Brand.lavender.opacity(0.45), radius: configuration.isPressed ? 6 : 16, y: configuration.isPressed ? 3 : 8)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
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
            Image(systemName: "photo.stack.fill")
                .font(.system(size: size * 0.5, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: size * 1.05, height: size * 1.05)
                .background(Brand.gradient, in: RoundedRectangle(cornerRadius: size * 0.3, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: size * 0.3, style: .continuous).strokeBorder(.white.opacity(0.5), lineWidth: 1))
                .shadow(color: Brand.lavender.opacity(0.45), radius: 8, y: 4)

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

// MARK: - Small components

struct ProBadge: View {
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "crown.fill")
            Text("PRO")
        }
        .font(.system(size: 9, weight: .heavy, design: .rounded))
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
            if locked { Image(systemName: "lock.fill").font(.system(size: 10)).opacity(0.7) }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .foregroundStyle(selected ? .white : .primary)
        .background {
            if selected {
                Capsule().fill(Brand.gradient)
                    .shadow(color: Brand.lavender.opacity(0.5), radius: 8, y: 4)
            }
        }
        .glassCapsule(interactive: true)
        .animation(Brand.spring, value: selected)
    }
}
