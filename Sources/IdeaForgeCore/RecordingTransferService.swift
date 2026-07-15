import Foundation

public enum RecordingTransferStatus: String, Codable, Equatable, Sendable {
    case unavailable
    case queuedForTransfer
    case received
    case failed

    public var label: String {
        switch self {
        case .unavailable: "Unavailable"
        case .queuedForTransfer: "Queued for transfer"
        case .received: "Imported on iPhone"
        case .failed: "Retry needed"
        }
    }
}

public struct RecordingTransferMetadata: Codable, Equatable, Sendable {
    public var recordingID: String
    public var ideaProjectID: String
    public var sourceDeviceName: String
    public var durationSeconds: Int
    public var languageHint: String
    public var markerOffsets: [Int]
    public var createdAt: Date

    public init(
        recordingID: String,
        ideaProjectID: String,
        sourceDeviceName: String,
        durationSeconds: Int,
        languageHint: String,
        markerOffsets: [Int],
        createdAt: Date
    ) {
        self.recordingID = recordingID
        self.ideaProjectID = ideaProjectID
        self.sourceDeviceName = sourceDeviceName
        self.durationSeconds = durationSeconds
        self.languageHint = languageHint
        self.markerOffsets = markerOffsets
        self.createdAt = createdAt
    }

    public init(recording: Recording) {
        self.init(
            recordingID: recording.id,
            ideaProjectID: recording.ideaProjectID,
            sourceDeviceName: recording.deviceName,
            durationSeconds: recording.durationSeconds,
            languageHint: recording.languageHint,
            markerOffsets: recording.markerOffsets,
            createdAt: recording.createdAt
        )
    }

    public var watchConnectivityMetadata: [String: Any] {
        [
            "recordingID": recordingID,
            "ideaProjectID": ideaProjectID,
            "sourceDeviceName": sourceDeviceName,
            "durationSeconds": durationSeconds,
            "languageHint": languageHint,
            "markerOffsets": markerOffsets,
            "createdAt": createdAt.timeIntervalSince1970
        ]
    }

    public init?(watchConnectivityMetadata metadata: [String: Any]) {
        guard let recordingID = metadata["recordingID"] as? String,
              let ideaProjectID = metadata["ideaProjectID"] as? String,
              let sourceDeviceName = metadata["sourceDeviceName"] as? String,
              let durationSeconds = metadata["durationSeconds"] as? Int,
              let languageHint = metadata["languageHint"] as? String,
              let markerOffsets = metadata["markerOffsets"] as? [Int],
              let createdAtSeconds = metadata["createdAt"] as? TimeInterval else {
            return nil
        }

        self.init(
            recordingID: recordingID,
            ideaProjectID: ideaProjectID,
            sourceDeviceName: sourceDeviceName,
            durationSeconds: durationSeconds,
            languageHint: languageHint,
            markerOffsets: markerOffsets,
            createdAt: Date(timeIntervalSince1970: createdAtSeconds)
        )
    }
}

public struct RecordingTransferReceipt: Equatable, Sendable {
    public var recordingID: String
    public var status: RecordingTransferStatus

    public init(recordingID: String, status: RecordingTransferStatus) {
        self.recordingID = recordingID
        self.status = status
    }
}

public enum RecordingTransferImportResult: String, Codable, Equatable, Sendable {
    case imported
    case failed
}

public struct RecordingTransferImportAcknowledgement: Equatable, Sendable {
    private static let messageType = "recordingImportAcknowledgement"

    public var recordingID: String
    public var result: RecordingTransferImportResult

    public init(recordingID: String, result: RecordingTransferImportResult) {
        self.recordingID = recordingID
        self.result = result
    }

    public var watchConnectivityUserInfo: [String: Any] {
        [
            "messageType": Self.messageType,
            "recordingID": recordingID,
            "result": result.rawValue
        ]
    }

    public init?(watchConnectivityUserInfo userInfo: [String: Any]) {
        guard userInfo["messageType"] as? String == Self.messageType,
              let recordingID = userInfo["recordingID"] as? String,
              !recordingID.isEmpty,
              let rawResult = userInfo["result"] as? String,
              let result = RecordingTransferImportResult(rawValue: rawResult) else {
            return nil
        }
        self.init(recordingID: recordingID, result: result)
    }
}

