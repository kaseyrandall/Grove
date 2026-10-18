import SwiftUI

// MARK: - Spread mode (iPhone Duo, open in landscape)
//
// When the open iPhone Duo is held in landscape, its inner display reads as two
// phone-sized pages with the fold running down the middle. Grove lays its tabs
// out as a two-page spread there: content sits on either side of the fold (never
// across it) and the tab bar stands up along the trailing edge, where the system
// puts bars on the Duo. Everywhere else — every other iPhone, the Duo's cover
// display, and the open Duo turned upright — keeps the familiar portrait layout.

extension EnvironmentValues {
    /// True while the window is a two-page spread (the open Duo in landscape).
    @Entry var groveIsSpread: Bool = false
    /// The fold's x position in the window's (global) coordinate space.
    @Entry var groveFoldX: CGFloat = 0
}

enum DuoSpread {
    /// The off switch for Duo support. While false, Grove stays portrait-only
    /// with its phone layouts everywhere (as in 1.1), even on the open Duo; the
    /// spread code stays in place. Flip to true once it's tested on a Duo.
    static let isEnabled = true

    /// The shortest side a window needs before it counts as the open Duo's inner
    /// display. Every regular iPhone (and the Duo's cover display) is narrower
    /// than this in portrait, so they never switch to spreads or landscape.
    static let minimumShortSide: CGFloat = 600

    /// Whether a window of this size should lay out as a two-page spread.
    static func isSpread(windowSize size: CGSize) -> Bool {
        isEnabled && size.width > size.height && min(size.width, size.height) >= minimumShortSide
    }

    /// Whether a screen this size may rotate to landscape at all.
    static func allowsLandscape(screenSize size: CGSize) -> Bool {
        isEnabled && min(size.width, size.height) >= minimumShortSide
    }

    /// How far down the side column the status bar reaches on the open Duo; the
    /// side tab bar starts below it.
    static let statusBarClearance: CGFloat = 112

    /// Half the clear gap kept on each side of the fold.
    static let foldGutter: CGFloat = 16

    /// Widths of the two pages inside `frame` (global coordinates), after the
    /// given outer padding, keeping `foldGutter` clear on each side of the fold.
    static func pageWidths(in frame: CGRect, foldX: CGFloat,
                           leading: CGFloat, trailing: CGFloat) -> (leading: CGFloat, trailing: CGFloat) {
        let left = foldX - foldGutter - (frame.minX + leading)
        let right = (frame.maxX - trailing) - (foldX + foldGutter)
        return (max(0, left), max(0, right))
    }
}
