import SwiftUI

// MARK: — KAIZENN Reusable Components

// MARK: KCard — Premium glassmorphic card
struct KCard<Content: View>: View {
    var elevated: Bool = false
    var padding: CGFloat = KTheme.Spacing.md
    let content: Content

    init(elevated: Bool = false, padding: CGFloat = KTheme.Spacing.md, @ViewBuilder content: () -> Content) {
        self.elevated = elevated
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: KTheme.Radius.lg)
                    .fill(elevated ? KTheme.Colors.cardElevated : KTheme.Colors.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: KTheme.Radius.lg)
                            .stroke(KTheme.Colors.border.opacity(0.5), lineWidth: 0.5)
                    )
            )
    }
}

// MARK: KButton — Primary CTA button
struct KButton: View {
    let title: String
    var style: Style = .primary
    var size: ButtonSize = .large
    var isLoading: Bool = false
    let action: () -> Void

    enum Style { case primary, secondary, ghost, danger }
    enum ButtonSize { case small, medium, large }

    var body: some View {
        Button(action: action) {
            HStack(spacing: KTheme.Spacing.sm) {
                if isLoading {
                    ProgressView().tint(.white).scaleEffect(0.8)
                }
                Text(title)
                    .font(size == .small ? KTheme.Typography.label : KTheme.Typography.headingSmall)
                    .foregroundColor(foregroundColor)
            }
            .frame(maxWidth: size == .small ? nil : .infinity)
            .frame(height: buttonHeight)
            .padding(.horizontal, size == .small ? KTheme.Spacing.md : 0)
            .background(backgroundView)
            .cornerRadius(size == .small ? KTheme.Radius.md : KTheme.Radius.lg)
        }
        .disabled(isLoading)
        .buttonStyle(KScaleButtonStyle())
    }

    private var buttonHeight: CGFloat {
        switch size {
        case .small: return 36
        case .medium: return 48
        case .large: return 56
        }
    }

    @ViewBuilder
    private var backgroundView: some View {
        switch style {
        case .primary:
            KTheme.Colors.brandGradient
        case .secondary:
            KTheme.Colors.card
                .overlay(RoundedRectangle(cornerRadius: KTheme.Radius.lg).stroke(KTheme.Colors.accentPrimary, lineWidth: 1))
        case .ghost:
            Color.clear
        case .danger:
            KTheme.Colors.danger.opacity(0.15)
                .overlay(RoundedRectangle(cornerRadius: KTheme.Radius.lg).stroke(KTheme.Colors.danger, lineWidth: 1))
        }
    }

    private var foregroundColor: Color {
        switch style {
        case .primary: return .white
        case .secondary: return KTheme.Colors.accentPrimary
        case .ghost: return KTheme.Colors.textSecondary
        case .danger: return KTheme.Colors.danger
        }
    }
}

// MARK: KProgressRing — Circular progress indicator
struct KProgressRing: View {
    let progress: Double
    let total: Double
    var size: CGFloat = 80
    var lineWidth: CGFloat = 8
    var color: Color = KTheme.Colors.accentPrimary
    var label: String? = nil

    private var percentage: Double { min(progress / total, 1.0) }

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.15), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: percentage)
                .stroke(
                    AngularGradient(
                        colors: [color, color.opacity(0.5)],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(KTheme.Animation.spring, value: percentage)
            if let label = label {
                Text(label)
                    .font(KTheme.Typography.caption)
                    .foregroundColor(KTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: KStatCard — Metric display card
struct KStatCard: View {
    let title: String
    let value: String
    let unit: String
    var trend: Double? = nil
    var color: Color = KTheme.Colors.accentPrimary
    var icon: String? = nil

    var body: some View {
        KCard {
            VStack(alignment: .leading, spacing: KTheme.Spacing.xs) {
                HStack {
                    if let icon = icon {
                        Image(systemName: icon)
                            .font(.caption)
                            .foregroundColor(color)
                    }
                    Text(title)
                        .font(KTheme.Typography.caption)
                        .foregroundColor(KTheme.Colors.textSecondary)
                    Spacer()
                    if let trend = trend {
                        TrendBadge(value: trend)
                    }
                }
                HStack(alignment: .lastTextBaseline, spacing: 3) {
                    Text(value)
                        .font(KTheme.Typography.displaySmall)
                        .foregroundColor(KTheme.Colors.textPrimary)
                    Text(unit)
                        .font(KTheme.Typography.caption)
                        .foregroundColor(KTheme.Colors.textSecondary)
                }
            }
        }
    }
}

// MARK: TrendBadge
struct TrendBadge: View {
    let value: Double
    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: value >= 0 ? "arrow.up.right" : "arrow.down.right")
                .font(.system(size: 9, weight: .bold))
            Text(String(format: "%.1f%%", abs(value)))
                .font(KTheme.Typography.caption)
        }
        .foregroundColor(value >= 0 ? KTheme.Colors.success : KTheme.Colors.danger)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            (value >= 0 ? KTheme.Colors.success : KTheme.Colors.danger).opacity(0.12)
                .cornerRadius(KTheme.Radius.sm)
        )
    }
}

