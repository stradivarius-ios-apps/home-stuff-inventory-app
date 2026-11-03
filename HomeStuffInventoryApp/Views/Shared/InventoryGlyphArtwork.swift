import ImageIO
import SwiftUI
import UIKit

struct InventoryGlyphArtwork: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.displayScale) private var displayScale

    let glyph: InventoryGlyph
    let variant: InventoryGlyph.Variant
    let tint: Color

    var body: some View {
        GeometryReader { geometry in
            let name = glyph.assetName(for: variant)
            let layout = InventoryGlyphRasterStore.layout(for: name)
            let side = min(geometry.size.width, geometry.size.height)
            let canvasSide = side * (20.0 / 24.0) / layout.bodyFraction
            let pixels = Int(ceil(canvasSide * displayScale / 32)) * 32
            if let image = InventoryGlyphRasterStore.image(named: name, maximumPixelSize: pixels) {
                artwork(image)
                    .frame(width: canvasSide, height: canvasSide)
                    .offset(x: layout.offsetX * canvasSide, y: layout.offsetY * canvasSide)
                    .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
        .clipped()
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func artwork(_ image: UIImage) -> some View {
        if variant == .material {
            source(image)
                .saturation(0)
                .brightness(colorScheme == .dark ? 0.16 : 0)
                .contrast(contrast == .increased ? 1.12 : 1)
                .overlay(Rectangle().fill(tint).blendMode(.color))
                .mask(source(image))
                .compositingGroup()
        } else {
            Image(uiImage: image)
                .renderingMode(.template)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .foregroundStyle(tint)
        }
    }

    private func source(_ image: UIImage) -> some View {
        Image(uiImage: image)
            .renderingMode(.original)
            .resizable()
            .aspectRatio(contentMode: .fit)
    }
}

@MainActor
private enum InventoryGlyphRasterStore {
    struct Layout: Decodable {
        let bodyFraction: CGFloat
        let offsetX: CGFloat
        let offsetY: CGFloat
    }

    private static let layouts: [String: Layout] = {
        guard let data = NSDataAsset(name: "InventoryGlyphLayout")?.data else { return [:] }
        return (try? JSONDecoder().decode([String: Layout].self, from: data)) ?? [:]
    }()

    private static let images: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.totalCostLimit = 24 * 1_024 * 1_024
        cache.countLimit = 192
        return cache
    }()

    static func layout(for name: String) -> Layout {
        layouts[name] ?? Layout(bodyFraction: 1, offsetX: 0, offsetY: 0)
    }

    static func image(named name: String, maximumPixelSize: Int) -> UIImage? {
        let pixels = min(1_024, max(32, maximumPixelSize))
        let key = "\(name):\(pixels)" as NSString
        if let image = images.object(forKey: key) { return image }
        guard let data = NSDataAsset(name: name)?.data,
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              let decoded = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: pixels,
                kCGImageSourceShouldCacheImmediately: true
              ] as CFDictionary) else { return nil }
        // Decode at display resolution; retain the original PNG dataset unchanged.
        let image = UIImage(cgImage: decoded)
        images.setObject(image, forKey: key, cost: decoded.bytesPerRow * decoded.height)
        return image
    }
}
