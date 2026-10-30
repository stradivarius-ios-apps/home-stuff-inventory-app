import Foundation
import Testing
@testable import HomeStuffInventoryApp

struct LocalizationCatalogTests {
    @Test func catalogContainsEveryCodeReferencedLocalizationKey() throws {
        let rootURL = try localizationTestRepositoryRootURL()
        let appURL = rootURL.appendingPathComponent("HomeStuffInventoryApp", isDirectory: true)
        let catalog = try localizationTestCatalog(at: appURL.appendingPathComponent("Resources/Localizable.xcstrings"))
        let referencedKeys = try codeReferencedLocalizationTestKeys(in: appURL)
            .union(runtimeReferencedLocalizationTestKeys())
        let issues = localizationTestCatalogIssues(keys: referencedKeys, catalog: catalog)
        #expect(issues.isEmpty, "Localization catalog issues: \(issues.joined(separator: ", "))")
    }

    @Test func appTargetKeepsCompilerStringExtractionDisabled() throws {
        let projectFile = try String(
            contentsOf: localizationTestRepositoryRootURL().appendingPathComponent("HomeStuffInventoryApp.xcodeproj/project.pbxproj"),
            encoding: .utf8
        )
        let emitSettings = projectFile.components(separatedBy: .newlines).filter { $0.contains("SWIFT_EMIT_LOC_STRINGS") }
        #expect(emitSettings.count == 2)
        #expect(emitSettings.allSatisfy { $0.contains("SWIFT_EMIT_LOC_STRINGS = NO;") })
    }

    @Test func listManagementRelationshipErrorUsesCatalogKey() throws {
        let source = try String(
            contentsOf: localizationTestRepositoryRootURL().appendingPathComponent("HomeStuffInventoryApp/Views/InventoryListManagementState.swift"),
            encoding: .utf8
        )

        #expect(source.contains("inventory.lists.error.placeDoesNotBelongToLocation.message"))
        #expect(!source.contains("message: \"This place does not belong to the selected location.\""))
    }

    @Test func managedValueEditorActionsMatchTheirCapabilities() throws {
        let root = try localizationTestRepositoryRootURL()
        let managedRowSource = try String(
            contentsOf: root.appendingPathComponent("HomeStuffInventoryApp/Views/InventoryManagedValueRow.swift"),
            encoding: .utf8
        )
        let listSource = try String(
            contentsOf: root.appendingPathComponent("HomeStuffInventoryApp/Views/InventoryListManagementView.swift"),
            encoding: .utf8
        )
        let placeSource = try String(
            contentsOf: root.appendingPathComponent("HomeStuffInventoryApp/Views/Settings/PlaceManagementView.swift"),
            encoding: .utf8
        )
        let hierarchySource = try String(
            contentsOf: root.appendingPathComponent(
                "HomeStuffInventoryApp/Views/Settings/InventoryPlaceHierarchyMutationViews.swift"
            ),
            encoding: .utf8
        )

        #expect(managedRowSource.contains("let editActionLabel: String"))
        #expect(listSource.contains("editActionLabel: localized(\"inventory.action.edit\""))
        #expect(listSource.contains("editActionLabel: localized(\"inventory.action.rename\""))
        #expect(placeSource.contains("onEdit: presentHierarchyEditor"))
        #expect(hierarchySource.contains("Label(\"inventory.action.edit\""))
    }

    @Test func tagsLabelAndFormatHelperResolveInBothLanguages() {
        for (language, label, format, expected) in [
            ("en", "Tags", "Separate tags with commas. Maximum %d characters per tag.",
             "Separate tags with commas. Maximum 16 characters per tag."),
            ("uk", "Теги", "Розділяйте теги комами. Максимум %d символів у кожному тегу.",
             "Розділяйте теги комами. Максимум 16 символів у кожному тегу.")
        ] {
            #expect(localizationTestValue("inventory.field.tags", language: language) == label)
            let helper = localizationTestValue("inventory.form.tagsFormatHelper", language: language)
            #expect(helper == format)
            #expect(String(format: helper, InventoryItemDraft.maximumTagLength) == expected)
        }
    }

    @Test func notesEmptyPromptKeepsDisplayCopySeparateFromNoNotesFallback() {
        for (language, prompt, fallback) in [
            ("en", "Tap to add a note", "No notes"),
            ("uk", "Торкніться, щоб додати нотатку", "Без нотаток")
        ] {
            #expect(localizationTestValue("inventory.notes.emptyPrompt", language: language) == prompt)
            #expect(localizationTestValue("inventory.fallback.noNotes", language: language) == fallback)
        }
    }

