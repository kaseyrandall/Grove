import SwiftUI
import SwiftData

/// Coach your fighter: a prioritised list of IF-this → DO-that rules. Each turn
/// the sim reads top to bottom and runs the first rule that's true. Persisted per
/// friend; drives the real match.
struct BattlePlanEditorView: View {
    let fighter: Catch
    let archetype: Archetype

    @Environment(\.dismiss) private var dismiss
    @State private var rules: [StoredRule]

    private let condTint = Color(hex: 0x5FC7D6)   // conditions read as cool/cyan
    private let actTint  = Color(hex: 0xEC7FB0)   // actions read as warm/pink

    init(fighter: Catch, archetype: Archetype) {
        self.fighter = fighter
        self.archetype = archetype
        _rules = State(initialValue: BattleRoster.shared.storedPlan(for: fighter, archetype: archetype).rules)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                BattleTheme.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        explainer
                        presetRow
                        ForEach(Array(rules.enumerated()), id: \.element.id) { idx, _ in
                            ruleCard(idx)
                        }
                        addButton
                        Text("No rule matched? Your fighter just strikes.")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(BattleTheme.muted.opacity(0.8))
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 4)
                    }
                    .padding()
                }
            }
            .navigationTitle("Battle Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }.fontWeight(.bold)
                }
            }
        }
    }

    // MARK: Header

    private var explainer: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(fighter.displayName)'s tactics")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(BattleTheme.ink)
            Text("Each turn, the first rule that's true runs. Drag priority top → bottom.")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(BattleTheme.muted)
        }
    }

    private var presetRow: some View {
        HStack(spacing: 8) {
            presetChip("Default") { rules = StoredPlan(.defaultPlan(for: archetype)).rules }
            presetChip("Aggressive") { rules = StoredPlan.aggressive.rules }
            presetChip("Defensive") { rules = StoredPlan.defensive.rules }
        }
    }

    private func presetChip(_ title: String, _ action: @escaping () -> Void) -> some View {
        Button { withAnimation(.easeInOut(duration: 0.15)) { action() } } label: {
            Text(title)
                .font(.system(size: 12.5, weight: .bold, design: .rounded))
                .foregroundStyle(BattleTheme.muted)
                .padding(.horizontal, 13).padding(.vertical, 8)
                .background(Capsule().fill(Color(hex: 0x1C2C23)).overlay(Capsule().stroke(BattleTheme.panelLine, lineWidth: 1)))
        }
        .buttonStyle(.plain)
    }

    // MARK: Rule card

    private func ruleCard(_ idx: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Text("\(idx + 1)")
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundStyle(BattleTheme.gold)
                    .frame(width: 20, height: 20)
                    .background(Circle().fill(Color.white.opacity(0.06)))
                Text("IF").font(.system(size: 11, weight: .heavy, design: .rounded)).foregroundStyle(BattleTheme.muted)
                conditionMenu(idx)
                Spacer(minLength: 0)
            }
            HStack(spacing: 10) {
                Text("DO").font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundStyle(BattleTheme.muted)
                    .padding(.leading, 30)
                actionMenu(idx)
                Spacer(minLength: 0)
                moveButton("chevron.up", disabled: idx == 0) { move(idx, by: -1) }
                moveButton("chevron.down", disabled: idx == rules.count - 1) { move(idx, by: 1) }
                Button { delete(idx) } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color(hex: 0xE8654F))
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(Color.white.opacity(0.05)))
                }
                .buttonStyle(.plain)
                .disabled(rules.count <= 1)
                .opacity(rules.count <= 1 ? 0.4 : 1)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(BattleTheme.panelFill)
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(BattleTheme.panelLine, lineWidth: 1))
        )
    }

    private func conditionMenu(_ idx: Int) -> some View {
        Menu {
            ForEach(CondSpec.choices, id: \.self) { c in
                Button(c.label) { rules[idx].condition = c }
            }
        } label: { chip(rules[idx].condition.label, tint: condTint) }
    }

    private func actionMenu(_ idx: Int) -> some View {
        Menu {
            ForEach(ActSpec.allCases, id: \.self) { a in
                Button(a.label) { rules[idx].action = a }
            }
        } label: { chip(rules[idx].action.label, tint: actTint) }
    }

    private func chip(_ text: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Text(text).lineLimit(1)
            Image(systemName: "chevron.down").font(.system(size: 9, weight: .bold))
        }
        .font(.system(size: 13, weight: .bold, design: .rounded))
        .foregroundStyle(BattleTheme.ink)
        .padding(.horizontal, 11).padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(tint.opacity(0.16))
                .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).stroke(tint.opacity(0.5), lineWidth: 1))
        )
    }

    private func moveButton(_ system: String, disabled: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(BattleTheme.muted)
                .frame(width: 30, height: 30)
                .background(Circle().fill(Color.white.opacity(0.05)))
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.35 : 1)
    }

    private var addButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                rules.append(StoredRule(condition: .always, action: .strike))
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                Text("Add a rule")
            }
            .font(.system(size: 15, weight: .bold, design: .rounded))
            .foregroundStyle(BattleTheme.leaf)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(BattleTheme.leaf.opacity(0.4), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: Actions

    private func move(_ idx: Int, by delta: Int) {
        let target = idx + delta
        guard rules.indices.contains(target) else { return }
        withAnimation(.easeInOut(duration: 0.18)) { rules.swapAt(idx, target) }
    }
    private func delete(_ idx: Int) {
        guard rules.count > 1, rules.indices.contains(idx) else { return }
        _ = withAnimation(.easeInOut(duration: 0.18)) { rules.remove(at: idx) }
    }
    private func save() {
        BattleRoster.shared.setPlan(StoredPlan(rules: rules), for: fighter)
        dismiss()
    }
}
