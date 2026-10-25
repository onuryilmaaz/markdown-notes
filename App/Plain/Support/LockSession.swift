import Foundation
import Observation
import LocalAuthentication

/// Which locked notes have been opened since the app came to the front. Nothing
/// is persisted: locking again is the whole point of leaving the app.
@MainActor
@Observable
final class LockSession {
    private var unlocked: Set<UUID> = []
    private var generation = 0
    private(set) var errorMessage: String?

    func isUnlocked(_ id: UUID) -> Bool { unlocked.contains(id) }

    func lockAll() {
        generation += 1
        unlocked.removeAll()
        errorMessage = nil
    }

    func forget(_ id: UUID) { unlocked.remove(id) }

    /// Face ID, Touch ID, or the device passcode as the fallback — a device
    /// with no biometrics should still be able to open its own notes.
    func unlock(_ id: UUID) async -> Bool {
        await unlock([id])
    }

    /// Authenticate once for a user-requested library export, then grant access
    /// to only those notes for this foreground session.
    func unlock(_ ids: Set<UUID>) async -> Bool {
        guard !ids.isSubset(of: unlocked) else { return true }
        let attemptGeneration = generation
        errorMessage = nil
        let context = LAContext()
        context.localizedCancelTitle = String(localized: "Not now")

        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            errorMessage = "Set up a device passcode in Settings to unlock protected notes."
            return false
        }
        do {
            let success = try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: String(localized: "Open this note"))
            guard generation == attemptGeneration else { return false }
            if success { unlocked.formUnion(ids) }
            return success
        } catch {
            return false
        }
    }
}
