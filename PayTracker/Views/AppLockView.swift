import SwiftUI

/// The screen shown in place of the app while it is locked.
struct AppLockView: View {
    @ObservedObject var lock: AppLock

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 18) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(Color.appAccent)

                Text("Paie Horaire est verrouillée")
                    .font(.headline)

                Text("Vos revenus, votre solde et vos dépenses sont masqués tant que vous ne vous êtes pas authentifié.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                if let failure = lock.failureMessage {
                    Text(failure)
                        .font(.caption)
                        .foregroundStyle(Color.moneyDanger)
                }

                Button {
                    Task { await lock.unlock() }
                } label: {
                    Label("Déverrouiller avec \(AppLock.methodLabel)", systemImage: "faceid")
                        .font(.headline)
                        .padding(.horizontal, 8)
                }
                .buttonStyle(.borderedProminent)
                .tint(.appAccent)
                .controlSize(.large)
                .disabled(lock.isAuthenticating)
            }
        }
    }
}

/// An opaque cover drawn while the app is not frontmost.
///
/// iOS snapshots the app when it goes to the background — for the app switcher,
/// and the snapshot is written to disk. Without this, that thumbnail keeps a
/// readable copy of the salary and balance, visible to anyone who double-taps
/// the Home indicator. Covering the window before the snapshot is taken means
/// the stored image shows only this.
struct PrivacyShadeView: View {
    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            VStack(spacing: 12) {
                Image(systemName: "eurosign.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(Color.appAccent)
                Text("Paie Horaire")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview("Verrouillé") {
    AppLockView(lock: AppLock())
}

#Preview("Écran de confidentialité") {
    PrivacyShadeView()
}
