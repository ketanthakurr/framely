import Observation
import CoreGraphics

/// Finger position during a photo reorder.
///
/// Kept in its own observable object so only the floating photo redraws as the finger moves
/// (60–120 times a second). The grid itself reads it only inside gesture callbacks, which
/// SwiftUI doesn't track, so the grid redraws just when the order actually changes.
@Observable
final class ReorderDrag {
    var point: CGPoint = .zero
}
