import SwiftUI

/// 3-column photo grid with hold-and-drag reordering.
///
/// The lifted photo is drawn in an overlay pinned to the finger (never animated, so it can't lag),
/// while the grid below reflows with a spring. Nothing is saved until the finger lifts.
struct ReorderableGrid<Cell: View>: View {
    let photos: [PhotoItem]
    var reorderEnabled: Bool
    /// True while a photo is lifted, so the page can stop scrolling under the drag.
    @Binding var isReordering: Bool
    var onTap: (PhotoItem) -> Void
    var onReorder: ([UUID]) -> Void
    @ViewBuilder var cell: (PhotoItem) -> Cell

    private let columnCount = 3
    private let spacing: CGFloat = 6
    private let space = "reorderGrid"

    @State private var width: CGFloat = 0
    @State private var liveOrder: [UUID]?
    @State private var draggedID: UUID?
    @State private var lifted = false
    @State private var startIndex = 0
    @State private var drag = ReorderDrag()
    @State private var moveTick = 0
    /// Bumped per drag, so a late "drop finished" from the previous drag can't end a new one.
    @State private var generation = 0
    @GestureState private var pressing = false

    private var displayed: [PhotoItem] {
        guard let liveOrder else { return photos }
        let byID = Dictionary(uniqueKeysWithValues: photos.map { ($0.id, $0) })
        return liveOrder.compactMap { byID[$0] }
    }

    private var side: CGFloat { max(1, (width - spacing * CGFloat(columnCount - 1)) / CGFloat(columnCount)) }

    private func center(of index: Int) -> CGPoint {
        let step = side + spacing
        return CGPoint(x: CGFloat(index % columnCount) * step + side / 2,
                       y: CGFloat(index / columnCount) * step + side / 2)
    }

    var body: some View {
        let items = displayed
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: spacing), count: columnCount), spacing: spacing) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                cell(item)
                    .opacity(draggedID == item.id ? 0 : 1)  // keeps the gap open where it will land
                    .contentShape(Rectangle())
                    .onTapGesture { onTap(item) }
                    .gesture(reorderGesture(item: item, index: index), including: reorderEnabled ? .all : .subviews)
                    .accessibilityLabel(item.caption ?? "Photo \(index + 1) of \(items.count)")
                    .accessibilityActions {
                        if reorderEnabled {
                            Button("Move earlier") { move(item, by: -1) }
                            Button("Move later") { move(item, by: 1) }
                        }
                    }
            }
        }
        .coordinateSpace(name: space)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        .overlay(alignment: .topLeading) {
            if let draggedID, let item = photos.first(where: { $0.id == draggedID }) {
                LiftedPhoto(drag: drag, lifted: lifted, side: side) { cell(item) }
            }
        }
        .onChange(of: pressing) { _, isPressing in
            if !isPressing { finish() }  // also covers a cancelled gesture
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: lifted) { _, new in new }
        .sensoryFeedback(.selection, trigger: moveTick)
    }

    private func reorderGesture(item: PhotoItem, index: Int) -> some Gesture {
        LongPressGesture(minimumDuration: 0.3)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .named(space)))
            .updating($pressing) { value, state, _ in
                if case .second(true, _) = value { state = true }
            }
            .onChanged { value in
                guard case .second(true, let dragValue) = value else { return }
                if draggedID != item.id { begin(item, at: index) }
                guard let dragValue else { return }
                let start = center(of: startIndex)
                drag.point = CGPoint(x: start.x + dragValue.translation.width, y: start.y + dragValue.translation.height)
                reflow()
            }
    }

    private func begin(_ item: PhotoItem, at index: Int) {
        generation += 1
        liveOrder = photos.map(\.id)
        startIndex = index
        drag.point = center(of: index)
        draggedID = item.id
        isReordering = true
        withAnimation(Brand.spring) { lifted = true }
    }

    /// Moves the lifted photo's slot to whichever cell the finger is over.
    private func reflow() {
        guard let draggedID, var order = liveOrder, let current = order.firstIndex(of: draggedID) else { return }
        let step = side + spacing
        let rows = (order.count + columnCount - 1) / columnCount
        let col = min(max(Int(drag.point.x / step), 0), columnCount - 1)
        let row = min(max(Int(drag.point.y / step), 0), rows - 1)
        let target = min(row * columnCount + col, order.count - 1)
        guard target != current else { return }
        order.insert(order.remove(at: current), at: target)
        withAnimation(Brand.spring) { liveOrder = order }
        moveTick += 1
    }

    private func finish() {
        guard let draggedID, let order = liveOrder else { return }
        isReordering = false
        if order != photos.map(\.id) { onReorder(order) }
        let landing = center(of: order.firstIndex(of: draggedID) ?? startIndex)
        let gen = generation
        withAnimation(Brand.spring, completionCriteria: .logicallyComplete) {
            drag.point = landing
            lifted = false
        } completion: {
            guard gen == generation else { return }
            self.draggedID = nil
            liveOrder = nil
        }
    }

    /// VoiceOver alternative to dragging.
    private func move(_ item: PhotoItem, by step: Int) {
        var ids = photos.map(\.id)
        guard let i = ids.firstIndex(of: item.id), ids.indices.contains(i + step) else { return }
        ids.swapAt(i, i + step)
        onReorder(ids)
    }
}

/// The photo under the finger. The only view that reads `drag.point`, so it alone redraws per move.
private struct LiftedPhoto<Content: View>: View {
    let drag: ReorderDrag
    let lifted: Bool
    let side: CGFloat
    @ViewBuilder var content: Content

    var body: some View {
        content
            .frame(width: side, height: side)
            .scaleEffect(lifted ? 1.08 : 1)
            .shadow(color: .black.opacity(lifted ? 0.3 : 0), radius: 14, y: 8)
            .position(drag.point)
            .allowsHitTesting(false)
    }
}
