import CoreGraphics

/// Pixel sizes the widgets decode at (@3x). Shared so the app pre-builds exactly what the widget reads.
/// The limit applies to a photo's long edge while widgets crop to fill, so sizes leave room for
/// the short edge (a 3:4 photo at 720 still covers a ~510px small widget without upscaling).
enum WidgetPixelSize {
    static let small: CGFloat = 720
    static let large: CGFloat = 1150
    static let accessory: CGFloat = 540
    /// Every size the Home Screen widgets (Photo, Info, Mosaic) use.
    static let home: [CGFloat] = [small, large]
    /// Every size the Lock Screen widgets use.
    static let lock: [CGFloat] = [accessory]
}
