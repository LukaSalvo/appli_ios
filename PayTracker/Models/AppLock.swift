import Foundation
import LocalAuthentication

/// Face ID / Touch ID (or the device passcode) in front of the app's contents.
///
/// The app holds a salary, an account balance, a month of spending and a work
/// history — everything an unlocked, unattended iPhone would otherwise hand to
/// whoever picks it up. iOS's own device lock does not help here: once the phone
/// is unlocked, every app is open. This adds a second gate, off by default and
/// enabled from Réglages.
///
/// `.deviceOwnerAuthentication` (rather than `…WithBiometrics`) is deliberate:
/// it falls back to the passcode, so the lock still works when Face ID fails,
/// when the user has no biometrics enrolled, or after too many failed scans.
@MainActor
final class AppLock: ObservableObject {

    /// The `UserDefaults`/`@AppStorage` key the Réglages toggle writes to.
    static let enabledKey = "appLockEnabled"

    /// True while the contents must stay hidden behind the lock screen.
    @Published private(set) var isLocked: Bool
    /// Set while a system prompt is on screen, so we never stack two.
    @Published private(set) var isAuthenticating = false
    /// A short, user-facing reason the last attempt did not go through.
    @Published var failureMessage: String?

    init() {
        // Start locked whenever the feature is on: the very first frame after a
        // cold launch must not show any figures.
        isLocked = UserDefaults.standard.bool(forKey: Self.enabledKey)
    }

    // MARK: - Device capability

    /// Whether this device can run a biometric or passcode check at all. With no
    /// passcode set there is nothing to authenticate against, and offering the
    /// toggle would lock the user out of their own data.
    static var isAvailable: Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
    }

    /// "Face ID", "Touch ID", or the passcode wording — for labels only.
    static var methodLabel: String {
        let context = LAContext()
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil) else {
            return "code de l'iPhone"
        }
        switch context.biometryType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        default: return "code de l'iPhone"
        }
    }

    // MARK: - Locking

    /// Re-arm the lock — called when the app leaves the foreground.
    func lock() {
        guard UserDefaults.standard.bool(forKey: Self.enabledKey) else { return }
        isLocked = true
    }

    /// Drop the lock without a prompt — only when the user turns the feature off.
    func disable() {
        isLocked = false
        failureMessage = nil
    }

    /// Prompt for Face ID / Touch ID / passcode and unlock on success.
    func unlock() async {
        guard isLocked, !isAuthenticating else { return }
        isAuthenticating = true
        defer { isAuthenticating = false }

        if await evaluate(reason: "Déverrouillez pour consulter votre paie et votre budget.") {
            isLocked = false
            failureMessage = nil
        }
    }

    /// Confirms the user is the device owner *before* switching the lock on, so
    /// nobody can enable it on someone else's phone and lock them out.
    func confirmOwnership() async -> Bool {
        guard !isAuthenticating else { return false }
        isAuthenticating = true
        defer { isAuthenticating = false }
        return await evaluate(reason: "Confirmez votre identité pour activer le verrouillage.")
    }

    // MARK: - Private

    private func evaluate(reason: String) async -> Bool {
        // A fresh context per evaluation: LAContext caches a successful result,
        // and reusing one would let a single unlock satisfy later prompts.
        let context = LAContext()
        context.localizedCancelTitle = "Annuler"

        var policyError: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &policyError) else {
            failureMessage = "Aucun code n'est configuré sur cet iPhone."
            return false
        }

        let outcome: (success: Bool, errorCode: Int?) = await withCheckedContinuation { continuation in
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, error in
                continuation.resume(returning: (success, (error as NSError?)?.code))
            }
        }

        if outcome.success { return true }

        // Backing out of the prompt is a normal action, not an error to report.
        let silent = [
            LAError.Code.userCancel.rawValue,
            LAError.Code.appCancel.rawValue,
            LAError.Code.systemCancel.rawValue,
            LAError.Code.userFallback.rawValue
        ]
        if let code = outcome.errorCode, !silent.contains(code) {
            failureMessage = "Authentification impossible pour le moment."
        } else {
            failureMessage = nil
        }
        return false
    }
}
