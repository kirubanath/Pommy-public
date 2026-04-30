import SwiftUI
import AppKit

/// Loads a PNG (or any image) from `Bundle.main` by filename (without extension).
///
/// SwiftUI's `Image(_:)` only finds images inside an `.xcassets` catalog.
/// For loose files copied to `Pommy.app/Contents/Resources/` by `build.sh`,
/// we load via `NSImage(contentsOf:)` and wrap in `Image(nsImage:)`.
@MainActor
struct BundleImage: View {
    let named: String

    private var nsImage: NSImage? {
        guard let url = Bundle.main.url(forResource: named, withExtension: "png") else {
            return nil
        }
        return NSImage(contentsOf: url)
    }

    var body: some View {
        if let img = nsImage {
            Image(nsImage: img)
                .resizable()
                .scaledToFit()
                .clipped()
        }
        // Silent fallback — EmptyView is cleaner than a broken photo icon
    }
}
