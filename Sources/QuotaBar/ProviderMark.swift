import AppKit
import QuotaBarCore

// SwiftPM keeps previews self-contained; packaged apps read the same SVGs from Contents/Resources.
@MainActor enum ProviderMark {
    private static let images: [Provider: NSImage] = Dictionary(uniqueKeysWithValues: Provider.allCases.compactMap { provider in
        #if QUOTABAR_PACKAGED
        let resourceURL = Bundle.main.url(forResource: provider.rawValue, withExtension: "svg", subdirectory: "ProviderMarks")
        #else
        let resourceURL = Bundle.module.url(forResource: provider.rawValue, withExtension: "svg", subdirectory: "Resources")
        #endif
        guard let url = resourceURL,
              let image = NSImage(contentsOf: url), image.isValid else { return nil }
        image.size = NSSize(width: 24, height: 24)
        image.isTemplate = true
        return (provider, image)
    })

    static func image(for provider: Provider) -> NSImage? { images[provider] }
}
