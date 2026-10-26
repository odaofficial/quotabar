import AppKit
import QuotaBarCore

// SwiftPM keeps previews self-contained; packaged apps read the same SVGs from Contents/Resources.
@MainActor enum ProviderMark {
    private static let images: [Provider: NSImage] = Dictionary(uniqueKeysWithValues: Provider.allCases.compactMap { provider in
        guard let url = Bundle.main.url(forResource: provider.rawValue, withExtension: "svg", subdirectory: "ProviderMarks")
                        ?? Bundle.module.url(forResource: provider.rawValue, withExtension: "svg", subdirectory: "Resources"),
              let image = NSImage(contentsOf: url), image.isValid else { return nil }
        image.size = NSSize(width: 24, height: 24)
        image.isTemplate = true
        return (provider, image)
    })

    static func image(for provider: Provider) -> NSImage? { images[provider] }
}
