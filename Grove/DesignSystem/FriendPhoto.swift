import SwiftUI

/// How a photo is framed inside its card: which point of the photo sits in the
/// middle (0…1 across and down) and how far it's zoomed past "just fills the
/// card". The photo itself is never cut, so a crop can always be redone.
struct PhotoFraming: Equatable {
    var centerX: Double = 0.5
    var centerY: Double = 0.5
    var zoom: Double = 1

    static let maxZoom: Double = 5

    /// Size of the photo, and where its top-left corner goes, so this framing
    /// fills `frame` without ever showing past the photo's edges.
    func layout(photo: CGSize, in frame: CGSize) -> (size: CGSize, origin: CGPoint) {
        guard photo.width > 0, photo.height > 0 else { return (frame, .zero) }
        let fill = max(frame.width / photo.width, frame.height / photo.height)
        let scale = fill * min(max(zoom, 1), Self.maxZoom)
        let size = CGSize(width: photo.width * scale, height: photo.height * scale)
        let x = frame.width / 2 - centerX * size.width
        let y = frame.height / 2 - centerY * size.height
        return (size, CGPoint(x: min(0, max(frame.width - size.width, x)),
                              y: min(0, max(frame.height - size.height, y))))
    }

    /// This framing with its centre pulled back so the card stays inside the
    /// photo (what `layout` would actually show).
    func clamped(photo: CGSize, in frame: CGSize) -> PhotoFraming {
        let placed = layout(photo: photo, in: frame)
        guard placed.size.width > 0, placed.size.height > 0 else { return self }
        return PhotoFraming(centerX: (frame.width / 2 - placed.origin.x) / placed.size.width,
                            centerY: (frame.height / 2 - placed.origin.y) / placed.size.height,
                            zoom: min(max(zoom, 1), Self.maxZoom))
    }
}

/// A friend's photo filling whatever shape it's given, honouring the player's
/// crop. Without a crop it centres the photo, like `scaledToFill`. Clip it with
/// the card's shape at the call site.
struct FriendPhoto: View {
    let image: UIImage
    var framing: PhotoFraming? = nil

    var body: some View {
        GeometryReader { geo in
            let placed = (framing ?? PhotoFraming()).layout(photo: image.size, in: geo.size)
            Image(uiImage: image)
                .resizable()
                .frame(width: placed.size.width, height: placed.size.height)
                .offset(x: placed.origin.x, y: placed.origin.y)
                .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
                .clipped()
                // Clipping hides the overflow but doesn't stop it taking
                // taps: a tall photo filling a square would catch taps meant
                // for whatever sits above or below it (the Profile's Edit
                // button, a neighbouring tile). The image takes none…
                .allowsHitTesting(false)
        }
        // …and the photo's visible frame takes them instead.
        .contentShape(Rectangle())
    }
}
