import Foundation
import SwiftUI
import UserNotifications

#if canImport(UIKit)
import UIKit

private final class BackgroundSessionCompletionHandler: @unchecked Sendable {
    private let handler: () -> Void

    init(_ handler: @escaping () -> Void) {
        self.handler = handler
    }

    func callAsFunction() {
        handler()
    }
}

@MainActor
final class PushNotificationTokenCenter: ObservableObject {
    static let shared = PushNotificationTokenCenter()

    @Published private(set) var deviceToken: Data?
    @Published private(set) var registrationFailureMessage: String?
    private var remoteNotificationHandler: ((RemotePushNotificationTrigger) async -> UIBackgroundFetchResult)?

    private init() {}

    func didRegister(deviceToken: Data) {
        self.deviceToken = deviceToken
        registrationFailureMessage = nil
        IdeaForgeLog.sync.info("iOS remote notification device token received")
    }

    func didFailToRegister(error: Error) {
        registrationFailureMessage = "APNs did not return a device token."
        IdeaForgeLog.sync.error("iOS remote notification registration failed")
    }

    func installRemoteNotificationHandler(_ handler: @escaping (RemotePushNotificationTrigger) async -> UIBackgroundFetchResult) {
        remoteNotificationHandler = handler
    }

    func handleRemoteNotification(_ decision: RemotePushNotificationPayloadDecision) async -> UIBackgroundFetchResult {
        switch decision {
        case .accepted(let trigger):
            guard let remoteNotificationHandler else {
                IdeaForgeLog.sync.warning("iOS remote notification ignored; handler unavailable")
                return .noData
            }
            return await remoteNotificationHandler(trigger)
        case .ignored(let blocker):
            IdeaForgeLog.sync.warning("iOS remote notification ignored; blocker: \(blocker.rawValue, privacy: .public)")
            return .noData
        }
    }
}

final class IdeaForgePushNotificationAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        handleEventsForBackgroundURLSession identifier: String,
        completionHandler: @escaping () -> Void
    ) {
        guard identifier == URLSessionHTTPDataTransport.backgroundSessionIdentifier else {
            completionHandler()
            return
        }
        let completion = BackgroundSessionCompletionHandler(completionHandler)
        URLSessionHTTPDataTransport.shared.installBackgroundEventsCompletionHandler {
            DispatchQueue.main.async {
                completion()
            }
        }
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Task { @MainActor in
            PushNotificationTokenCenter.shared.didRegister(deviceToken: deviceToken)
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        Task { @MainActor in
            PushNotificationTokenCenter.shared.didFailToRegister(error: error)
        }
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        let decision = RemotePushNotificationPayloadParser.parse(userInfo: userInfo)
        Task { @MainActor in
            let result = await PushNotificationTokenCenter.shared.handleRemoteNotification(decision)
            completionHandler(result)
        }
    }
}

enum PushNotificationAuthorizationRequester {
    static func authorizeAndRequestDeviceToken() async throws -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()

        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            break
        case .notDetermined:
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            guard granted else { return false }
        case .denied:
            return false
        @unknown default:
            return false
        }

        await MainActor.run {
            UIApplication.shared.registerForRemoteNotifications()
        }
        return true
    }
}
#endif
