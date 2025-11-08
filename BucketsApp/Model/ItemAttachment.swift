import Foundation

struct ItemAttachment: Identifiable, Codable, Hashable {
    enum Status: String, Codable {
        case pendingUpload
        case uploading
        case synced
        case failed
    }

    let id: UUID
    let itemID: UUID
    var localFileName: String
    var remoteURL: String?
    var status: Status
    var createdAt: Date
    var updatedAt: Date
    var retryCount: Int
}
