import Foundation
import UIKit

struct StoredImagePaths: Equatable {
    let photoPath: String
    let thumbnailPath: String
}

enum ImageStore {
    private static let directoryName = "PocketClosetImages"

    static func save(image: UIImage, id: UUID = UUID()) throws -> StoredImagePaths {
        let folderURL = try imagesDirectory()
        let photoPath = "\(id.uuidString)-photo.jpg"
        let thumbnailPath = "\(id.uuidString)-thumb.jpg"
        let photoURL = folderURL.appendingPathComponent(photoPath)
        let thumbURL = folderURL.appendingPathComponent(thumbnailPath)

        let fullImage = image.resized(maxLongEdge: 1600)
        let thumbnail = image.resized(maxLongEdge: 520)

        guard
            let fullData = fullImage.jpegData(compressionQuality: 0.82),
            let thumbData = thumbnail.jpegData(compressionQuality: 0.78)
        else {
            throw ImageStoreError.encodingFailed
        }

        try fullData.write(to: photoURL, options: [.atomic])
        try thumbData.write(to: thumbURL, options: [.atomic])

        return StoredImagePaths(
            photoPath: "\(directoryName)/\(photoPath)",
            thumbnailPath: "\(directoryName)/\(thumbnailPath)"
        )
    }

    static func load(relativePath: String?) -> UIImage? {
        guard let url = url(for: relativePath) else { return nil }
        return UIImage(contentsOfFile: url.path)
    }

    static func delete(relativePath: String?) {
        guard let url = url(for: relativePath) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    static func delete(paths: StoredImagePaths) {
        delete(relativePath: paths.photoPath)
        delete(relativePath: paths.thumbnailPath)
    }

    static func makePlaceholderImage(color: UIColor, symbolName: String = "tshirt") -> UIImage {
        let size = CGSize(width: 900, height: 900)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))

            let symbolConfiguration = UIImage.SymbolConfiguration(pointSize: 220, weight: .regular)
            let symbol = UIImage(systemName: symbolName, withConfiguration: symbolConfiguration)?
                .withTintColor(.white.withAlphaComponent(0.82), renderingMode: .alwaysOriginal)
            let symbolSize = symbol?.size ?? .zero
            let rect = CGRect(
                x: (size.width - symbolSize.width) / 2,
                y: (size.height - symbolSize.height) / 2,
                width: symbolSize.width,
                height: symbolSize.height
            )
            symbol?.draw(in: rect)
        }
    }

    private static func url(for relativePath: String?) -> URL? {
        guard let relativePath else { return nil }
        let components = relativePath.split(separator: "/", maxSplits: 1).map(String.init)
        guard components.count == 2, components[0] == directoryName else { return nil }
        return try? imagesDirectory().appendingPathComponent(components[1])
    }

    private static func imagesDirectory() throws -> URL {
        let supportURL = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let imagesURL = supportURL.appendingPathComponent(directoryName, isDirectory: true)
        if !FileManager.default.fileExists(atPath: imagesURL.path) {
            try FileManager.default.createDirectory(at: imagesURL, withIntermediateDirectories: true)
        }
        return imagesURL
    }
}

enum ImageStoreError: Error {
    case encodingFailed
}

private extension UIImage {
    func resized(maxLongEdge: CGFloat) -> UIImage {
        let longEdge = max(size.width, size.height)
        guard longEdge > maxLongEdge else { return self }

        let scale = maxLongEdge / longEdge
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1

        return UIGraphicsImageRenderer(size: newSize, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
