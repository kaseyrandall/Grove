import SwiftUI
import SwiftData

/// A friend's name with a pencil: tap it, type, done. Used on the friend page
/// and the catch celebration so naming a friend never needs a separate sheet.
///
/// The parent owns `isRenaming` so a tap anywhere else on its page can finish
/// the rename (set it to false); the typed name is saved then. An empty name
/// goes back to the friend's kind.
struct RenamableName: View {
    let friend: Catch
    @Binding var isRenaming: Bool
    var fontSize: CGFloat = 26

    @Environment(\.modelContext) private var context
    @State private var draft = ""
    @FocusState private var focused: Bool

    var body: some View {
        Group {
            if isRenaming {
                TextField(friend.species.name, text: $draft)
                    .font(.system(size: fontSize, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)
                    .submitLabel(.done)
                    .focused($focused)
                    .onSubmit { isRenaming = false }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 16)
                    .background(Capsule().fill(.white))
                    .overlay(Capsule().stroke(Theme.accent, lineWidth: 2))
                    .padding(.horizontal, 24)
            } else {
                Button { isRenaming = true } label: {
                    HStack(spacing: 8) {
                        Text(friend.displayName)
                            .font(.system(size: fontSize, weight: .heavy, design: .rounded))
                            .foregroundStyle(Theme.ink)
                            .multilineTextAlignment(.center)
                        Image(systemName: "pencil")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Theme.accent)
                            .frame(width: 28, height: 28)
                            .background(Circle().fill(.white))
                            .shadow(color: Theme.ink.opacity(0.08), radius: 3, y: 1)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(friend.displayName), rename")
            }
        }
        .onChange(of: isRenaming) { _, renaming in
            if renaming {
                draft = friend.nickname ?? ""
                focused = true
            } else {
                commit()
            }
        }
        // Dismissing the keyboard finishes the rename too.
        .onChange(of: focused) { _, isFocused in
            if !isFocused && isRenaming { isRenaming = false }
        }
    }

    private func commit() {
        focused = false
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        let newName: String? = trimmed.isEmpty ? nil : trimmed
        guard newName != friend.nickname else { return }
        friend.nickname = newName
        try? context.save()
    }
}
