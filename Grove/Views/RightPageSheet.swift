import SwiftUI

// MARK: - Right-page sheets (iPhone Duo)
//
// On the open Duo's spread, a sheet would open as a card straddling the fold.
// `groveSheet` opens the same screen as a panel over the right page instead —
// where details always open on a spread — leaving the left page in view (the
// friend's photo while you edit it, your profile while you choose your look).
// Everywhere else it's an ordinary sheet.

extension EnvironmentValues {
    /// Set inside a right-page panel: closes it. A screen that can open either
    /// way calls this when it's set, and `dismiss` otherwise — `dismiss` inside
    /// a panel would act on the page underneath instead.
    @Entry var groveSheetClose: (() -> Void)? = nil
}

extension View {
    /// A sheet on phones; a panel over the right page on the open Duo's spread.
    func groveSheet<Sheet: View>(isPresented: Binding<Bool>,
                                 @ViewBuilder content: @escaping () -> Sheet) -> some View {
        modifier(RightPageSheet(isPresented: isPresented, sheet: content))
    }
}

private struct RightPageSheet<Sheet: View>: ViewModifier {
    @Binding var isPresented: Bool
    let sheet: () -> Sheet

    @Environment(\.groveIsSpread) private var isSpread
    @Environment(\.groveFoldX) private var foldX

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: isSpread ? .constant(false) : $isPresented, content: sheet)
            .overlay {
                if isSpread && isPresented {
                    GeometryReader { geo in
                        let pages = DuoSpread.pageWidths(in: geo.frame(in: .global), foldX: foldX,
                                                         leading: 16, trailing: 16)
                        // The panel takes over the right page: the page's own
                        // ground covers it edge to edge, so nothing of the page
                        // underneath peeks out around the panel.
                        // It's the same full-screen gradient as the page, on
                        // the same window background (the gradient fades to
                        // translucent), masked to the right page, so the
                        // shades line up.
                        Theme.background
                            .background(Color(uiColor: .systemBackground))
                            .ignoresSafeArea()
                            .mask(alignment: .trailing) {
                                Rectangle()
                                    .frame(width: pages.trailing + 32)
                                    .ignoresSafeArea()
                            }
                        sheet()
                            // Inside the panel the screen lays out as it would
                            // in a phone sheet, and closes the panel.
                            .environment(\.groveIsSpread, false)
                            .environment(\.groveSheetClose, { isPresented = false })
                            .frame(width: pages.trailing)
                            .background(Theme.cream)
                            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                            .shadow(color: Theme.ink.opacity(0.18), radius: 18, y: 8)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                            .padding(.trailing, 16)
                            .padding(.vertical, 16)
                    }
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: isPresented)
    }
}

// MARK: - Sheet chrome

/// A title-bar button for a screen that opens as a sheet or a panel.
struct SheetAction {
    let title: String
    let action: () -> Void
}

extension View {
    /// The title and Cancel / confirm buttons of a screen that opens either as
    /// a sheet or as a right-page panel. In a sheet it's a navigation bar in the
    /// screen's own navigation stack; in a panel it's a header drawn right in
    /// the panel, since a panel shares the page's navigation and a bar of its
    /// own would merge into the page's bar underneath.
    func groveSheetChrome(title: String, cancel: SheetAction? = nil,
                          confirm: SheetAction? = nil) -> some View {
        modifier(SheetChrome(title: title, cancel: cancel, confirm: confirm))
    }
}

private struct SheetChrome: ViewModifier {
    let title: String
    let cancel: SheetAction?
    let confirm: SheetAction?

    @Environment(\.groveSheetClose) private var closePanel

    func body(content: Content) -> some View {
        if closePanel != nil {
            VStack(spacing: 0) {
                ZStack {
                    Text(title)
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                        .padding(.horizontal, 80)
                    HStack {
                        if let cancel {
                            Button(cancel.title, action: cancel.action)
                        }
                        Spacer()
                        if let confirm {
                            Button(confirm.title, action: confirm.action)
                                .fontWeight(.bold)
                        }
                    }
                    .font(.system(.body, design: .rounded))
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .background(Theme.cream)

                content
            }
        } else {
            NavigationStack {
                content
                    .navigationTitle(title)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        if let cancel {
                            ToolbarItem(placement: .cancellationAction) {
                                Button(cancel.title, action: cancel.action)
                            }
                        }
                        if let confirm {
                            ToolbarItem(placement: .confirmationAction) {
                                Button(confirm.title, action: confirm.action)
                                    .fontWeight(.bold)
                            }
                        }
                    }
            }
        }
    }
}
