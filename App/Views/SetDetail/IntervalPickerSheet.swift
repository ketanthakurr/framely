import SwiftUI

/// Pick any rotation length: tap a default, or dial days / hours / minutes.
struct IntervalPickerSheet: View {
    let setID: UUID

    @Environment(AppModel.self) private var model
    @Environment(StoreManager.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var days = 0
    @State private var hours = 1
    @State private var minutes = 0
    @State private var showPaywall = false

    private var total: Int { days * 1440 + hours * 60 + minutes }
    private var tooShort: Bool { total < ProConfig.absoluteMinimumMinutes }
    private var needsPro: Bool { !store.gate.allows(minutes: total) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    // Big live readout
                    VStack(spacing: 4) {
                        Text("New photo every")
                            .font(Brand.caption).foregroundStyle(.secondary)
                        Text(RotationInterval.longTitle(minutes: max(total, 0)))
                            .font(Brand.title(28))
                            .multilineTextAlignment(.center)
                            .contentTransition(.numericText())
                            .animation(Brand.spring, value: total)
                    }
                    .padding(.top, 8)

                    // Defaults
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Defaults").font(Brand.headline)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                            ForEach(RotationInterval.allCases) { preset in
                                Button { withAnimation(Brand.spring) { apply(minutes: preset.rawValue) } } label: {
                                    ChoiceChip(title: preset.shortTitle,
                                               selected: total == preset.rawValue,
                                               locked: !store.gate.allows(preset))
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(16)
                    .glass(cornerRadius: 24)

                    // Time picker
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Custom time").font(Brand.headline)
                        HStack(spacing: 0) {
                            wheel("days", selection: $days, range: Array(0...7))
                            wheel("hours", selection: $hours, range: Array(0...23))
                            wheel("min", selection: $minutes, range: Array(0...59))
                        }
                        .frame(height: 170)
                    }
                    .padding(16)
                    .glass(cornerRadius: 24)

                    if tooShort {
                        notice("The shortest interval is \(RotationInterval.longTitle(minutes: ProConfig.absoluteMinimumMinutes)).", symbol: "exclamationmark.triangle.fill")
                    } else if needsPro {
                        notice("Faster than \(RotationInterval.everyTitle(minutes: ProConfig.freeMinimumMinutes).lowercased()) is part of Framely Pro.", symbol: "crown.fill")
                    }
                }
                .padding(20)
            }
            .background(AnimatedBackground())
            .navigationTitle("Rotation Time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(needsPro && !tooShort ? "Upgrade" : "Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(tooShort)
                }
            }
            .sensoryFeedback(.selection, trigger: total)
        }
        .presentationDetents([.large])
        .presentationCornerRadius(32)
        .sheet(isPresented: $showPaywall) { PaywallView() }
        .onAppear {
            if let set = model.photoSet(id: setID) { apply(minutes: set.intervalMinutes) }
        }
    }

    // MARK: Pieces

    private func wheel(_ unit: String, selection: Binding<Int>, range: [Int]) -> some View {
        Picker(unit, selection: selection) {
            ForEach(range, id: \.self) { value in
                Text("\(value) \(unit)").tag(value)
            }
        }
        .pickerStyle(.wheel)
        .frame(maxWidth: .infinity)
        .clipped()
    }

    private func notice(_ text: String, symbol: String) -> some View {
        Label(text, systemImage: symbol)
            .font(Brand.caption)
            .foregroundStyle(.secondary)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glass(cornerRadius: 18)
    }

    private func apply(minutes total: Int) {
        days = min(7, total / 1440)
        hours = (total % 1440) / 60
        minutes = total % 60
    }

    private func save() {
        guard !tooShort else { return }
        if needsPro {
            showPaywall = true
            return
        }
        guard var set = model.photoSet(id: setID) else { return dismiss() }
        // Matching a default? Store it as that default; otherwise as custom.
        if let preset = RotationInterval(rawValue: total) {
            set.interval = preset
            set.customMinutes = nil
        } else {
            set.customMinutes = total
        }
        model.update(set)
        dismiss()
    }
}