// MARK: KBadge — Status / macro badge
struct KBadge: View {
    let text: String
    var color: Color = KTheme.Colors.accentPrimary

    var body: some View {
        Text(text)
            .font(KTheme.Typography.caption)
            .foregroundColor(color)
            .padding(.horizontal, KTheme.Spacing.sm)
            .padding(.vertical, KTheme.Spacing.xs)
            .background(color.opacity(0.15).cornerRadius(KTheme.Radius.sm))
    }
}

// MARK: KStreakBadge — Flame streak counter pill
struct KStreakBadge: View {
    let days: Int
    var color: Color = KTheme.Colors.accentAmber

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "flame.fill")
                .font(.system(size: 11, weight: .bold))
            Text("\(days)")
                .font(KTheme.Typography.caption.bold())
        }
        .foregroundColor(color)
        .padding(.horizontal, KTheme.Spacing.sm)
        .padding(.vertical, KTheme.Spacing.xs)
        .background(
            Capsule().fill(color.opacity(0.15))
        )
    }
}

// MARK: KSection — Section header
struct KSection<Content: View>: View {
    let title: String
    var trailing: AnyView? = nil
    let content: Content

    init(title: String, trailing: AnyView? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.trailing = trailing
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: KTheme.Spacing.md) {
            HStack {
                Text(title)
                    .font(KTheme.Typography.headingMedium)
                    .foregroundColor(KTheme.Colors.textPrimary)
                Spacer()
                trailing
            }
            content
        }
    }
}

// MARK: KScaleButtonStyle
struct KScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(KTheme.Animation.snappy, value: configuration.isPressed)
    }
}

// MARK: KTextField — Custom text field
struct KTextField: View {
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var icon: String? = nil
    var isSecure: Bool = false

    var body: some View {
        HStack(spacing: KTheme.Spacing.sm) {
            if let icon = icon {
                Image(systemName: icon)
                    .foregroundColor(KTheme.Colors.textSecondary)
                    .frame(width: 20)
            }
            if isSecure {
                SecureField(placeholder, text: $text)
            } else {
                TextField(placeholder, text: $text)
                    .keyboardType(keyboardType)
            }
        }
        .font(KTheme.Typography.bodyMedium)
        .foregroundColor(KTheme.Colors.textPrimary)
        .padding(KTheme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: KTheme.Radius.md)
                .fill(KTheme.Colors.card)
                .overlay(
                    RoundedRectangle(cornerRadius: KTheme.Radius.md)
                        .stroke(KTheme.Colors.border, lineWidth: 1)
                )
        )
    }
}

// MARK: GlowModifier
struct GlowModifier: ViewModifier {
    let color: Color
    let radius: CGFloat

    func body(content: Content) -> some View {
        content
            .shadow(color: color.opacity(0.4), radius: radius / 2)
            .shadow(color: color.opacity(0.2), radius: radius)
    }
}

extension View {
    func kGlow(color: Color, radius: CGFloat = 16) -> some View {
        modifier(GlowModifier(color: color, radius: radius))
    }

    func kBackground() -> some View {
        self.background(KTheme.Colors.background.ignoresSafeArea())
    }
}

// MARK: KEmptyState — consistent "nothing here yet" placeholder
struct KEmptyState: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: KTheme.Spacing.sm) {
            Image(systemName: icon).font(.system(size: 36)).foregroundColor(KTheme.Colors.textTertiary)
            Text(title).font(KTheme.Typography.headingSmall).foregroundColor(KTheme.Colors.textSecondary)
            Text(subtitle).font(KTheme.Typography.bodySmall).foregroundColor(KTheme.Colors.textTertiary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(KTheme.Spacing.xl)
        .background(KTheme.Colors.card.opacity(0.5).cornerRadius(KTheme.Radius.md))
    }
}

// MARK: FlowLayout — wraps subviews onto multiple lines (e.g. tag chips)
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rowWidth: CGFloat = 0
        var totalHeight: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth + size.width > maxWidth, rowWidth > 0 {
                totalHeight += rowHeight + spacing
                rowWidth = 0
                rowHeight = 0
            }
            rowWidth += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        totalHeight += rowHeight
        return CGSize(width: maxWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let maxWidth = bounds.width
        var x: CGFloat = bounds.minX
        var y: CGFloat = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.minX + maxWidth, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: .unspecified)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
