import Foundation

public enum TransferredRecordingImportError: Error, Equatable, UserFacingIdeaForgeError {
    case unreadableSource(String)
    case storage(StoragePreflightError)
    case copyFailed

    public var userFacingMessage: String {
        switch self {
        case .unreadableSource:
            return "Transferred recording could not be read."
        case .storage(let error):
            return error.userFacingMessage
        case .copyFailed:
            return "Transferred recording could not be imported."
        }
    }
}

public struct TransferredRecordingImporter: Sendable {
    public var inboxDirectory: URL
    public var storagePreflight: StoragePreflight

    public init(
        inboxDirectory: URL = TransferredRecordingImporter.applicationSupportInboxDirectory(),
        storagePreflight: StoragePreflight = .recordingImport()
    ) {
        self.inboxDirectory = inboxDirectory
        self.storagePreflight = storagePreflight
    }

    @MainActor
    @discardableResult
    public func importFile(
        sourceURL: URL,
        metadata: RecordingTransferMetadata,
        into store: IdeaForgeStore
    ) async throws -> IdeaProject {
        if let existingProject = store.projects.first(where: { project in
            project.recordings.contains { $0.id == metadata.recordingID }
        }) {
            IdeaForgeLog.recording.info("Skipped duplicate transferred recording import; project count: \(store.projects.count, privacy: .public)")
            return existingProject
        }

        guard FileManager.default.fileExists(atPath: sourceURL.path) else {
            throw TransferredRecordingImportError.unreadableSource(sourceURL.path)
        }

        let destinationURL = try copyIntoInbox(sourceURL: sourceURL, metadata: metadata)
        let recording = Recording(
            id: metadata.recordingID,
            ideaProjectID: metadata.ideaProjectID,
            deviceName: metadata.sourceDeviceName,
            durationSeconds: metadata.durationSeconds,
            localFileStatus: .available,
            syncStatus: .transferredToIPhone,
            localAudioPath: destinationURL.path,
            languageHint: metadata.languageHint,
            createdAt: metadata.createdAt,
            markerOffsets: metadata.markerOffsets
        )
        let transcript = Transcript(
            cleanText: "Voice idea transferred from \(metadata.sourceDeviceName).",
            segments: [
                TranscriptSegment(
                    id: "segment_\(metadata.recordingID)",
                    startSeconds: 0,
                    endSeconds: max(metadata.durationSeconds, 1),
                    text: "Voice idea transferred from \(metadata.sourceDeviceName).",
                    isMarkedImportant: !metadata.markerOffsets.isEmpty
                )
            ],
            unclearFragments: []
        )
        let draft = RecordingDraft(
            projectTitle: "Watch Idea",
            tag: .appIdea,
            source: .watch,
            durationSeconds: metadata.durationSeconds,
            transcriptHint: transcript.cleanText,
            localAudioPath: destinationURL.path,
            markerOffsets: metadata.markerOffsets,
            languageHint: metadata.languageHint
        )

        if store.projects.contains(where: { $0.id == metadata.ideaProjectID }) {
            store.attach(recording: recording, to: metadata.ideaProjectID, transcript: transcript)
            guard let updatedProject = store.projects.first(where: { $0.id == metadata.ideaProjectID }) else {
                throw TransferredRecordingImportError.copyFailed
            }
            return updatedProject
        }

        return store.createProject(from: draft, transcript: transcript, recording: recording)
    }

    private func copyIntoInbox(sourceURL: URL, metadata: RecordingTransferMetadata) throws -> URL {
        do {
            try storagePreflight.validateWritableVolume(
                for: inboxDirectory,
                estimatedWriteBytes: try sourceFileByteCount(sourceURL)
            )
            try FileManager.default.createDirectory(at: inboxDirectory, withIntermediateDirectories: true)
            let fileExtension = sourceURL.pathExtension.isEmpty ? "m4a" : sourceURL.pathExtension
            let destinationURL = inboxDirectory.appending(path: "\(metadata.recordingID).\(fileExtension)")
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
            return destinationURL
        } catch let error as StoragePreflightError {
            throw TransferredRecordingImportError.storage(error)
        } catch let error as TransferredRecordingImportError {
            throw error
        } catch {
            throw TransferredRecordingImportError.copyFailed
        }
    }

    private func sourceFileByteCount(_ sourceURL: URL) throws -> Int64 {
        let attributes = try FileManager.default.attributesOfItem(atPath: sourceURL.path)
        guard let byteCount = attributes[.size] as? NSNumber else {
            throw TransferredRecordingImportError.unreadableSource(sourceURL.path)
        }
        return byteCount.int64Value
    }

    public static func applicationSupportInboxDirectory(fileManager: FileManager = .default) -> URL {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        return base.appending(path: "IdeaForge/Recordings/Transferred", directoryHint: .isDirectory)
    }
}
