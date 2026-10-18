import SwiftUI
import UIKit
import ImageIO

/// How a friend looks in the Arena: a small cached thumbnail of their photo,
/// framed the way the player cropped it, or their kind's art (emoji or
/// custom-drawn) when there's no photo.
struct BattlePortrait {
    var image: UIImage?
    var framing: PhotoFraming?
    var species: Species?

    /// A wild rival, or a friend who's since been released.
    static let none = BattlePortrait()

    init(image: UIImage? = nil, framing: PhotoFraming? = nil, species: Species? = nil) {
        self.image = image
        self.framing = framing
        self.species = species
    }

    init(friend: Catch?) {
        self.init(image: friend.flatMap(BattleImages.thumbnail),
                  framing: friend?.framing,
                  species: friend?.species)
    }
}

/// Decodes each friend's photo once, as a small thumbnail. The Arena redraws
/// every second for its timers; decoding full photos each time was wasteful.
enum BattleImages {
    private static let cache = NSCache<NSString, UIImage>()

    static func thumbnail(_ friend: Catch) -> UIImage? {
        guard let data = friend.photoData else { return nil }
        let key = "\(friend.persistentModelID.hashValue)-\(data.count)" as NSString
        if let hit = cache.object(forKey: key) { return hit }
        let options = [kCGImageSourceCreateThumbnailFromImageAlways: true,
                       kCGImageSourceCreateThumbnailWithTransform: true,
                       kCGImageSourceThumbnailMaxPixelSize: 800] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, options) else { return nil }
        let image = UIImage(cgImage: cg)
        cache.setObject(image, forKey: key)
        return image
    }
}

/// A portrait filling whatever frame it's given: the photo (honoring the
/// crop, and taking taps only inside its frame), or the kind's art on a
/// type-colored backdrop, or a monogram when nothing else is known.
struct PortraitFill: View {
    let portrait: BattlePortrait
    let color: Color
    let monogram: String
    /// Art and monogram size, as a share of the frame.
    var artScale: CGFloat = 0.52

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            if let image = portrait.image {
                FriendPhoto(image: image, framing: portrait.framing)
            } else {
                ZStack {
                    RadialGradient(colors: [color, color.darkened(0.45)],
                                   center: .init(x: 0.35, y: 0.3), startRadius: 2,
                                   endRadius: max(geo.size.width, geo.size.height))
                    if let species = portrait.species, species.id != Species.mystery.id {
                        SpeciesGlyph(species: species, size: side * artScale * 0.85)
                    } else {
                        Text(monogram)
                            .font(.system(size: side * artScale * 0.8, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color(hex: 0x0C130F).opacity(0.85))
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
        }
    }
}
