import Foundation

struct InventoryItemCreateContext: Equatable {
    var locationName: String
    var placeName: String

    static let global = InventoryItemCreateContext()

    init(locationName: String = "", placeName: String = "") {
        self.locationName = locationName
        self.placeName = placeName
    }
}

struct InventoryItemDraft: Equatable {
    static let maximumTagLength = 16

    var name = ""
    var iconID: String?
    var locationName = ""
    var containerName = ""
    /// Optional first-class Place identity. `containerName` remains the compatibility value.
    var placeID: UUID?
    /// A Location change must not turn same-looking legacy text into a different scoped Place.
    var allowsLegacyPlaceResolution = true
    var category = InventoryCategory.miscellaneous.rawValue
    var quantity = 1
    var condition = InventoryCondition.unknown.rawValue
    var tagsText = ""
    var notes = ""

    init() { }

    init(createContext: InventoryItemCreateContext) {
        locationName = createContext.locationName
        containerName = createContext.placeName
    }

    init(item: InventoryItem) {
        name = item.name
        iconID = ItemIconCatalog.normalizedIconID(item.iconID)
        locationName = item.locationName
        containerName = item.containerName ?? ""
        placeID = item.placeID
        category = InventoryCategory.storageValue(from: item.category)
        quantity = item.quantity
        condition = InventoryCondition.storageValue(from: item.condition)
        tagsText = item.tags.joined(separator: ", ")
        notes = item.notes
    }

    var isNameValid: Bool {
        InventoryItem.isValidName(name)
    }

    var isTagsValid: Bool {
        invalidTags.isEmpty
    }

    var invalidTags: [String] {
        normalizedTags.filter { $0.count > Self.maximumTagLength }
    }

    var normalizedTags: [String] {
        InventoryTagNormalization.normalizedTags(from: tagsText
            .split(separator: ",")
            .map(String.init)
        )
    }

    /// The persisted meaning of editable input, used to decide whether a form has unsaved changes.
    var normalizedForComparison: NormalizedForComparison {
        let normalizedContainerName = containerName.trimmingCharacters(in: .whitespacesAndNewlines)

        return NormalizedForComparison(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            iconID: ItemIconCatalog.normalizedIconID(iconID),
            locationName: locationName.trimmingCharacters(in: .whitespacesAndNewlines),
            containerName: normalizedContainerName.isEmpty ? nil : normalizedContainerName,
            placeID: placeID,
            allowsLegacyPlaceResolution: allowsLegacyPlaceResolution,
            category: InventoryCategory.storageValue(from: category),
            quantity: max(1, quantity),
            condition: InventoryCondition.storageValue(from: condition),
            tags: normalizedTags.map(InventoryTagNormalization.comparisonKey),
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    func makeInventoryItem(createdAt: Date = .now, placeID: UUID? = nil) -> InventoryItem? {
        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        guard InventoryItem.isValidName(normalizedName), isTagsValid else {
            return nil
        }

        let normalizedContainerName = containerName.trimmingCharacters(in: .whitespacesAndNewlines)

        return InventoryItem(
            name: normalizedName,
            category: category,
            locationName: locationName.trimmingCharacters(in: .whitespacesAndNewlines),
            containerName: normalizedContainerName.isEmpty ? nil : normalizedContainerName,
            placeID: placeID,
            iconID: iconID,
            quantity: quantity,
            condition: condition,
            tags: normalizedTags,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            createdAt: createdAt
        )
    }

    func apply(to item: InventoryItem, placeID: UUID? = nil, updatedAt timestamp: Date = .now) {
        guard isTagsValid else {
            return
        }

        item.applyUserEdit(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            category: category,
            locationName: locationName.trimmingCharacters(in: .whitespacesAndNewlines),
            containerName: containerName,
            placeID: placeID,
            updatesPlaceID: true,
            iconID: iconID,
            quantity: quantity,
            condition: condition,
            tags: normalizedTags,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            updatedAt: timestamp
        )
    }
}

extension InventoryItemDraft {
    struct NormalizedForComparison: Equatable {
        let name: String
        let iconID: String?
        let locationName: String
        let containerName: String?
        let placeID: UUID?
        let allowsLegacyPlaceResolution: Bool
        let category: String
        let quantity: Int
        let condition: String
        let tags: [String]
        let notes: String
    }
}

struct InventoryStorageConsistencyReview: Equatable {
    struct Prompt: Equatable {
        let locationName: String
        let placeName: String
    }

    private var lastAcceptedLocationName: String

    init(initialLocationName: String) {
        lastAcceptedLocationName = Self.trimmed(initialLocationName)
    }

    mutating func promptIfNeeded(nextLocationName: String, placeName: String) -> Prompt? {
        let nextLocationName = Self.trimmed(nextLocationName)
        defer { lastAcceptedLocationName = nextLocationName }

        guard !Self.isSameLocation(lastAcceptedLocationName, nextLocationName),
              !Self.trimmed(placeName).isEmpty else {
            return nil
        }

        return Prompt(locationName: nextLocationName, placeName: placeName)
    }

    private static func isSameLocation(_ lhs: String, _ rhs: String) -> Bool {
        lhs.localizedCaseInsensitiveCompare(rhs) == .orderedSame
    }

    private static func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
