import SwiftUI
import SwiftData
import UIKit

/// Customize an individual friend: identify (or correct) which animal it is,
/// give them a nickname, choose which Grove zone they live in, or release them
/// back to the wild. Edits the friend's `Catch` directly. Releasing is signalled
/// to the presenter via `onRelease` (which performs the delete once this sheet
/// closes, so we never touch a deleted model).
struct EditFriendView: View {
    let friend: Catch
    let onRelease: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    /// The friend's kind — mutable so it can be (re)identified here.
    @State private var species: Species
    @State private var nickname: String
    @State private var zone: Habitat
    @State private var showReleaseConfirm = false

    /// Best guesses re-derived from the friend's photo on appear.
    @State private var suggestions: [Species] = []
    /// Drives the push to the full, searchable catalog.
    @State private var showPicker = false

    init(friend: Catch, onRelease: @escaping () -> Void) {
        self.friend = friend
        self.onRelease = onRelease
        _species = State(initialValue: friend.species)
        _nickname = State(initialValue: friend.nickname ?? "")
        _zone = State(initialValue: friend.effectiveZone)
    }

    private var isMystery: Bool { species.id == Species.mystery.id }

    /// Suggestions minus whatever is already chosen (no point re-offering it).
    private var offeredSuggestions: [Species] {
        suggestions.filter { $0.id != species.id }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 22) {
                        preview
                        typeSection
                        zonePicker
                        nicknameField
                        releaseButton
                    }
                    .padding()
                }
                .navigationDestination(isPresented: $showPicker) {
                    SpeciesPickerView(selectedID: species.id) { picked in
                        select(picked)
                    }
                }
            }
            .navigationTitle(isMystery ? "New Friend" : "Edit \(species.name)")
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
            .confirmationDialog("Release \(species.name)?", isPresented: $showReleaseConfirm, titleVisibility: .visible) {
                Button("Release back to the wild", role: .destructive) {
                    onRelease()
                    dismiss()
                }
                Button("Keep them", role: .cancel) {}
            } message: {
                Text("They'll leave your Grove for good. You can always meet a new friend out in the wild.")
            }
            .task { await loadSuggestions() }
        }
    }

    private var preview: some View {
        ZStack {
            zone.gradient
            if let data = friend.photoData, let ui = UIImage(data: data) {
                Image(uiImage: ui).resizable().scaledToFill()
            } else {
                Text(species.emoji).font(.system(size: 64))
            }
        }
        .frame(height: 130)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(alignment: .bottomTrailing) {
            if !isMystery {
                Text("\(species.emoji) \(species.name)")
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Capsule().fill(.white.opacity(0.92)))
                    .padding(12)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: zone)
    }

    // MARK: Type of friend — a few guesses inline, full list behind a door

    private var typeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("TYPE OF FRIEND")

            // Lead with whatever's confident: for an identified friend that's
            // the current pick; for a Mystery Friend it's the photo guesses.
            if isMystery {
                suggestionsBlock
                browseButton
            } else {
                browseButton
                suggestionsBlock
            }
        }
    }

    /// The photo-derived shortlist — framed as the primary recommendation for a
    /// Mystery Friend, or as alternatives ("or did you mean…") once identified.
    @ViewBuilder private var suggestionsBlock: some View {
        if !offeredSuggestions.isEmpty {
            Text(isMystery ? "✨ Best guesses from your photo" : "✨ Or did you mean…")
                .font(.system(.caption2, design: .rounded, weight: .bold))
                .foregroundStyle(Theme.ink.opacity(0.5))
                .padding(.leading, 6)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 10)], spacing: 10) {
                ForEach(offeredSuggestions) { candidate in
                    SpeciesTile(species: candidate, isSelected: false) { select(candidate) }
                }
            }
        }
    }

    /// The door to the full, searchable catalog.
    private var browseButton: some View {
        Button {
            showPicker = true
        } label: {
            HStack(spacing: 10) {
                if isMystery {
                    Image(systemName: "square.grid.2x2.fill")
                        .foregroundStyle(Theme.accent)
                    Text("Browse all animals")
                        .font(.system(.body, design: .rounded, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                } else {
                    Text(species.emoji)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(species.name)
                            .font(.system(.body, design: .rounded, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                        Text("Tap to choose a different animal")
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(Theme.ink.opacity(0.5))
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.ink.opacity(0.3))
            }
            .padding()
            .softCard()
        }
        .buttonStyle(.plain)
    }

    private var zonePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("LIVES IN")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 10)], spacing: 10) {
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
                                .fill(zone == habitat
                                      ? habitat.gradient
                                      : LinearGradient(colors: [.white, .white], startPoint: .top, endPoint: .bottom))
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

    private var nicknameField: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("NICKNAME")
            TextField("A name just for this friend", text: $nickname)
                .font(.system(.body, design: .rounded))
                .padding()
                .softCard()
        }
    }

    private var releaseButton: some View {
        Button(role: .destructive) {
            showReleaseConfirm = true
        } label: {
            Text("🍃 Release \(species.name) back to the wild")
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(Theme.ink.opacity(0.5))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
        }
        .padding(.top, 4)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundStyle(Theme.ink.opacity(0.45))
            .padding(.leading, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Actions

    /// Pick a kind. Moves the friend to that kind's home zone so "Lives in"
    /// reflects the choice — the player can still override it just below.
    private func select(_ candidate: Species) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
            species = candidate
            zone = candidate.zone
        }
    }

    /// Re-run on-device Vision over the stored photo to offer a shortlist of
    /// likely animals. Cheap, no network, and works for any existing catch.
    private func loadSuggestions() async {
        guard suggestions.isEmpty,
              let data = friend.photoData,
              let ui = UIImage(data: data) else { return }
        let labels = await AnimalClassifier.classify(ui)
        let picks = CreatureCatalog.smartSuggestions(labels: labels)
        #if DEBUG
        print("🔎 Identify suggestions — Vision: \(labels) → \(picks.map(\.name))")
        #endif
        await MainActor.run { suggestions = picks }
    }

    private func save() {
        // If the kind changed, re-log it and recompute its first-of-kind bonus.
        if species.id != friend.speciesID {
            let others = (try? context.fetch(FetchDescriptor<Catch>())) ?? []
            let isFirst = !others.contains { $0 !== friend && $0.speciesID == species.id }
            friend.speciesID = species.id
            friend.isFirstSighting = isFirst
            friend.sparksEarned = Progression.sparks(for: species, isFirstSighting: isFirst)
        }

        let trimmed = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        friend.nickname = trimmed.isEmpty ? nil : trimmed
        friend.zoneOverride = (zone == species.zone) ? nil : zone

        try? context.save()
        dismiss()
    }
}

