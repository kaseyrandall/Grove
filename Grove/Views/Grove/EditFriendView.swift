import SwiftUI
import SwiftData

/// Lets the player customize a friend: give it a nickname and choose which
/// Grove zone it lives in. Writes to a `FriendProfile` (created on demand).
struct EditFriendView: View {
    let species: Species
    let currentNickname: String
    let currentZone: Habitat

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var nickname: String
    @State private var zone: Habitat

    private let columns = [GridItem(.adaptive(minimum: 110), spacing: 10)]

    init(species: Species, currentNickname: String, currentZone: Habitat) {
        self.species = species
        self.currentNickname = currentNickname
        self.currentZone = currentZone
        _nickname = State(initialValue: currentNickname)
        _zone = State(initialValue: currentZone)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 22) {
                        preview
                        nicknameField
                        zonePicker
                    }
                    .padding()
                }
            }
            .navigationTitle("Edit \(species.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.bold)
                }
            }
        }
    }

    private var preview: some View {
        ZStack {
            zone.gradient
            Text(species.emoji).font(.system(size: 64))
        }
        .frame(height: 130)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .animation(.easeInOut(duration: 0.25), value: zone)
    }

    private var nicknameField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("NICKNAME")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.ink.opacity(0.45))
                .padding(.leading, 6)

            TextField("A name just for you", text: $nickname)
                .font(.system(.body, design: .rounded))
                .padding()
                .softCard()
        }
    }

    private var zonePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("LIVES IN")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.ink.opacity(0.45))
                .padding(.leading, 6)

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(Habitat.ordered) { habitat in
                    Button {
                        withAnimation { zone = habitat }
                    } label: {
                        HStack(spacing: 6) {
                            Text(habitat.emoji)
                            Text(habitat.shortName)
                                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        }
                        .foregroundStyle(Theme.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(zone == habitat ? habitat.gradient : LinearGradient(colors: [.white, .white], startPoint: .top, endPoint: .bottom))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(zone == habitat ? Theme.accent : Theme.ink.opacity(0.08), lineWidth: 2)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func save() {
        let existing = (try? context.fetch(FetchDescriptor<FriendProfile>()))?
            .first { $0.speciesID == species.id }
        let profile = existing ?? FriendProfile(speciesID: species.id)
        if existing == nil { context.insert(profile) }

        let trimmed = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.nickname = trimmed.isEmpty ? nil : trimmed
        // Only store an override when it differs from the catalog default.
        profile.zoneOverride = (zone == species.zone) ? nil : zone

        try? context.save()
        dismiss()
    }
}
