import SwiftUI
import PhotosUI

struct SetDetailView: View {
    let setID: UUID

    @Environment(AppModel.self) private var model
    @Environment(StoreManager.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.dismiss) private var dismiss

    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var showPicker = false
    @State private var showStyle = false
    @State private var showAlbums = false
    @State private var showRename = false
    @State private var confirmDelete = false
    @State private var topPhoto: PhotoItem?
    @State private var selecting = false
    @State private var selection: Set<UUID> = []
    @State private var captionTarget: PhotoItem?
    @State private var viewerItem: PhotoItem?
    @State private var customValue = ""
    @State private var customUnit: TimeUnit = .minutes
    @FocusState private var customFocused: Bool

    enum TimeUnit: Int, CaseIterable, Identifiable {
        case minutes = 1, hours = 60, days = 1440
        var id: Int { rawValue }
        var title: String {
            switch self {
            case .minutes: "minutes"
            case .hours: "hours"
            case .days: "days"
            }
        }
    }

    private var set: PhotoSet? { model.photoSet(id: setID) }
    private var gate: FeatureGate { store.gate }

    var body: some View {
        Group {
            if let set {
                content(set)
            } else {
                ContentUnavailableView("Set not found", systemImage: "questionmark.folder")
            }
        }
        .background(PhotoBackdrop(item: topPhoto ?? set?.cover).overlay(AnimatedBackground().opacity(0.35)))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbar }
        .photosPicker(
            isPresented: $showPicker,
            selection: $pickerItems,
            maxSelectionCount: max(1, gate.maxPhotos() - (set?.photos.count ?? 0)),
            selectionBehavior: .ordered,
            matching: .images,
            photoLibrary: .shared()
        )
        .onChange(of: pickerItems) { _, items in
            guard !items.isEmpty else { return }
            let batch = items
            pickerItems = []
            Task { await model.importPhotos(batch, into: setID, gate: gate) }
        }
        .sheet(isPresented: $showStyle) { StyleStudioView(setID: setID) }
        .sheet(isPresented: $showAlbums) { AlbumPickerSheet(setID: setID) }
        .sheet(isPresented: $showRename) { if let set { NewSetSheet(editing: set) } }
        .sheet(item: $captionTarget) { item in CaptionSheet(item: item, setID: setID) }
        .fullScreenCover(item: $viewerItem) { item in PhotoViewer(setID: setID, startAt: item) }
        .confirmationDialog("Delete “\(set?.name ?? "")”?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete Set", role: .destructive) {
                if let set { model.deleteSet(set) }
                dismiss()
            }
        } message: {
            Text("Widgets showing this set will show another one. Your Photos library isn’t affected.")
        }
    }

    // MARK: Content

    private func content(_ set: PhotoSet) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                titleBlock(set)

                if set.photos.isEmpty {
                    emptyState
                } else {
                    VStack(spacing: 14) {
                        CardStack(photos: Array(set.photos.prefix(8))) { top in
                            topPhoto = top
                        }
                        .frame(height: 380)
                        .padding(.horizontal, 50)
                        .padding(.top, 10)

                        Label("Swipe the photo to see the next one", systemImage: "hand.draw")
                            .font(Brand.caption)
                            .foregroundStyle(.white.opacity(0.85))
                    }
                }

                actionBar(set)
                rotationCard(set)
                photoGrid(set)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 60)
        }
        .scrollIndicators(.hidden)
    }

    private func titleBlock(_ set: PhotoSet) -> some View {
        VStack(spacing: 6) {
            Image(systemName: set.symbol)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(Brand.gradient, in: Circle())
            Text(set.name).font(Brand.title(30)).foregroundStyle(.white)
            HStack(spacing: 6) {
                Text("\(set.photos.count) photos")
                if case let .album(_, title) = set.source {
                    Text("·")
                    Label(title, systemImage: "arrow.triangle.2.circlepath")
                }
            }
            .font(Brand.caption)
            .foregroundStyle(.white.opacity(0.85))
        }
        .shadow(color: .black.opacity(0.3), radius: 8)
        .padding(.top, 8)
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            FloatingPolaroids().frame(height: 220)
            Text("Add your favorite photos").font(Brand.title(22)).foregroundStyle(.white)
            Text("Pick photos by hand, or link an album that stays in sync.")
                .font(Brand.body).foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 10)
    }

    // MARK: Actions

    private func actionBar(_ set: PhotoSet) -> some View {
        HStack(spacing: 12) {
            ActionTile(symbol: "photo.badge.plus", title: "Add") {
                if set.photos.count >= gate.maxPhotos() { router.showPaywall = true } else { showPicker = true }
            }
            .disabled(set.source.isAlbum)
            .opacity(set.source.isAlbum ? 0.5 : 1)

            ActionTile(symbol: "paintpalette.fill", title: "Style") { showStyle = true }

            if set.source.isAlbum {
                ActionTile(symbol: "arrow.triangle.2.circlepath", title: "Sync") {
                    Task { await model.syncAlbum(setID: setID, gate: gate) }
                }
            } else {
                ActionTile(symbol: "rectangle.stack.badge.plus", title: "Album", pro: !gate.albumSync) {
                    if gate.albumSync { showAlbums = true } else { router.showPaywall = true }
                }
            }
        }
    }

    // MARK: Rotation

    private func rotationCard(_ set: PhotoSet) -> some View {
        let schedule = gate.schedule(for: set)
        let next = PhotoScheduler.nextChange(after: .now, schedule: schedule)
        return VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("Changes every…", systemImage: "timer")
                    .font(Brand.headline)
                Spacer()
                Text(RotationInterval.shortTitle(minutes: schedule.minutes))
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .contentTransition(.numericText())
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Brand.gradient.opacity(0.9), in: Capsule())
                    .foregroundStyle(.white)
            }

            // Defaults
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(RotationInterval.allCases) { interval in
                        let allowed = gate.allows(interval)
                        Button {
                            guard allowed else { router.showPaywall = true; return }
                            var s = set
                            s.interval = interval
                            s.customMinutes = nil
                            withAnimation(Brand.spring) { model.update(s) }
                        } label: {
                            ChoiceChip(title: interval.shortTitle,
                                       selected: set.customMinutes == nil && set.interval == interval,
                                       locked: !allowed)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }
            .scrollIndicators(.hidden)

            customRow(set)

            Divider().opacity(0.5)

            // Anchor time: rotations line up with this clock time.
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Label("Starts at", systemImage: "alarm")
                        .font(Brand.headline)
                    Text(schedule.minutes >= 1440 ? "The photo changes at this time" : "Changes line up with this time")
                        .font(Brand.caption).foregroundStyle(.secondary)
                }
                Spacer()
                DatePicker("Starts at", selection: anchorBinding(set), displayedComponents: .hourAndMinute)
                    .labelsHidden()
            }

            Label {
                Text("Next photo \(Self.dayWord(next)) at \(next.formatted(date: .omitted, time: .shortened))")
            } icon: {
                Image(systemName: "sparkles")
            }
            .font(Brand.caption)
            .foregroundStyle(Brand.lavender)
            .contentTransition(.opacity)

            Picker("Order", selection: Binding(
                get: { set.order },
                set: { var s = set; s.order = $0; model.update(s) }
            )) {
                ForEach(PhotoOrder.allCases) { Label($0.title, systemImage: $0.symbol).tag($0) }
            }
            .pickerStyle(.segmented)

            Text("iOS decides the exact moment widgets refresh, so changes can land a little late — especially in Low Power Mode.")
                .font(Brand.caption)
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .glass(cornerRadius: 26)
        .sensoryFeedback(.selection, trigger: set.intervalMinutes)
        .animation(Brand.spring, value: schedule)
    }

    private static func dayWord(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "today" }
        if cal.isDateInTomorrow(date) { return "tomorrow" }
        return "on " + date.formatted(.dateTime.weekday(.wide))
    }

    // MARK: Custom interval (type your own)

    private var customTotal: Int? {
        guard let n = Int(customValue.trimmingCharacters(in: .whitespaces)), n > 0 else { return nil }
        return n * customUnit.rawValue
    }

    private func customRow(_ set: PhotoSet) -> some View {
        let total = customTotal
        let tooShort = (total ?? Int.max) < ProConfig.absoluteMinimumMinutes
        let needsPro = total.map { !gate.allows(minutes: $0) } ?? false
        let isCurrent = total != nil && total == set.intervalMinutes

        return VStack(alignment: .leading, spacing: 8) {
            Text("Or set your own")
                .font(Brand.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                Text("Every").font(Brand.headline)

                TextField("45", text: $customValue)
                    .keyboardType(.numberPad)
                    .focused($customFocused)
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .multilineTextAlignment(.center)
                    .frame(width: 64)
                    .padding(.vertical, 8)
                    .glass(cornerRadius: 12, interactive: true)
                    .onChange(of: customValue) { _, v in
                        let digits = String(v.filter(\.isNumber).prefix(4))
                        if digits != v { customValue = digits }
                    }

                Picker("Unit", selection: $customUnit) {
                    ForEach(TimeUnit.allCases) { Text($0.title).lineLimit(1).tag($0) }
                }
                .pickerStyle(.menu)
                .tint(Color.primary)
                .fixedSize()

                Spacer(minLength: 0)

                Button {
                    applyCustom(set)
                } label: {
                    Image(systemName: isCurrent ? "checkmark" : "arrow.right")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(Brand.gradient, in: Circle())
                        .contentTransition(.symbolEffect(.replace))
                }
                .disabled(total == nil || tooShort || isCurrent)
                .opacity(total == nil || tooShort ? 0.4 : 1)
                .accessibilityLabel("Set custom interval")
            }

            if tooShort {
                Label("The shortest is \(RotationInterval.longTitle(minutes: ProConfig.absoluteMinimumMinutes))", systemImage: "exclamationmark.triangle.fill")
                    .font(Brand.caption).foregroundStyle(.orange)
            } else if needsPro {
                Label("Faster than every hour is part of Pro", systemImage: "crown.fill")
                    .font(Brand.caption).foregroundStyle(.secondary)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { customFocused = false }
                    .fontWeight(.semibold)
            }
        }
        .onAppear { if customValue.isEmpty { prefillCustom(minutes: set.intervalMinutes) } }
        .onChange(of: set.intervalMinutes) { _, newValue in
            if !customFocused { prefillCustom(minutes: newValue) }
        }
        .animation(Brand.spring, value: tooShort)
        .animation(Brand.spring, value: needsPro)
    }

    private func prefillCustom(minutes m: Int) {
        if m % 1440 == 0 { customUnit = .days; customValue = "\(m / 1440)" }
        else if m % 60 == 0 { customUnit = .hours; customValue = "\(m / 60)" }
        else { customUnit = .minutes; customValue = "\(m)" }
    }

    private func applyCustom(_ set: PhotoSet) {
        guard let total = customTotal, total >= ProConfig.absoluteMinimumMinutes else { return }
        customFocused = false
        guard gate.allows(minutes: total) else { router.showPaywall = true; return }
        var s = set
        if let preset = RotationInterval(rawValue: total) {
            s.interval = preset
            s.customMinutes = nil
        } else {
            s.customMinutes = total
        }
        withAnimation(Brand.spring) { model.update(s) }
    }

    private func anchorBinding(_ set: PhotoSet) -> Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(byAdding: .minute, value: set.anchorMinutes, to: Calendar.current.startOfDay(for: .now)) ?? .now
            },
            set: { date in
                let c = Calendar.current.dateComponents([.hour, .minute], from: date)
                var s = set
                s.anchorMinutes = (c.hour ?? 0) * 60 + (c.minute ?? 0)
                model.update(s)
            }
        )
    }

    // MARK: Grid

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 3)

    @ViewBuilder
    private func photoGrid(_ set: PhotoSet) -> some View {
        if !set.photos.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Photos").font(.system(.title3, design: .rounded).weight(.bold))
                    Spacer()
                    if selecting && !selection.isEmpty {
                        Button(role: .destructive) {
                            withAnimation(Brand.spring) {
                                model.deletePhotos(selection, from: setID)
                                selection = []
                                selecting = false
                            }
                        } label: {
                            Label("Delete \(selection.count)", systemImage: "trash")
                        }
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    }
                    if !set.source.isAlbum {
                        Button(selecting ? "Done" : "Select") {
                            withAnimation(Brand.spring) { selecting.toggle(); selection = [] }
                        }
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    }
                }
                .foregroundStyle(.primary)

                LazyVGrid(columns: columns, spacing: 6) {
                    ForEach(set.photos) { item in
                        gridCell(item, set: set)
                    }
                }

                Text("Tap a photo to view it, set it as cover, add a caption or remove it.")
                    .font(Brand.caption).foregroundStyle(.secondary)

                if !gate.isPro {
                    Text("\(set.photos.count) of \(gate.maxPhotos()) photos on the free plan")
                        .font(Brand.caption).foregroundStyle(.secondary)
                }
            }
            .padding(16)
            .glass(cornerRadius: 26)
        }
    }

    private func gridCell(_ item: PhotoItem, set: PhotoSet) -> some View {
        let selected = selection.contains(item.id)
        return Button {
            if selecting {
                withAnimation(Brand.bouncy) {
                    if selected { selection.remove(item.id) } else { selection.insert(item.id) }
                }
            } else {
                viewerItem = item
            }
        } label: {
            Thumbnail(item: item, maxPixel: 360)
                .aspectRatio(1, contentMode: .fill)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(alignment: .topTrailing) {
                    if selecting {
                        Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundStyle(.white, selected ? Brand.lavender : .black.opacity(0.2))
                            .padding(6)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .overlay(alignment: .bottomLeading) {
                    if item.id == set.cover?.id {
                        Image(systemName: "star.fill").font(.caption2).foregroundStyle(.white).padding(6)
                            .shadow(radius: 2)
                    }
                }
                .scaleEffect(selected ? 0.9 : 1)
        }
        .buttonStyle(PressableStyle())
        .contextMenu {
            Button { model.makeCover(item.id, in: setID) } label: { Label("Make Cover", systemImage: "star") }
            Button { captionTarget = item } label: { Label("Caption", systemImage: "text.bubble") }
            if !set.source.isAlbum {
                Button(role: .destructive) {
                    withAnimation(Brand.spring) { model.deletePhotos([item.id], from: setID) }
                } label: { Label("Remove", systemImage: "trash") }
            }
        } preview: {
            Thumbnail(item: item, maxPixel: 900).frame(width: 300, height: 380)
        }
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button { showRename = true } label: { Label("Rename & Icon", systemImage: "pencil") }
                if set?.source.isAlbum == true {
                    Button { model.unlinkAlbum(setID: setID) } label: { Label("Unlink Album", systemImage: "link") }
                }
                Divider()
                Button(role: .destructive) { confirmDelete = true } label: { Label("Delete Set", systemImage: "trash") }
            } label: {
                Image(systemName: "ellipsis.circle.fill")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.white)
            }
        }
    }
}

struct ActionTile: View {
    let symbol: String
    let title: String
    var pro = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 22, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                Text(title).font(.system(.subheadline, design: .rounded).weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .foregroundStyle(.primary)
            .overlay(alignment: .topTrailing) { if pro { ProBadge().padding(6) } }
            .glass(cornerRadius: 22, interactive: true)
        }
        .buttonStyle(PressableStyle())
    }
}
