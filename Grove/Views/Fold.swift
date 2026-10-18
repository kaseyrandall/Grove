import SwiftUI
import UIKit

/// How an iPhone Duo is folded right now, from iOS 27.1's hinge API. On
/// phones without a hinge it stays `.none`, so everything Duo-only keys off
/// `.halfFolded` and is never seen elsewhere.
enum FoldState: Equatable {
    /// No hinge (every other iPhone), or not known yet.
    case none
    case closed
    /// Partly open, like a tiny laptop or a book stood on a table.
    case halfFolded(angle: CGFloat)
    case flat

    var isHalfFolded: Bool {
        if case .halfFolded = self { return true }
        return false
    }
}

private struct FoldStateKey: EnvironmentKey {
    static let defaultValue: FoldState = .none
}

extension EnvironmentValues {
    /// The Duo's fold, set once at the root by `.readsFold()`.
    var groveFold: FoldState {
        get { self[FoldStateKey.self] }
        set { self[FoldStateKey.self] = newValue }
    }
}

extension View {
    /// Watch the hinge and hand the fold to everything below.
    func readsFold() -> some View {
        modifier(FoldReader())
    }
}

private struct FoldReader: ViewModifier {
    @State private var fold: FoldState = .none

    func body(content: Content) -> some View {
        content
            .environment(\.groveFold, fold)
            .background(HingeWatcher { fold = $0 }.allowsHitTesting(false))
    }
}

/// A zero-size UIKit view carrying a `UIHingeInteraction`.
private struct HingeWatcher: UIViewRepresentable {
    let onChange: (FoldState) -> Void

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        if #available(iOS 27.1, *) {
            let interaction = UIHingeInteraction { _, update in
                let state: FoldState
                if let hinge = update.hinge {
                    switch hinge.status {
                    case .closed:        state = .closed
                    case .partiallyOpen: state = .halfFolded(angle: hinge.angle)
                    case .fullyOpen:     state = .flat
                    default:             state = .none
                    }
                } else {
                    state = .none
                }
                #if DEBUG
                print("🪭 Grove fold: \(state)")
                #endif
                onChange(state)
            }
            view.addInteraction(interaction)
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}
