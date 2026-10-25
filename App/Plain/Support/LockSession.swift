import Foundation
import Observation
import LocalAuthentication

/// Which locked notes have been opened since the app came to the front. Nothing
/// is persisted: locking again is the whole point of leaving the app.
@MainActor
@Observable
final class LockSession {
    private var unlocked: Set<UUID> = []

    func isUnlocked(_ id: UUID) -> Bool { unlocked.contains(id) }

    func lockAll() { unlocked.removeAll() }

    func forget(_ id: UUID) { unlocked.remove(id) }

    /// Face ID, Touch ID, or the device passcode as the fallback — a device
    /// with no biometrics should still be able to open its own notes.
    func unlock(_ id: UUID) async -> Bool {
        let context = LAContext()
        context.localizedCancelTitle = "Not now"

        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            // No passcode set at all: there is nothing to check against, so the
            // lock would only be theatre.
            unlocked.insert(id)
            return true
        }
        do {
            let success = try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Open this note")
            if success { unlocked.insert(id) }
            return success
        } catch {
            return false
        }
    }
}
