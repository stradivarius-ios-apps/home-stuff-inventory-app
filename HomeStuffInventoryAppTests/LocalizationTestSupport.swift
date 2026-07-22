import Foundation

func localizationTestValue(_ key: String) -> String {
    localizationTestValue(key, language: "uk")
}

func localizationTestValue(_ key: String, language: String) -> String {
    guard let bundle = localizationTestLanguageBundle(language) else {
        return ""
    }

    return bundle.localizedString(forKey: key, value: nil, table: "Localizable")
}

func localized(_ key: String) -> String {
    localizationTestValue(key)
}

func localizationTestLanguageBundle(_ language: String) -> Bundle? {
    guard let localizationPath = Bundle.main.path(forResource: language, ofType: "lproj") else {
        return nil
    }

    return Bundle(path: localizationPath)
}

func localizationTestRepositoryRootURL() throws -> URL {
    var url = URL(fileURLWithPath: #filePath)

    while url.path != "/" {
        url.deleteLastPathComponent()

        if FileManager.default.fileExists(atPath: url.appendingPathComponent("AGENTS.md").path),
           FileManager.default.fileExists(atPath: url.appendingPathComponent("HomeStuffInventoryApp.xcodeproj").path) {
            return url
        }
    }

    throw LocalizationTestError.repositoryRootNotFound
}

func localizationTestCatalog(at url: URL) throws -> [String: LocalizationCatalogEntry] {
    let data = try Data(contentsOf: url)
    let decoder = JSONDecoder()
    let catalog = try decoder.decode(LocalizationCatalog.self, from: data)
    return catalog.strings
}

func codeReferencedLocalizationTestKeys(in appURL: URL) throws -> Set<String> {
    let sourceURLs = try localizationTestSwiftSourceURLs(in: appURL)
    let keyPattern = #""((?:inventory|itemIcons|locationIcons|locations|settings)\.[^"\\]+)""#
    let keyRegex = try NSRegularExpression(pattern: keyPattern)
    var keys: Set<String> = []

    for sourceURL in sourceURLs {
        let source = try String(contentsOf: sourceURL, encoding: .utf8)
        let localizableSource = source
            .components(separatedBy: .newlines)
            .filter { !$0.contains(".accessibilityIdentifier(") }
            .joined(separator: "\n")
        let range = NSRange(localizableSource.startIndex..<localizableSource.endIndex, in: localizableSource)

        for match in keyRegex.matches(in: localizableSource, range: range) {
            guard let keyRange = Range(match.range(at: 1), in: localizableSource) else {
                continue
            }

            keys.insert(String(localizableSource[keyRange]))
        }
    }

    return keys
}

private func localizationTestSwiftSourceURLs(in appURL: URL) throws -> [URL] {
    guard let enumerator = FileManager.default.enumerator(
        at: appURL,
        includingPropertiesForKeys: [.isRegularFileKey],
        options: [.skipsHiddenFiles]
    ) else {
        throw LocalizationTestError.sourceEnumerationFailed
    }

    return try enumerator.compactMap { item in
        guard let url = item as? URL, url.pathExtension == "swift" else {
            return nil
        }

        let resourceValues = try url.resourceValues(forKeys: [.isRegularFileKey])
        return resourceValues.isRegularFile == true ? url : nil
    }
}

struct LocalizationCatalog: Decodable {
    let strings: [String: LocalizationCatalogEntry]
}

struct LocalizationCatalogEntry: Decodable {
    let localizations: [String: LocalizationValue]?

    func localizedValue(for language: String) -> String? {
        localizations?[language]?.stringUnit.value
    }
}

struct LocalizationValue: Decodable {
    let stringUnit: LocalizationStringUnit
}

struct LocalizationStringUnit: Decodable {
    let value: String
}

enum LocalizationTestError: Error {
    case repositoryRootNotFound
    case sourceEnumerationFailed
}
