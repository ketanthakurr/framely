import SwiftUI

/// Lock Screen designer: live mock Lock Screen + shape, look, layout and text options.
struct LockStudio: View {
    let set: PhotoSet
    @Binding var lock: LockScreenStyle
    let gate: FeatureGate
    let tick: Int
    let choose: @MainActor (Bool, () -> Void) -> Void

    var body: some View {
        VStack(spacing: 22) {
            LockScreenPreview(set: set, lock: lock, tick: tick)

            shapeSection
            lookSection
            layoutSection
            textSection
            detailsSection

            Label("iOS always draws Lock Screen widgets in a tinted, see-through style. Bold, Poster and Sketch keep photos readable on any wallpaper.",
                  systemImage: "info.circle")
                .font(Brand.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: Sections

    private var shapeSection: some View {
        StudioSection(title: "Circle widget shape") {
            ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    ForEach(LockShape.allCases) { shape in
                        let allowed = gate.allows(shape)
                        Button { choose(allowed) { lock.shape = shape } } label: {
                            OptionTile(title: shape.title, selected: lock.shape == shape, locked: !allowed) {
                                Image(systemName: shape.symbol).font(.system(size: 24, weight: .medium))
                            }
                        }
                        .buttonStyle(PressableStyle())
                    }
                }
                .padding(.vertical, 4)
            }
            .scrollIndicators(.hidden)
        }
    }

    private var lookSection: some View {
        StudioSection(title: "Photo look") {
            ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    ForEach(LockPhotoLook.allCases) { look in
                        let allowed = gate.allows(look)
                        Button { choose(allowed) { lock.look = look } } label: {
                            OptionTile(title: look.title, selected: lock.look == look, locked: !allowed) {
                                LookThumb(item: set.cover, look: look)
                            }
                        }
                        .buttonStyle(PressableStyle())
                    }
                }
                .padding(.vertical, 4)
            }
            .scrollIndicators(.hidden)
        }
    }

    private var layoutSection: some View {
        StudioSection(title: "Rectangle widget layout") {
            ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    ForEach(LockRectLayout.allCases) { layout in
                        let allowed = gate.allows(layout)
                        Button { choose(allowed) { lock.rectLayout = layout } } label: {
                            OptionTile(title: layout.title, selected: lock.rectLayout == layout, locked: !allowed) {
                                Image(systemName: layout.symbol).font(.system(size: 24, weight: .medium))
                            }
                        }
                        .buttonStyle(PressableStyle())
                    }
                }
                .padding(.vertical, 4)
            }
            .scrollIndicators(.hidden)
        }
    }

    private var textSection: some View {
        StudioSection(title: "Text") {
            VStack(spacing: 12) {
                textPicker("Main line", selection: $lock.primaryText)
                textPicker("Second line", selection: $lock.secondaryText)
                if lock.primaryText == .custom || lock.secondaryText == .custom {
                    TextField("Your text (e.g. “My people ♡”)", text: $lock.customText)
                        .font(Brand.body)
                        .padding(12)
                        .glass(cornerRadius: 14)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                Text("The main line also appears in the one-line widget above the clock.")
                    .font(Brand.caption).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .animation(Brand.spring, value: lock.primaryText == .custom || lock.secondaryText == .custom)
        }
    }

    private func textPicker(_ title: String, selection: Binding<LockText>) -> some View {
        HStack {
            Text(title).font(Brand.body)
            Spacer()
            Picker(title, selection: selection) {
                ForEach(LockText.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.menu)
            .tint(Brand.lavender)
        }
    }

    private var detailsSection: some View {
        StudioSection(title: "Details") {
            VStack(spacing: 14) {
                Toggle(isOn: $lock.border) { Label("Outline", systemImage: "circle.dashed") }
                HStack {
                    Label("Strength", systemImage: "circle.lefthalf.filled")
                    Slider(value: $lock.intensity, in: 0.3...1.0)
                }
            }
            .font(Brand.body)
            .tint(Brand.lavender)
        }
    }
}

// MARK: - Look thumbnail

private struct LookThumb: View {
    let item: PhotoItem?
    let look: LockPhotoLook
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            Circle().fill(Color.black.opacity(0.55))
            if let image {
                Color.white
                    .mask { Image(uiImage: image).resizable().scaledToFill().luminanceToAlpha() }
            }
        }
        .clipShape(Circle())
        .task(id: look) {
            guard let item else { return }
            image = await ThumbnailCache.shared.image(for: item, maxPixel: 200, lockLook: look)
        }
    }
}

// MARK: - Mock Lock Screen

/// Approximates iOS's Lock Screen: blurred wallpaper, big clock, and widgets drawn
/// in the vibrant style (brightness becomes opacity, just like the real thing).
struct LockScreenPreview: View {
    let set: PhotoSet
    let lock: LockScreenStyle
    let tick: Int

    @State private var images: [UIImage?] = [nil, nil, nil]

    private func item(_ shift: Int) -> PhotoItem? {
        guard !set.photos.isEmpty else { return nil }
        let n = set.photos.count
        return set.photos[((tick + shift) % n + n) % n]
    }

    private func content(_ shift: Int) -> LockContent {
        let imgs = lock.rectLayout == .strip ? Array(images[shift...]) + Array(images[..<shift]) : [images[shift]]
        return LockContent(images: imgs, item: item(shift), set: set, style: lock, date: .now, systemBackground: false)
    }

    var body: some View {
        ZStack {
            // Wallpaper
            PhotoBackdrop(item: set.cover)
            LinearGradient(colors: [.black.opacity(0.25), .clear, .black.opacity(0.35)], startPoint: .top, endPoint: .bottom)

            VStack(spacing: 6) {
                vibrant(LockInlineView(content: content(0)).font(.system(size: 15, weight: .semibold, design: .rounded)))
                    .frame(height: 20)

                Text(Date.now, format: .dateTime.hour(.defaultDigits(amPM: .omitted)).minute())
                    .font(.system(size: 84, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.top, -4)

                HStack(spacing: 10) {
                    vibrant(LockCircularView(content: content(0)))
                        .frame(width: 64, height: 64)
                    vibrant(LockCircularView(content: content(1)))
                        .frame(width: 64, height: 64)
                    vibrant(LockRectangularView(content: content(0)))
                        .frame(width: 150, height: 64)
                }
                .padding(.top, 4)
                Spacer()
            }
            .padding(.top, 26)
        }
        .frame(height: 300)
        .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 36, style: .continuous).strokeBorder(.white.opacity(0.35), lineWidth: 1))
        .shadow(color: .black.opacity(0.25), radius: 20, y: 10)
        .animation(Brand.spring, value: lock)
        .task(id: "\(tick)-\(lock.look.rawValue)") {
            var loaded: [UIImage?] = []
            for shift in 0..<3 {
                if let item = item(shift) {
                    loaded.append(await ThumbnailCache.shared.image(for: item, maxPixel: 320, lockLook: lock.look))
                } else {
                    loaded.append(nil)
                }
            }
            withAnimation(.easeInOut(duration: 0.4)) { images = loaded }
        }
    }

    /// Brightness → opacity, tinted white: the Lock Screen "vibrant" look.
    private func vibrant<V: View>(_ view: V) -> some View {
        let white = view
            .foregroundStyle(.white)
            .environment(\.colorScheme, .dark)
        return ZStack {
            white.opacity(0.001) // keeps layout
            Color.white.opacity(0.92)
                .mask { white.luminanceToAlpha() }
        }
    }
}
