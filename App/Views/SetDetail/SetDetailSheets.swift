import SwiftUI

// MARK: - Album picker

struct AlbumPickerSheet: View {
    let setID: UUID

    @Environment(AppModel.self) private var model
    @Environment(StoreManager.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var albums: [AlbumInfo] = []
    @State private var state: LoadState = .loading

    private enum LoadState { case loading, denied, ready }

    var body: some View {
        NavigationStack {
            Group {
                switch state {
                case .loading:
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                case .denied:
                    ContentUnavailableView {
                        Label("Photos access needed", systemImage: "photo.on.rectangle.angled")
                    } description: {
                        Text("To keep a set in sync with an album, allow Framely to read your library in Settings. Hand-picking photos works without it.")
                    } actions: {
                        Button("Open Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                case .ready:
                    List(albums) { album in
                        Button {
                            Task {
                                dismiss()
                                await model.linkAlbum(album, to: setID, gate: store.gate)
                            }
                        } label: {
                            HStack(spacing: 14) {
                                AlbumCover(assetID: album.coverAssetID)
                                VStack(alignment: .leading) {
                                    Text(album.title).font(Brand.headline)
                                    Text("\(album.count) photos").font(Brand.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                        .foregroundStyle(.primary)
                    }
                    .overlay {
                        if albums.isEmpty { ContentUnavailableView("No albums", systemImage: "rectangle.stack") }
                    }
                }
            }
            .navigationTitle("Link an Album")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
            .safeAreaInset(edge: .bottom) {
                if state == .ready {
                    Text("The newest \(store.gate.maxPhotos()) photos sync each time you open Framely.")
                        .font(Brand.caption).foregroundStyle(.secondary)
                        .padding()
                }
            }
        }
        .task {
            if await AlbumSyncService.requestAccess() {
                albums = await Task.detached { AlbumSyncService.albums() }.value
                state = .ready
            } else {
                state = .denied
            }
        }
    }
}

private struct AlbumCover: View {
    let assetID: String?
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Brand.gradient.opacity(0.5))
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            }
        }
        .frame(width: 54, height: 54)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .task {
            if let assetID { image = await AlbumSyncService.thumbnail(for: assetID) }
        }
    }
}

// MARK: - Caption

struct CaptionSheet: View {
    let item: PhotoItem
    let setID: UUID
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Thumbnail(item: item, maxPixel: 600)
                    .frame(width: 180, height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .shadow(radius: 12, y: 6)
                TextField("Say something about this photo", text: $text, axis: .vertical)
                    .font(Brand.body)
                    .lineLimit(1...3)
                    .focused($focused)
                    .padding(16)
                    .glass(cornerRadius: 18)
                Text("Captions appear on widgets when “Show caption” is on in Style.")
                    .font(Brand.caption).foregroundStyle(.secondary)
                Spacer()
            }
            .padding(20)
            .navigationTitle("Caption")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        model.setCaption(text, photoID: item.id, in: setID)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .onAppear { text = item.caption ?? ""; focused = true }
    }
}

// MARK: - Full-screen viewer

struct PhotoViewer: View {
    let setID: UUID
    let startAt: PhotoItem

    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var current: UUID?
    @State private var dragY: CGFloat = 0
    @State private var captionTarget: PhotoItem?

    private var photoSet: PhotoSet? { model.photoSet(id: setID) }
    private var photos: [PhotoItem] { photoSet?.photos ?? [] }

    var body: some View {
        ZStack {
            Color.black.opacity(1 - min(0.6, abs(dragY) / 500)).ignoresSafeArea()

            ScrollView(.horizontal) {
                LazyHStack(spacing: 0) {
                    ForEach(photos) { item in
                        ViewerImage(item: item)
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .padding(.horizontal, 12)
                            .containerRelativeFrame(.horizontal)
                            .scrollTransition { content, phase in
                                content.scaleEffect(1 - abs(phase.value) * 0.1).opacity(1 - abs(phase.value) * 0.5)
                            }
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $current)
            .scrollIndicators(.hidden)
            .offset(y: dragY)
            .scaleEffect(1 - min(0.15, abs(dragY) / 2000))
            .simultaneousGesture(
                DragGesture()
                    .onChanged { v in if abs(v.translation.height) > abs(v.translation.width) { dragY = v.translation.height } }
                    .onEnded { v in
                        if abs(v.translation.height) > 140 { dismiss() } else { withAnimation(Brand.bouncy) { dragY = 0 } }
                    }
            )

            VStack {
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").font(.headline).foregroundStyle(.white).frame(width: 44, height: 44)
                    }
                    .glassCircle()
                }
                Spacer()
                if let item = photos.first(where: { $0.id == current }) {
                    VStack(spacing: 4) {
                        if let caption = item.caption { Text(caption).font(Brand.headline) }
                        if let date = item.capturedAt {
                            Text(date, format: .dateTime.day().month(.wide).year()).font(Brand.caption).opacity(0.8)
                        }
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18).padding(.vertical, 10)
                    .glassCapsule()
                    .animation(Brand.spring, value: current)

                    actions(for: item)
                }
            }
            .padding(20)
            .opacity(dragY == 0 ? 1 : 0.3)
        }
        .onAppear { current = startAt.id }
        .sheet(item: $captionTarget) { item in CaptionSheet(item: item, setID: setID) }
        .statusBarHidden()
    }
}

extension PhotoViewer {
    /// Photo actions shown on screen, so they're not hidden behind a long press.
    private func actions(for item: PhotoItem) -> some View {
        let isCover = item.id == photoSet?.cover?.id
        let canRemove = photoSet?.source.isAlbum == false
        return HStack(spacing: 10) {
            viewerButton(isCover ? "Cover" : "Make Cover", symbol: isCover ? "star.fill" : "star") {
                model.makeCover(item.id, in: setID)
            }
            .disabled(isCover)

            viewerButton("Caption", symbol: "text.bubble") { captionTarget = item }

            if canRemove {
                viewerButton("Remove", symbol: "trash") {
                    let next = photos.firstIndex(where: { $0.id == item.id }).flatMap { i in
                        photos.indices.contains(i + 1) ? photos[i + 1] : (i > 0 ? photos[i - 1] : nil)
                    }
                    model.deletePhotos([item.id], from: setID)
                    if let next { current = next.id } else { dismiss() }
                }
            }
        }
        .padding(.top, 8)
    }

    private func viewerButton(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .frame(minHeight: 44)
        }
        .glassCapsule(interactive: true)
    }
}

private struct ViewerImage: View {
    let item: PhotoItem
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).resizable().scaledToFit()
            } else {
                ProgressView().tint(.white).frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task(id: item.id) { image = await ThumbnailCache.shared.image(for: item, maxPixel: 1400) }
    }
}
