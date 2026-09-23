import SwiftUI

/// Choose your profile look — a wild-thing emoji and a cozy background color,
/// split across two tabs whose labels are your current picks: the chosen emoji
/// and a swatch of the chosen color. A live preview sits up top.
struct ProfileLookPicker: View {
    @Binding var emoji: String
    @Binding var colorHex: Int
    @Environment(\.dismiss) private var dismiss
    @State private var tab = 0

    /// The default avatar background (a soft mint).
    static let defaultColor = 0xBFE3C8

    private let emojis = [
        "🌿","🍃","🌸","🌼","🌻","🍄","🌲","🌳",
        "🦊","🐰","🐿️","🦔","🦌","🐻","🐢","🐸",
        "🐦","🦉","🦅","🕊️","🦆","🦋","🐝","🐞",
        "🐳","🐬","🐙","🦭","🦩","🦚","🐾","🍁",
        "🌎","⛰️","🏕️","☀️","🌙","⭐️",
    ]
    /// Curated quick-pick presets — the color wheel below covers everything else.
    static let palette: [Int] = [
        0xBFE3C8, 0xBFDDF2, 0xF7C9D9, 0xD9CDF0,
        0xF8D2B8, 0xF6E7A8, 0xCBD6B0, 0xF6BCA8,
        0xC6CCF0, 0xB8E6E0, 0xF3C0C0, 0xDDD8CE,
    ]
    private let emojiColumns = [GridItem(.adaptive(minimum: 60), spacing: 12)]
    private let colorColumns = [GridItem(.adaptive(minimum: 60), spacing: 12)]

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                VStack(spacing: 16) {
                    preview
                    lookTabs
                        .padding(.horizontal)

                    ScrollView {
                        if tab == 0 { emojiGrid } else { colorTab }
                    }
                }
                .padding(.top, 10)
            }
            .navigationTitle("Choose your look")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
        }
    }

    private var preview: some View {
        ZStack {
            Circle().fill(Color(hex: UInt(colorHex))).frame(width: 88, height: 88)
            Text(emoji).font(.system(size: 42))
        }
        .shadow(color: .black.opacity(0.06), radius: 6, y: 3)
    }

    // MARK: Tabs — labelled by your current picks

    private var lookTabs: some View {
        HStack(spacing: 0) {
            tabButton(index: 0) {
                Text(emoji).font(.system(size: 22))
            }
            tabButton(index: 1) {
                Circle()
                    .fill(Color(hex: UInt(colorHex)))
                    .frame(width: 26, height: 26)
                    .overlay(Circle().stroke(Theme.ink.opacity(0.15), lineWidth: 1))
            }
        }
        .padding(4)
        .background(Capsule().fill(Theme.ink.opacity(0.07)))
    }

    private func tabButton<Content: View>(index: Int, @ViewBuilder content: () -> Content) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) { tab = index }
        } label: {
            content()
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(tab == index ? Color.white : Color.clear)
                        .shadow(color: tab == index ? .black.opacity(0.08) : .clear, radius: 3, y: 1)
                )
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: Icon grid

    private var emojiGrid: some View {
        LazyVGrid(columns: emojiColumns, spacing: 12) {
            ForEach(emojis, id: \.self) { e in
                Button { emoji = e } label: {
                    Text(e)
                        .font(.system(size: 34))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(emoji == e ? Theme.mint.opacity(0.5) : Color.white)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(emoji == e ? Theme.accent : Theme.ink.opacity(0.06),
                                                lineWidth: emoji == e ? 2 : 1)
                                )
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
    }

    // MARK: Color grid

    private var colorTab: some View {
        LazyVGrid(columns: colorColumns, spacing: 12) {
            ForEach(Self.palette, id: \.self) { hex in
                Button { colorHex = hex } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color(hex: UInt(hex)))
                            .frame(height: 60)
                        if colorHex == hex {
                            Image(systemName: "checkmark")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(Theme.ink.opacity(0.55))
                        }
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(colorHex == hex ? Theme.accent : Theme.ink.opacity(0.08),
                                    lineWidth: colorHex == hex ? 2.5 : 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
    }
}

#Preview {
    ProfileLookPicker(emoji: .constant("🦊"), colorHex: .constant(0xBFE3C8))
        .tint(Theme.accent)
        .fontDesign(.rounded)
}