    @Test func ukrainianCoreStringsResolveFromCatalog() {
        #expect(localized("inventory.title") == "Інвентар")
        #expect(localized("inventory.action.addItem") == "Додати річ")
        #expect(localized("inventory.category.tools") == "Інструменти")
        #expect(localized("inventory.condition.good") == "Гарний")
        #expect(localized("inventory.condition.needsRepair") == "Потребує ремонту")
        #expect(localized("inventory.condition.new") == "Новий")
        #expect(localized("inventory.condition.unknown") == "Невідомий")
        #expect(localized("inventory.fallback.noLocation") == "Без локації")
        #expect(localized("inventory.fallback.noContainer") == "Без місця зберігання")
        #expect(localized("inventory.fallback.noNotes") == "Без нотаток")
        #expect(localized("inventory.notes.emptyPrompt") == "Торкніться, щоб додати нотатку")
        #expect(localized("inventory.field.location") == "Локація")
        #expect(localized("inventory.field.container") == "Місце зберігання")
        #expect(localized("inventory.field.itemIcon") == "Іконка речі")
        #expect(localized("inventory.field.notes") == "Нотатки")
        #expect(localized("inventory.notes.editor.title") == "Редагувати нотатки")
        #expect(localized("inventory.notes.discard.title") == "Відкинути зміни?")
        #expect(localized("inventory.notes.discard.message") == "Відкинути внесені зміни до нотаток?")
        #expect(localized("inventory.action.discard") == "Відкинути зміни")
        #expect(localized("inventory.action.keepEditing") == "Продовжити редагування")
        #expect(localized("inventory.alert.discardItemChanges.title") == "Відкинути зміни?")
        #expect(localized("inventory.alert.discardItemChanges.newMessage") == "Відкинути нову річ? Її не буде збережено.")
        #expect(localized("inventory.alert.discardItemChanges.editMessage") == "Відкинути зміни? Збережена річ не зміниться.")
        #expect(localized("inventory.alert.reviewPlaceAfterLocationChange.title") == "Перевірте місце зберігання")
        #expect(localized("inventory.alert.reviewPlaceAfterLocationChange.message") == "Місце зберігання «%@» може належати попередній локації. Залишити його після зміни локації на «%@» чи очистити й ввести нове місце зберігання?")
        #expect(localized("inventory.alert.deleteError.title") == "Річ не видалено")
        #expect(localized("inventory.alert.deleteError.message") == "Не вдалося видалити річ. Спробуйте ще раз.")
        #expect(localized("inventory.alert.saveError.editTitle") == "Річ не оновлено")
        #expect(localized("inventory.alert.saveError.message") == "Не вдалося зберегти зміни. Спробуйте ще раз.")
        #expect(localized("inventory.action.keepPlace") == "Залишити місце зберігання")
        #expect(localized("inventory.action.clearPlace") == "Очистити місце зберігання")
        #expect(localized("inventory.notes.placeholder") == "Додайте деталі: для чого це, що в комплекті або де шукати.")
        #expect(localized("inventory.notes.card.accessibilityLabel") == "Нотатки: %@")
        #expect(localized("inventory.notes.card.accessibilityHint") == "Відкриває редактор нотаток.")
        #expect(localized("inventory.search.match.notes") == "Збіг у нотатках")
        #expect(localized("inventory.search.match.tag") == "Збіг за тегом: %@")
        #expect(localized("inventory.section.item") == "Річ")
        #expect(localized("inventory.section.whereIsIt") == "Де це зберігається?")
        #expect(localized("inventory.section.itemKind") == "Деталі")
        #expect(localized("inventory.section.extraContext") == "Контекст")
        #expect(localized("inventory.form.nameRequiredFooter") == "Назва обов’язкова.")
        #expect(localized("inventory.form.storageFooter") == "Додайте точну шухляду, коробку, полицю, шафу або органайзер.")
        #expect(localized("inventory.form.extraContextFooter") == "Теги допомагають із альтернативними назвами або пов’язаним пошуком.")
        #expect(localized("inventory.empty.message") == "Додавайте домашні речі з локацією та точним місцем зберігання, щоб знаходити їх пізніше.")
        #expect(localized("inventory.empty.filtered.searchAndFilters") == "За цим пошуком і фільтрами речей не знайдено.")
        #expect(localized("inventory.action.clearSearch") == "Очистити пошук")
        #expect(localized("inventory.action.clearSearchAndFilters") == "Очистити пошук і фільтри")
        #expect(localized("locations.empty.message") == "Додайте речі з локацією та точним місцем зберігання, щоб бачити, де що лежить.")
        #expect(localized("locations.allItems.title") == "Усі речі")
        #expect(localized("locations.allItems.subtitle") == "%@ у цій локації")
        #expect(localized("locations.itemsAccess.allItemsAction.accessibilityHint") == "Відкриває повний список речей у цій локації.")
        #expect(localized("locations.recentItems.itemAction.accessibilityHint") == "Відкриває екран деталей речі.")
        #expect(localized("locations.items.empty.title") == "Тут немає речей")
        #expect(localized("locations.places.empty.message") == "Додайте річ, щоб почати впорядковувати цю локацію за місцями зберігання.")
        #expect(localized("locations.placeItems.empty.title") == "У цьому місці зберігання немає речей")
        #expect(localized("inventory.filterContext.search") == "Пошук: %@")
        #expect(localized("inventory.filterContext.category") == "Категорія: %@")
        #expect(localized("inventory.filterContext.location") == "Локація: %@")
        #expect(localized("inventory.tab.accessibilityLabel") == "Вкладка інвентарю")
        #expect(localized("locations.tab.accessibilityLabel") == "Вкладка локацій")
        #expect(localized("settings.title") == "Налаштування")
        #expect(localized("settings.introduction.title") == "Упорядкуйте свої речі")
        #expect(localized("settings.introduction.body") == "Локації та місця зберігання допомагають памʼятати, де зберігається кожна річ.")
        #expect(localized("settings.section.lists") == "Списки")
        #expect(localized("settings.lists.locations") == "Локації")
        #expect(localized("settings.lists.categories") == "Категорії")
        #expect(localized("settings.section.data") == "Дані")
        #expect(localized("settings.export.subtitle") == "Для перегляду або поширення. Не підходить для відновлення інвентарю.")
        #expect(localized("settings.backup.subtitle") == "Повна копія для відновлення інвентарю.")
        #expect(localized("settings.restore.subtitle") == "Замінює інвентар на цьому пристрої даними резервної копії.")
        #expect(localized("settings.backup.title") == "Створити резервну копію")
        #expect(localized("settings.backup.accessibilityLabel") == "Створити резервну копію інвентарю")
        #expect(localized("settings.backup.error.encoding.title") == "Не вдалося створити резервну копію")
        #expect(localized("settings.backup.error.lowStorage.title") == "Недостатньо місця")
        #expect(localized("settings.backup.error.destination.title") == "Не вдалося зберегти резервну копію")
        #expect(localized("settings.tab.accessibilityLabel") == "Вкладка налаштувань")
        #expect(localized("inventory.condition.good") != "Добрий")
    }
}


