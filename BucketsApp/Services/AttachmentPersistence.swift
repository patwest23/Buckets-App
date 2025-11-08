import Foundation

actor AttachmentPersistence {
    static let shared = AttachmentPersistence()

    private let directoryURL: URL
    private let metadataURL: URL
    private var attachments: [UUID: ItemAttachment] = [:]

    init() {
        let fileManager = FileManager.default
        let baseDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? fileManager.temporaryDirectory
        let attachmentsDirectory = baseDirectory.appendingPathComponent("Attachments", isDirectory: true)
        directoryURL = attachmentsDirectory
        metadataURL = attachmentsDirectory.appendingPathComponent("attachments.json")

        do {
            try fileManager.createDirectory(at: attachmentsDirectory, withIntermediateDirectories: true)
        } catch {
            print("[AttachmentPersistence] Failed to create attachments directory:", error.localizedDescription)
        }

        do {
            try loadFromDisk()
        } catch {
            print("[AttachmentPersistence] Failed to load metadata from disk:", error.localizedDescription)
        }
    }

    // MARK: - Loading & Persistence
    private func loadFromDisk() throws {
        guard FileManager.default.fileExists(atPath: metadataURL.path) else { return }
        let data = try Data(contentsOf: metadataURL)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode([ItemAttachment].self, from: data)
        attachments = Dictionary(uniqueKeysWithValues: decoded.map { ($0.id, $0) })
    }

    private func persistToDisk() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(Array(attachments.values))
            try data.write(to: metadataURL, options: [.atomic])
        } catch {
            print("[AttachmentPersistence] Failed to persist metadata:", error.localizedDescription)
        }
    }

    // MARK: - Querying
    func allAttachments() -> [ItemAttachment] {
        Array(attachments.values)
    }

    func attachments(for itemID: UUID) -> [ItemAttachment] {
        attachments.values.filter { $0.itemID == itemID }
    }

    func attachment(withID id: UUID) -> ItemAttachment? {
        attachments[id]
    }

    // MARK: - Creation
    func createAttachment(for itemID: UUID, imageData: Data) throws -> ItemAttachment {
        let id = UUID()
        let fileName = id.uuidString + ".jpg"
        let fileURL = directoryURL.appendingPathComponent(fileName)

        do {
            try imageData.write(to: fileURL, options: [.atomic])
        } catch {
            print("[AttachmentPersistence] Failed to write image data:", error.localizedDescription)
            throw error
        }

        let now = Date()
        let attachment = ItemAttachment(
            id: id,
            itemID: itemID,
            localFileName: fileName,
            remoteURL: nil,
            status: .pendingUpload,
            createdAt: now,
            updatedAt: now,
            retryCount: 0
        )
        attachments[id] = attachment
        persistToDisk()
        return attachment
    }

    // MARK: - Updates
    func updateStatus(for id: UUID, to status: ItemAttachment.Status) {
        guard var attachment = attachments[id] else { return }
        attachment.status = status
        attachment.updatedAt = Date()
        attachments[id] = attachment
        persistToDisk()
    }

    func setRemoteURL(_ url: String, for id: UUID) {
        guard var attachment = attachments[id] else { return }
        attachment.remoteURL = url
        attachment.status = .synced
        attachment.updatedAt = Date()
        attachments[id] = attachment
        persistToDisk()
    }

    func incrementRetryCount(for id: UUID) {
        guard var attachment = attachments[id] else { return }
        attachment.retryCount += 1
        attachment.status = .failed
        attachment.updatedAt = Date()
        attachments[id] = attachment
        persistToDisk()
    }

    // MARK: - Removal
    func removeAttachment(_ id: UUID) {
        guard let attachment = attachments.removeValue(forKey: id) else { return }
        persistToDisk()
        let fileURL = directoryURL.appendingPathComponent(attachment.localFileName)
        try? FileManager.default.removeItem(at: fileURL)
    }

    func removeAllAttachments(for itemID: UUID) {
        let idsToRemove = attachments.values.filter { $0.itemID == itemID }.map { $0.id }
        idsToRemove.forEach { removeAttachment($0) }
    }

    // MARK: - File URLs
    func fileURL(for id: UUID) -> URL? {
        guard let attachment = attachments[id] else { return nil }
        return directoryURL.appendingPathComponent(attachment.localFileName)
    }
}
