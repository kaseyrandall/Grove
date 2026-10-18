import SwiftUI

/// The two choices you make about a friend — which animal it is and where it
/// lives — laid out the same way wherever they appear: the catch celebration
/// and the Edit sheet. One look and one set of words ("Animal", "Lives in").

/// A small uppercase heading over a section ("ANIMAL", "LIVES IN").
struct FriendSectionLabel: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundStyle(Theme.ink.opacity(0.45))
            .padding(.leading, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// "ANIMAL" over a full-width row that opens the field guide. A Mystery
/// Friend's row asks who it is; a named friend's shows its kind.
struct FriendAnimalSection: View {
    let species: Species
    let action: () -> Void

    private var isMystery: Bool { species.id == Species.mystery.id }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            FriendSectionLabel(text: "Animal")
            Button(action: action) {
                HStack(spacing: 12) {
                    SpeciesGlyph(species: isMystery ? .mystery : species, size: 22)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(isMystery ? "Choose your friend" : species.name)
                            .font(.system(.body, design: .rounded, weight: .bold))
                            .foregroundStyle(isMystery ? Theme.accent : Theme.ink)
                        Text(isMystery ? "Who did you find?" : "Tap to choose a different animal")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(Theme.ink.opacity(0.5))
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.ink.opacity(0.3))
                }
                .padding()
                .softCard()
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens the field guide")
        }
    }
}

/// "LIVES IN" over all eight zones as chips. `selected` is nil until the
/// player has chosen (nothing is highlighted then).
struct FriendZoneSection: View {
    let selected: Habitat?
    let onSelect: (Habitat) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            FriendSectionLabel(text: "Lives in")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 10)], spacing: 10) {
                ForEach(Habitat.ordered) { habitat in
                    let isOn = habitat == selected
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) { onSelect(habitat) }
                    } label: {
                        HStack(spacing: 6) {
                            Text(habitat.emoji)
                            Text(habitat.shortName)
                                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .foregroundStyle(Theme.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(isOn ? habitat.gradient
                                      : LinearGradient(colors: [.white, .white], startPoint: .top, endPoint: .bottom))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(isOn ? Theme.accent : Theme.ink.opacity(0.08), lineWidth: 2)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isOn ? .isSelected : [])
                }
            }
        }
    }
}
