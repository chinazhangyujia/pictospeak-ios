import Foundation

struct Material: Codable, Identifiable {
    let id: UUID
    let materialUrl: String
    let type: MediaType
    let thumbnailUrl: String?

    enum CodingKeys: String, CodingKey {
        case id
        case materialUrl = "material_url"
        case type
        case thumbnailUrl = "thumbnail_url"
    }
}

enum MediaType: String, Codable {
    case image = "IMAGE"
    case video = "VIDEO"

    var displayName: String {
        switch self {
        case .image:
            return "Image"
        case .video:
            return "Video"
        }
    }

    var systemIconName: String {
        switch self {
        case .image:
            return "photo"
        case .video:
            return "video"
        }
    }
}