// MARK: - Full catalog picker

/// The extensive, searchable list of every friend — a dedicated screen so the
/// edit sheet stays compact and this scales as the catalog grows. Picking an
/// animal reports it back and pops.
struct SpeciesPickerView: View {
    let selectedID: String
    let onPick: (Species) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private let columns = [GridItem(.adaptive(minimum: 96), spacing: 10)]

    private var results: [Species] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return CreatureCatalog.alphabetical }
        return CreatureCatalog.alphabetical.filter { candidate in
            candidate.name.lowercased().contains(q)
                || candidate.matchKeywords.contains { $0.contains(q) }
        }
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            ScrollView {
                if results.isEmpty {
                    Text("No animals match “\(query.trimmingCharacters(in: .whitespaces))”.")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(Theme.ink.opacity(0.5))
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                } else {
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(results) { candidate in
                            SpeciesTile(species: candidate, isSelected: candidate.id == selectedID) {
                                onPick(candidate)
                                dismiss()
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("Choose a Friend")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search animals")
        .autocorrectionDisabled()
        .textInputAutocapitalization(.never)
    }
}

// MARK: - Shared tile

/// One animal in a grid: emoji, name, a rarity-tinted border, and an accent
/// ring + check when it's the current pick. Shared by the inline suggestions
/// and the full picker so they stay visually identical.
struct SpeciesTile: View {
    let species: Species
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                Text(species.emoji).font(.system(size: 30))
                Text(species.name)
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? Theme.accent.opacity(0.12) : Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? Theme.accent : species.rarity.tint.opacity(0.35),
                            lineWidth: isSelected ? 2.5 : 1.5)
            )
            .overlay(alignment: .topTrailing) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.accent)
                        .padding(6)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
