import Combine
import SwiftUI

class ImageLoader: ObservableObject {
    @Published var image: UIImage?

    private let url: URL?
    private var cancellable: AnyCancellable?
    private static let cache = NSCache<NSString, UIImage>()

    init(url: URL?) {
        self.url = url
    }

    deinit {
        cancel()
    }

    func load() {
        guard let url = url else { return }

        // Check memory cache first
        if let cachedImage = Self.cache.object(forKey: url.absoluteString as NSString) {
            image = cachedImage
            return
        }

        // Download if not in cache
        cancellable = URLSession.shared.dataTaskPublisher(for: url)
            .map { UIImage(data: $0.data) }
            .replaceError(with: nil)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] image in
                guard let self = self, let image = image else { return }
                Self.cache.setObject(image, forKey: url.absoluteString as NSString)
                self.image = image
            }
    }

    func cancel() {
        cancellable?.cancel()
    }
}

struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    private let url: URL?
    private let content: (Image) -> Content
    private let placeholder: () -> Placeholder

    @StateObject private var loader: ImageLoader

    init(
        url: URL?,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
        _loader = StateObject(wrappedValue: ImageLoader(url: url))
    }

    var body: some View {
        Group {
            if let uiImage = loader.image {
                content(Image(uiImage: uiImage))
            } else {
                placeholder()
            }
        }
        .onAppear {
            loader.load()
        }
    }
}