struct LocalizationGuardRegressionTests {
    @Test func literalScannerIncludesExtendedNamespacesAndExcludesIdentifiers() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try #"""
        Text("premium.fixture")
        Text("placeIcons.fixture")
        Text("inventory.fixture")
        .accessibilityIdentifier("premium.identifier")
        """#.write(to: directory.appendingPathComponent("Fixture.swift"), atomically: true, encoding: .utf8)
        #expect(try codeReferencedLocalizationTestKeys(in: directory) == [
            "premium.fixture", "placeIcons.fixture", "inventory.fixture"
        ])
    }

    @Test func runtimeKeysFollowTheProductionEnumsAndOptionCatalogs() {
        let keys = runtimeReferencedLocalizationTestKeys()
        #expect(keys.isSuperset(of: ItemIconCategory.allCases.map(\.titleKey)))
        #expect(keys.isSuperset(of: LocationIconCategory.allCases.map(\.titleKey)))
        #expect(keys.isSuperset(of: PremiumBundleCapability.allCases.map(\.titleKey)))
        #expect(keys.isSuperset(of: ItemIconCatalog.options.map(\.nameKey)))
        #expect(keys.isSuperset(of: LocationIconCatalog.options.map(\.nameKey)))
    }

    @Test(arguments: ["premium.fixture", "placeIcons.fixture", PremiumBundleCapability.roomSweep.titleKey])
    func missingKeysAndMissingOrBlankTranslationsFailTheGuard(key: String) {
        #expect(localizationTestCatalogIssues(keys: [key], catalog: [:]) == ["Missing catalog key: \(key)"])
        #expect(localizationTestCatalogIssues(keys: [key], catalog: fixture(key, en: "English", uk: "Українська")).isEmpty)
        for language in ["en", "uk"] {
            for invalid in [nil, "", " \n\t"] as [String?] {
                let catalog = fixture(key, en: language == "en" ? invalid : "English",
                                      uk: language == "uk" ? invalid : "Українська")
                #expect(localizationTestCatalogIssues(keys: [key], catalog: catalog) == [
                    "Missing or empty \(language) value: \(key)"
                ])
            }
        }
    }

    private func fixture(_ key: String, en: String?, uk: String?) -> [String: LocalizationCatalogEntry] {
        var values: [String: LocalizationValue] = [:]
        for (language, value) in [("en", en), ("uk", uk)] {
            if let value { values[language] = LocalizationValue(stringUnit: LocalizationStringUnit(value: value)) }
        }
        return [key: LocalizationCatalogEntry(localizations: values)]
    }
}
