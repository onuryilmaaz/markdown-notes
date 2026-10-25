import SwiftUI
import PlainDesignSystem

struct PrivacyView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ScreenHeader(title: "Privacy policy", onBack: { dismiss() })
                section("Your notes", "Plain stores your notes on your device. If you enable iCloud sync, Apple stores and syncs your library in your private iCloud database. Plain has no account system or developer-operated notes server.")
                section("Purchases", "Apple processes payments. Plain reads verified App Store transactions to enable Pro and restore purchases. Plain does not receive your payment card details.")
                section("On-device assistance", "Optional writing assistance uses Apple Intelligence on supported devices. Plain does not send your notes to a developer-operated AI service.")
                section("Sharing and deletion", "Files you export or share go to the destination you choose. Deleted notes stay in Recently deleted for up to 30 days unless you delete them sooner. Delete everything in Settings removes your library; manage an active subscription separately in your Apple Account.")
                section("Tracking", "Plain includes no advertising, third-party analytics or tracking SDKs. It does not sell your notes or collect usage analytics.")
            }
            .padding(24)
            .frame(maxWidth: PlainLayout.maximumColumn, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .foregroundStyle(PlainPalette.ink)
        .plainGround()
        .toolbar(.hidden, for: .navigationBar)
    }

    private func section(_ title: LocalizedStringKey, _ text: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(PlainFont.headline)
            Text(text).font(PlainFont.body).foregroundStyle(PlainPalette.inkSecondary)
        }
    }
}