enum RecordingTransferCompletionPolicy {
    static func transportCompletion(delivered: Bool) -> Bool? {
        delivered ? nil : false
    }

    static func importCompletion(for result: RecordingTransferImportResult) -> Bool {
        result == .imported
    }
}

public enum RecordingTransferError: Error, Equatable {
    case unsupportedPlatform
    case missingLocalAudioFile
    case inactiveSession
    case receivedFileStageFailed
}

public protocol RecordingTransferService {
    @MainActor func activate()
    @MainActor func transfer(recording: Recording) throws -> RecordingTransferReceipt
    @MainActor func setTransferCompletionHandler(_ handler: RecordingTransferCompletionHandler?)
}

extension RecordingTransferService {
    @MainActor
    public func setTransferCompletionHandler(_ handler: RecordingTransferCompletionHandler?) {}
}

public typealias RecordingTransferReceiveHandler = @MainActor @Sendable (URL, RecordingTransferMetadata) async -> RecordingTransferImportResult

/// Called after transport fails or the receiving app acknowledges its import.
/// `imported` is true only after the recording is durable in the receiving workspace.
public typealias RecordingTransferCompletionHandler = @MainActor @Sendable (_ recordingID: String, _ imported: Bool) -> Void

public struct UnavailableRecordingTransferService: RecordingTransferService {
    public init() {}

    @MainActor
    public func activate() {}

    @MainActor
    public func transfer(recording: Recording) throws -> RecordingTransferReceipt {
        throw RecordingTransferError.unsupportedPlatform
    }
}

enum RecordingTransferFileStager {
    static func stageReceivedFileForImport(
        sourceURL: URL,
        metadata: RecordingTransferMetadata,
        fileManager: FileManager = .default,
        rootDirectory: URL? = nil
    ) throws -> URL {
        guard fileManager.fileExists(atPath: sourceURL.path) else {
            throw RecordingTransferError.missingLocalAudioFile
        }

        let root = rootDirectory
            ?? fileManager.temporaryDirectory.appending(path: "IdeaForge/WatchConnectivity/Received", directoryHint: .isDirectory)
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)

        let fileExtension = sourceURL.pathExtension.isEmpty ? "m4a" : sourceURL.pathExtension
        let destinationURL = root.appending(
            path: "\(metadata.recordingID)-\(UUID().uuidString).\(fileExtension)"
        )
        try fileManager.copyItem(at: sourceURL, to: destinationURL)
        return destinationURL
    }

    @discardableResult
    static func discardStagedFileAfterImport(
        _ stagedURL: URL,
        fileManager: FileManager = .default
    ) -> Bool {
        guard fileManager.fileExists(atPath: stagedURL.path) else {
            return true
        }
        do {
            try fileManager.removeItem(at: stagedURL)
            return true
        } catch {
            return false
        }
    }
}

public enum RecordingTransferServiceFactory {
    @MainActor
    public static func platformDefault(
        receiveHandler: RecordingTransferReceiveHandler? = nil
    ) -> any RecordingTransferService {
        #if canImport(WatchConnectivity) && (os(iOS) || os(watchOS))
        return WatchConnectivityRecordingTransferService(receiveHandler: receiveHandler)
        #else
        return UnavailableRecordingTransferService()
        #endif
    }
}

#if canImport(WatchConnectivity) && (os(iOS) || os(watchOS))
@preconcurrency import WatchConnectivity

public final class WatchConnectivityRecordingTransferService: NSObject, RecordingTransferService, @unchecked Sendable {
    private let session: WCSession?
    private let receiveHandler: RecordingTransferReceiveHandler?
    @MainActor private var transferCompletionHandler: RecordingTransferCompletionHandler?
    @MainActor public private(set) var receivedTransfers: [RecordingTransferMetadata] = []

