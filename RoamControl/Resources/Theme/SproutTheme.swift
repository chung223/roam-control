import SwiftUI

/// Sprout's design tokens.
///
/// Colours are defined here rather than in the asset catalogue so that the
/// light and dark values sit side by side and can be read as one decision.
/// Every token resolves for both appearances: the app offers an explicit
/// light/dark/automatic setting, so no token may assume one of them.
///
/// The palette is soft and botanical — warm paper, moss, coral — chosen to
/// read as calm rather than technical. It is original: it borrows a genre,
/// not any product's identity.
enum SproutTheme {

    // MARK: - Colour

    /// Page background, behind the map and sheets.
    static let background = dynamic(light: 0xFBF6E2, dark: 0x141A12)

    /// Cards and controls that sit on the background.
    static let surface = dynamic(light: 0xFFFFFF, dark: 0x1F2A1B)

    /// A surface raised above another surface, such as a row inside a card.
    static let surfaceRaised = dynamic(light: 0xF3EED8, dark: 0x2A3724)

    /// Primary action and brand colour: moss.
    static let primary = dynamic(light: 0x55743A, dark: 0xAECC84)

    /// Primary colour at low opacity, for fills behind icons.
    static let primarySoft = dynamic(light: 0xE9EFD3, dark: 0x2E3F24)

    /// Destructive and attention colour: coral. Warm enough to belong to the
    /// palette, distinct enough to stop someone mid-gesture.
    static let accent = dynamic(light: 0xD4694A, dark: 0xE8896B)

    static let accentSoft = dynamic(light: 0xFBEAE4, dark: 0x40241C)

    /// Body and heading text.
    static let text = dynamic(light: 0x2E3A2B, dark: 0xF0EDE4)

    /// Supporting text, captions and inactive icons.
    static let textSecondary = dynamic(light: 0x6B7A63, dark: 0xA8B5A0)

    /// Hairlines and dividers.
    static let separator = dynamic(light: 0xE2DED2, dark: 0x33422B)

    /// Positive state, for a healthy connection.
    static let positive = dynamic(light: 0x4F8A4A, dark: 0x8FCB78)

    // MARK: - Illustrative colour

    /// Single colours for illustrative headers. The app icon is drawn flat,
    /// with no gradient anywhere in it, so the interface is too — a gradient
    /// here would be the one place the two visual languages disagreed.
    enum Pair {
        /// The brand colour.
        static let moss = dynamic(light: 0x55743A, dark: 0x8FBF6A)
        /// Cooler green, for calm or informational moments.
        static let sage = dynamic(light: 0x4E7D69, dark: 0x7FB39C)
        /// Warm, for attention without alarm.
        static let clay = dynamic(light: 0xB07C42, dark: 0xD6A874)
        /// Coral, for interruption and recovery.
        static let coral = dynamic(light: 0xD4694A, dark: 0xE8896B)
    }

    // MARK: - Shape

    enum Radius {
        /// Cards and sheets.
        static let card: CGFloat = 24
        /// Buttons and rows inside a card.
        static let control: CGFloat = 16
        /// Chips and badges.
        static let chip: CGFloat = 12
    }

    /// The floating circular map controls.
    static let mapControlDiameter: CGFloat = 44

    // MARK: - Typography

    /// Rounded throughout. It is the single choice that carries most of the
    /// friendliness, and it keeps Dynamic Type working because it only
    /// changes the design of the system font.
    static func font(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        .system(style, design: .rounded).weight(weight)
    }

    // MARK: - Elevation

    struct Shadow {
        let color: Color
        let radius: CGFloat
        let y: CGFloat
    }

    /// Resting cards.
    static let cardShadow = Shadow(color: shadowColor(0.10), radius: 18, y: 8)
    /// Floating controls over the map.
    static let controlShadow = Shadow(color: shadowColor(0.10), radius: 10, y: 4)

    // MARK: - Private

    private static func shadowColor(_ lightOpacity: Double) -> Color {
        Color(uiColor: UIColor { traits in
            // A dark surface needs a deeper shadow to separate at all.
            let opacity = traits.userInterfaceStyle == .dark ? lightOpacity * 2.6 : lightOpacity
            return UIColor(white: 0, alpha: opacity)
        })
    }

    private static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

private extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

extension View {
    /// A card in the Sprout style: soft surface, generous radius, gentle lift.
    /// A card floating over the map. Glass for the same reason the controls
    /// are: what is behind it moves and changes brightness, and it has to
    /// stay readable over all of it.
    func sproutCard(
        radius: CGFloat = SproutTheme.Radius.card,
        padding: CGFloat = 18
    ) -> some View {
        self
            .padding(padding)
            .contentShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .glassEffect(
                .regular,
                in: RoundedRectangle(cornerRadius: radius, style: .continuous)
            )
    }

    /// Puts a List or Form on the Sprout background instead of the system
    /// grouped grey, which is the only part of a standard list that reads as
    /// belonging to a different app.
    func sproutListBackground() -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(SproutTheme.background)
    }

    /// A circular control floating over the map.
    ///
    /// Glass rather than a filled circle and a drawn shadow: this is exactly
    /// what the system's own material is for — a control over moving content,
    /// which has to stay legible whether the map beneath it is a pale street
    /// or a dark satellite photograph. An opaque surface had to pick one.
    func sproutMapControl() -> some View {
        self
            .frame(
                width: SproutTheme.mapControlDiameter,
                height: SproutTheme.mapControlDiameter
            )
            // Before the glass, a drawn fill made the whole circle tappable.
            // A material is not a shape to hit, so without this the target
            // shrinks to the glyph itself and the control stops responding.
            .contentShape(Circle())
            .glassEffect(.regular.interactive(), in: Circle())
    }
}
