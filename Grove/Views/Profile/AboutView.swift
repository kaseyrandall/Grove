import SwiftUI

/// A little about-the-maker page: who made Grove, how to reach them, and a way
/// to share feedback. Reached from Settings.
struct AboutView: View {
    /// Marketing version (e.g. "1.0"), read from the bundle so it never goes stale.
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private let website = URL(string: "https://kaseyrandall.design")!
    private let email = URL(string: "mailto:edgekaseinteractive@gmail.com?subject=Grove%20Feedback")!
    private let survey = URL(string: "https://forms.gle/bKomWP17BUP1msbY8")!

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    hero
                    noteCard
                    linksCard

                    Text("Made with 💗 for the wild things around us.")
                        .font(.system(.footnote, design: .rounded, weight: .medium))
                        .foregroundStyle(Theme.ink.opacity(0.55))
                        .multilineTextAlignment(.center)
                        .padding(.top, 2)

                    Text("Grove \(appVersion)")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(Theme.ink.opacity(0.35))
                }
                .padding()
                .padding(.bottom, Theme.tabBarClearance)
            }
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
        .groveTabBarHidden()
    }

    private var hero: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle().fill(Theme.mint.opacity(0.5)).frame(width: 96, height: 96)
                Text("🌿").font(.system(size: 44))
            }
            Text("Grove")
                .font(.system(size: 24, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.ink)
            Text("A cozy home for the wild life you meet.")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(Theme.ink.opacity(0.7))
                .multilineTextAlignment(.center)
            Text("Made by Kasey Randall\nEdge Kase Interactive")
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(Theme.ink.opacity(0.55))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 16)
        .softCard()
    }

    private var noteCard: some View {
        Text("My first iOS game ever — please be kind. 🙏")
            .font(.system(.subheadline, design: .rounded, weight: .semibold))
            .foregroundStyle(Theme.ink.opacity(0.8))
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding()
            .softCard()
    }

    private var linksCard: some View {
        VStack(spacing: 0) {
            linkRow(icon: "globe", title: "Website", url: website)
            Divider().padding(.leading, 56)
            linkRow(icon: "envelope.fill", title: "Send feedback", url: email)
            Divider().padding(.leading, 56)
            linkRow(icon: "square.and.pencil", title: "Share your thoughts", url: survey)
        }
        .softCard()
    }

    private func linkRow(icon: String, title: String, url: URL) -> some View {
        Link(destination: url) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 26)
                Text(title)
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.ink.opacity(0.25))
            }
            .padding()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack { AboutView() }
        .tint(Theme.accent)
        .fontDesign(.rounded)
}
