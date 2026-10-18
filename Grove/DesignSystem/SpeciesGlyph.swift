import SwiftUI

/// A friend's kind, drawn: its custom art when it has some (for animals
/// with no emoji, like the opossum), otherwise its emoji. `size` is the
/// emoji point size; art is framed to match an emoji at that size.
struct SpeciesGlyph: View {
    let species: Species
    let size: CGFloat

    var body: some View {
        if let art = species.art {
            Image(art)
                .resizable()
                .scaledToFit()
                .frame(width: size * 1.2, height: size * 1.2)
                .accessibilityHidden(true)
        } else {
            Text(species.emoji)
                .font(.system(size: size))
        }
    }
}
