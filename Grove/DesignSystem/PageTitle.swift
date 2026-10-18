import SwiftUI

/// A tab's big title. It matches iOS's large navigation title (system font,
/// same size and spot, as on the Journal) but is drawn in the page, so a
/// button can sit beside it and both scroll away with the page instead of
/// staying pinned. Pair with `.statusBarFade()` on the scroll view.
struct PageTitle<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(title)
                .font(.largeTitle.bold())
                .fontDesign(.default)
                .foregroundStyle(Color.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
            trailing
        }
        .frame(minHeight: 44)
        .padding(.horizontal, 20)
        .padding(.top, 53)
    }
}

extension PageTitle where Trailing == EmptyView {
    init(_ title: String) {
        self.init(title: title) { EmptyView() }
    }
}

/// A round button that sits beside a `PageTitle`.
struct PageTitleButton: View {
    let systemImage: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .frame(width: 42, height: 42)
                .background(Circle().fill(.white))
                .shadow(color: Theme.ink.opacity(0.1), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

extension View {
    /// With no navigation bar, fade a scrolling page out under the status bar
    /// so its content doesn't run into the clock.
    func statusBarFade() -> some View {
        overlay(alignment: .top) {
            GeometryReader { geo in
                LinearGradient(colors: [Theme.cream, Theme.cream.opacity(0)],
                               startPoint: .top, endPoint: .bottom)
                    .frame(height: geo.safeAreaInsets.top + 14)
                    .ignoresSafeArea(edges: .top)
            }
            .allowsHitTesting(false)
        }
    }
}