    public init(
        session: WCSession? = WCSession.isSupported() ? .default : nil,
        receiveHandler: RecordingTransferReceiveHandler? = nil
    ) {
        self.session = session
        self.receiveHandler = receiveHandler
        super.init()
    }

    @MainActor
    public func activate() {
        guard let session else { return }
        session.delegate = self
        session.activate()
    }

    @MainActor
    public func setTransferCompletionHandler(_ handler: RecordingTransferCompletionHandler?) {
        transferCompletionHandler = handler
    }

    @MainActor
    public func transfer(recording: Recording) throws -> RecordingTransferReceipt {
        guard let session else {
            throw RecordingTransferError.unsupportedPlatform
        }
        guard session.activationState != .notActivated else {
            throw RecordingTransferError.inactiveSession
        }
        guard let localAudioPath = recording.localAudioPath else {
            throw RecordingTransferError.missingLocalAudioFile
        }

        let fileURL = URL(fileURLWithPath: localAudioPath)
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw RecordingTransferError.missingLocalAudioFile
        }

        _ = session.transferFile(
            fileURL,
            metadata: RecordingTransferMetadata(recording: recording).watchConnectivityMetadata
        )
        return RecordingTransferReceipt(recordingID: recording.id, status: .queuedForTransfer)
    }
}

extension WatchConnectivityRecordingTransferService: WCSessionDelegate {
    public nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {}

    public nonisolated func session(_ session: WCSession, didFinish fileTransfer: WCSessionFileTransfer, error: Error?) {
        guard let metadata = RecordingTransferMetadata(watchConnectivityMetadata: fileTransfer.file.metadata ?? [:]) else {
            return
        }
        let delivered = error == nil
        guard let completion = RecordingTransferCompletionPolicy.transportCompletion(delivered: delivered) else {
            IdeaForgeLog.sync.info("Watch recording transport completed; awaiting iPhone import acknowledgement")
            return
        }
        if !completion {
            IdeaForgeLog.sync.error("Watch recording transfer finished with delivery failure")
        }
        Task { @MainActor [weak self] in
            self?.transferCompletionHandler?(metadata.recordingID, completion)
        }
    }

    public nonisolated func session(_ session: WCSession, didReceive file: WCSessionFile) {
        guard let metadata = RecordingTransferMetadata(watchConnectivityMetadata: file.metadata ?? [:]) else {
            return
        }
        let stagedFileURL: URL
        do {
            stagedFileURL = try RecordingTransferFileStager.stageReceivedFileForImport(
                sourceURL: file.fileURL,
                metadata: metadata
            )
        } catch {
            IdeaForgeLog.sync.error("Watch recording transfer staging failed")
            _ = session.transferUserInfo(
                RecordingTransferImportAcknowledgement(
                    recordingID: metadata.recordingID,
                    result: .failed
                )
                .watchConnectivityUserInfo
            )
            return
        }

        Task { @MainActor [weak self] in
            guard let self else {
                _ = RecordingTransferFileStager.discardStagedFileAfterImport(stagedFileURL)
                return
            }
            let result = await self.receiveHandler?(stagedFileURL, metadata) ?? .failed
            if result == .imported {
                self.receivedTransfers.append(metadata)
            } else {
                IdeaForgeLog.sync.error("Watch recording reached iPhone but workspace import failed")
            }
            if !RecordingTransferFileStager.discardStagedFileAfterImport(stagedFileURL) {
                IdeaForgeLog.sync.error("Watch recording transfer staging cleanup failed")
            }
            _ = session.transferUserInfo(
                RecordingTransferImportAcknowledgement(
                    recordingID: metadata.recordingID,
                    result: result
                )
                .watchConnectivityUserInfo
            )
        }
    }

    public nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        guard let acknowledgement = RecordingTransferImportAcknowledgement(
            watchConnectivityUserInfo: userInfo
        ) else {
            return
        }
        let imported = RecordingTransferCompletionPolicy.importCompletion(for: acknowledgement.result)
        Task { @MainActor [weak self] in
            self?.transferCompletionHandler?(acknowledgement.recordingID, imported)
        }
    }

    #if os(iOS)
    public nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    public nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
    #endif
}
#endif
