import SwiftUI
import SwiftData

/// A field-guide page for one critter: its story, where it lives in your Grove,
/// your history with it, and the personal nickname you gave it.
struct GuideEntryView: View {
    let species: Species
    let catches: [Catch]

    @Environment(\.modelContext) private var context
    @State private var showRename = false
    @State private var draftNickname = ""

    private var isCaught: Bool { !catches.isEmpty }
    private var earliest: Catch? { catches.min { $0.caughtAt < $1.caughtAt } }
    private var latest: Catch? { catches.max { $0.caughtAt < $1.caughtAt } }
    private var nickname: String? { earliest?.nickname }
    private var totalSparks: Int { catches.reduce(0) { $0 + $1.sparksEarned } }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 18) {
                    hero
                    nameBlock
                    if isCaught { metaRow }
                    infoCard
                    if isCaught { sightingsCard }
                }
                .padding()
            }
        }
        .navigationTitle(isCaught ? species.name : "Not yet spotted")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Name your \(species.name)", isPresented: $showRename) {
            TextField("Nickname", text: $draftNickname)
            Button("Save") { saveNickname() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Give this friend a nickname just for you.")
        }
    }

    // MARK: Hero

    private var hero: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(species.zone.gradient)

            if let data = latest?.photoData, let ui = UIImage(data: data) {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFill()
                    .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            } else {
                Text(species.emoji)
                    .font(.system(size: 92))
                    .opacity(isCaught ? 1 : 0.4)
            }
        }
        .frame(height: 200)
        .overlay(alignment: .topLeading) {
            RarityBadge(rarity: species.rarity).padding(12)
        }
        .overlay(alignment: .bottomTrailing) {
            Text("\(species.zone.emoji) Lives in your \(species.zone.shortName)")
                .font(.system(.caption, design: .rounded, weight: .bold))
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill(.white.opacity(0.9)))
                .padding(12)
        }
    }

    // MARK: Name + nickname

    private var nameBlock: some View {
        VStack(spacing: 4) {
            Text(species.name)
                .font(.system(size: 26, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.ink)

            if isCaught {
                Button {
                    draftNickname = nickname ?? ""
                    showRename = true
                } label: {
                    if let nickname, !nickname.isEmpty {
                        Text("you named it “\(nickname)”  ✎")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(Theme.ink.opacity(0.7))
                    } else {
                        Label("Give it a nickname", systemImage: "pencil")
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            .foregroundStyle(Theme.accent)
                    }
                }
            }
        }
    }

    // MARK: Meta

    private var metaRow: some View {
        HStack(spacing: 10) {
            metaTile(value: earliest.map { $0.caughtAt.formatted(.dateTime.month().day()) } ?? "—",
                     label: "First met")
            metaTile(value: "\(catches.count)×", label: "Times seen")
            metaTile(value: "\(totalSparks) ✨", label: "Sparks")
        }
    }

    private func metaTile(value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(Theme.ink)
            Text(label.uppercased())
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.ink.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .softCard()
    }

    // MARK: Info

    private var infoCard: some View {
        VStack(spacing: 12) {
            Text(isCaught ? species.blurb : "You haven't spotted this critter yet. Keep exploring!")
                .font(.system(.body, design: .rounded))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)

            Divider()

            Label(species.habitatNote, systemImage: "leaf.fill")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(Theme.ink.opacity(0.7))
        }
        .padding()
        .frame(maxWidth: .infinity)
        .softCard()
    }

    // MARK: Sightings

    private var sightingsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your photos (\(catches.count))")
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(Theme.ink)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(catches.sorted { $0.caughtAt > $1.caughtAt }) { c in
                        VStack(spacing: 6) {
                            if let data = c.photoData, let ui = UIImage(data: data) {
                                Image(uiImage: ui)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 96, height: 96)
                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            } else {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Theme.ink.opacity(0.06))
                                    .frame(width: 96, height: 96)
                                    .overlay(Text(species.emoji).font(.largeTitle))
                            }
                            Text(c.caughtAt, format: .dateTime.month().day())
                                .font(.system(.caption2, design: .rounded))
                                .foregroundStyle(Theme.ink.opacity(0.6))
                        }
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .softCard()
    }

    // MARK: Actions

    private func saveNickname() {
        let trimmed = draftNickname.trimmingCharacters(in: .whitespacesAndNewlines)
        earliest?.nickname = trimmed.isEmpty ? nil : trimmed
        try? context.save()
    }
}
