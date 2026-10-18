import SwiftUI

/// "What's new in Grove": shown once after an update brings new features (and
/// any time from Settings). Reads its highlights from `ReleaseNotes`.
struct WhatsNewView: View {
    let notes: ReleaseNotes
    var onDone: () -> Void

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 12) {
                        Image("GroveIcon")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 76, height: 76)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .shadow(color: Theme.ink.opacity(0.12), radius: 10, x: 0, y: 5)
                        Text("What's new")
                            .font(.system(size: 30, weight: .heavy, design: .rounded))
                            .foregroundStyle(Theme.ink)
                        Text("in Grove \(notes.version)")
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            .foregroundStyle(Theme.ink.opacity(0.55))
                    }

                    VStack(spacing: 12) {
                        ForEach(notes.items) { item in row(item) }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 36)
                .padding(.bottom, 24)
            }
            .safeAreaInset(edge: .bottom) {
                GroveButton(title: "Let's go!", action: onDone)
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                    .padding(.bottom, 8)
            }
        }
        .presentationDragIndicator(.visible)
    }

    private func row(_ item: ReleaseNotes.Item) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text(item.emoji)
                .font(.system(size: 24))
                .frame(width: 46, height: 46)
                .background(Circle().fill(Theme.mint.opacity(0.35)))
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(Theme.ink)
                Text(item.detail)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(Theme.ink.opacity(0.65))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .softCard()
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    WhatsNewView(notes: ReleaseNotes.all[0], onDone: {})
}
