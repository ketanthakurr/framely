import AppIntents
import WidgetKit

// MARK: - Photo set entity (lets users pick a set when editing a widget)

struct PhotoSetEntity: AppEntity, Identifiable {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Photo Set"
    static let defaultQuery = PhotoSetQuery()

    var id: UUID
    var name: String
    var symbol: String

    init(id: UUID, name: String, symbol: String) {
        self.id = id
        self.name = name
        self.symbol = symbol
    }

    init(_ set: PhotoSet) {
        self.init(id: set.id, name: set.name, symbol: set.symbol)
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", image: .init(systemName: symbol))
    }
}

struct PhotoSetQuery: EntityQuery {
    func entities(for identifiers: [UUID]) async throws -> [PhotoSetEntity] {
        SharedStore.shared.loadSets().filter { identifiers.contains($0.id) }.map(PhotoSetEntity.init)
    }

    func suggestedEntities() async throws -> [PhotoSetEntity] {
        SharedStore.shared.loadSets().map(PhotoSetEntity.init)
    }

    func defaultResult() async -> PhotoSetEntity? {
        SharedStore.shared.loadSets().first.map(PhotoSetEntity.init)
    }
}

// MARK: - Enums shown in the widget editor

enum MosaicLayout: String, AppEnum, CaseIterable {
    case grid, filmStrip, polaroidStack

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Layout"
    static let caseDisplayRepresentations: [MosaicLayout: DisplayRepresentation] = [
        .grid: "Grid",
        .filmStrip: "Film strip",
        .polaroidStack: "Polaroid stack",
    ]
}

enum InfoMode: String, AppEnum, CaseIterable {
    case date, countdown, onThisDay

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Show"
    static let caseDisplayRepresentations: [InfoMode: DisplayRepresentation] = [
        .date: "Day & date",
        .countdown: "Countdown",
        .onThisDay: "On this day",
    ]
}

// MARK: - Widget configuration intents

struct PhotoWidgetIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Photo"
    static let description = IntentDescription("Rotates through the photos in one of your sets.")

    @Parameter(title: "Photo Set")
    var photoSet: PhotoSetEntity?

    @Parameter(title: "Show Next Button", default: true)
    var showNextButton: Bool

    init() {}
}

struct MosaicWidgetIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Mosaic"
    static let description = IntentDescription("Several photos from a set in a collage.")

    @Parameter(title: "Photo Set")
    var photoSet: PhotoSetEntity?

    @Parameter(title: "Layout", default: .grid)
    var layout: MosaicLayout

    init() {}
}

struct InfoWidgetIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Photo + Info"
    static let description = IntentDescription("A photo with the date, a countdown, or a memory from this day.")

    @Parameter(title: "Photo Set")
    var photoSet: PhotoSetEntity?

    @Parameter(title: "Show", default: .date)
    var mode: InfoMode

    @Parameter(title: "Countdown Title", default: "Weekend trip")
    var countdownTitle: String

    @Parameter(title: "Countdown Date")
    var countdownDate: Date?

    init() {}
}

struct LockScreenWidgetIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Lock Screen Photo"
    static let description = IntentDescription("A small photo for your Lock Screen.")

    @Parameter(title: "Photo Set")
    var photoSet: PhotoSetEntity?

    init() {}
}

// MARK: - Interactive "next photo" button

struct NextPhotoIntent: AppIntent {
    static let title: LocalizedStringResource = "Next Photo"
    static let isDiscoverable = false

    @Parameter(title: "Set ID")
    var setID: String

    init() {}
    init(setID: UUID) { self.setID = setID.uuidString }

    func perform() async throws -> some IntentResult {
        if let id = UUID(uuidString: setID) {
            SharedStore.shared.advance(setID: id)
        }
        // WidgetKit reloads the tapped widget automatically; refresh the others showing this set.
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
