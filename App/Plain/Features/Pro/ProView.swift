import SwiftUI
import StoreKit
import PlainDesignSystem

struct ProView: View {
    var feature: ProFeature?
    @Environment(PurchaseStore.self) private var purchases
    @Environment(\.dismiss) private var dismiss
    @State private var selection: PurchaseStore.Plan = .annual
    @State private var showingPrivacy = false
    @State private var showingSubscriptions = false

    private var selectedProduct: Product? { purchases.product(for: selection) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack {
                        Text("PLAIN PRO")
                            .font(PlainFont.sans(11, .bold)).tracking(2)
                        Spacer()
                        CircleIconButton("xmark", label: "Close", size: 36) { dismiss() }
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        Text(LocalizedStringKey(feature?.title ?? "Make space for your best work"))
                            .font(PlainFont.display)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("Your everyday notebook is free. Pro adds the tools for the work you care about.")
                            .font(PlainFont.callout)
                            .foregroundStyle(PlainPalette.inkSecondary)
                    }
                    VStack(alignment: .leading, spacing: 20) {
                        ForEach(ProFeature.allCases) { item in
                            HStack(alignment: .top, spacing: 14) {
                                Image(systemName: item.symbol)
                                    .font(.system(size: 18, weight: .medium))
                                    .frame(width: 26, height: 26)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(LocalizedStringKey(item.name)).font(PlainFont.label)
                                    Text(LocalizedStringKey(item.detail))
                                        .font(PlainFont.callout)
                                        .foregroundStyle(PlainPalette.inkSecondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }
                    .padding(20).plainCard()

                    if purchases.hasPro {
                        Label("Your Pro subscription is active. Thank you for supporting Plain.", systemImage: "checkmark.circle.fill")
                            .font(PlainFont.body)
                        Button("Manage subscription") { showingSubscriptions = true }
                            .font(PlainFont.label)
                    } else {
                        plans
                    }

                    if let notice = purchases.notice {
                        Text(LocalizedStringKey(notice.text))
                            .font(PlainFont.callout)
                            .foregroundStyle(PlainPalette.inkSecondary)
                            .accessibilityIdentifier("pro-notice")
                    }

                    Text("Unlimited notes, folders, tags, search, iCloud sync and Markdown backups stay free. Your notes remain yours when Pro ends.")
                        .font(PlainFont.meta)
                        .foregroundStyle(PlainPalette.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    footer
                }
                .foregroundStyle(PlainPalette.ink)
                .padding(24)
                .frame(maxWidth: PlainLayout.maximumColumn, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .plainGround()
            .safeAreaInset(edge: .bottom) { purchaseBar }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $showingPrivacy) { PrivacyView() }
            .manageSubscriptionsSheet(isPresented: $showingSubscriptions)
        }
        .task {
            if purchases.products.isEmpty { await purchases.loadProducts() }
            if selectedProduct == nil, let available = PurchaseStore.Plan.allCases.first(where: { purchases.product(for: $0) != nil }) {
                selection = available
            }
        }
        .onChange(of: purchases.hasPro) { _, active in
            if active { dismiss() }
        }
        .interactiveDismissDisabled(purchases.isPurchasing)
    }

    @ViewBuilder
    private var purchaseBar: some View {
        if !purchases.hasPro, let product = selectedProduct {
            VStack(spacing: 10) {
                Button {
                    Task { await purchases.purchase(product) }
                } label: {
                    HStack(spacing: 8) {
                        if purchases.isPurchasing { ProgressView().tint(PlainPalette.onEmphasis) }
                        Text(selection == .annual ? "Get Pro for a year" : "Get Pro for a month")
                        Spacer(minLength: 8)
                        Text(verbatim: product.displayPrice)
                    }
                    .font(PlainFont.button)
                    .foregroundStyle(PlainPalette.onEmphasis)
                    .padding(.horizontal, 22)
                    .frame(minHeight: Metrics.controlHeight)
                    .background(PlainPalette.emphasis, in: .capsule)
                }
                .buttonStyle(PressableButtonStyle())
                .disabled(purchases.isPurchasing || !purchases.hasCheckedAccess)
                .opacity(purchases.isPurchasing ? 0.5 : 1)
                .accessibilityIdentifier("pro-purchase")
                Text(selection == .annual
                     ? "Billed yearly. Renews automatically unless canceled at least 24 hours before renewal. Manage or cancel in App Store settings."
                     : "Billed monthly. Renews automatically unless canceled at least 24 hours before renewal. Manage or cancel in App Store settings.")
                    .font(PlainFont.meta)
                    .foregroundStyle(PlainPalette.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(PlainPalette.ground)
        }
    }

    @ViewBuilder
    private var plans: some View {
        if purchases.isLoading {
            ProgressView().frame(maxWidth: .infinity).padding()
        } else if purchases.products.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("The App Store could not load the available plans.")
                    .font(PlainFont.callout)
                Button("Try again") { Task { await purchases.loadProducts() } }
                    .font(PlainFont.label)
            }
        } else {
            VStack(spacing: 10) {
                ForEach(PurchaseStore.Plan.allCases) { plan in
                    if let product = purchases.product(for: plan) {
                        Button { selection = plan } label: {
                            HStack(spacing: 12) {
                                Image(systemName: selection == plan ? "checkmark.circle.fill" : "circle")
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(plan == .annual ? "Yearly" : "Monthly").font(PlainFont.label)
                                    Text(plan == .annual ? "Billed once a year" : "Billed once a month")
                                        .font(PlainFont.meta)
                                        .foregroundStyle(PlainPalette.inkSecondary)
                                }
                                Spacer(minLength: 4)
                                Text(verbatim: product.displayPrice).font(PlainFont.headline)
                            }
                            .foregroundStyle(PlainPalette.ink)
                            .padding(16)
                            .plainCard(radius: 20)
                            .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(selection == plan ? PlainPalette.ink : .clear, lineWidth: 1.5))
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("pro-plan-\(plan.rawValue)")
                        .accessibilityAddTraits(selection == plan ? .isSelected : [])
                    }
                }
            }
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 16) {
            Button("Restore purchases") { Task { await purchases.restore() } }
                .disabled(purchases.isPurchasing)
                .accessibilityIdentifier("pro-restore")
            HStack(spacing: 20) {
                Button("Privacy policy") { showingPrivacy = true }
                Link("Terms of use", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
            }
        }
        .font(PlainFont.meta)
        .foregroundStyle(PlainPalette.inkSecondary)
    }
}

/// Reusable gate at the destination, so routes cannot bypass Pro access.
struct ProAccessView<Content: View>: View {
    let feature: ProFeature
    @ViewBuilder var content: () -> Content
    @Environment(PurchaseStore.self) private var purchases
    @Environment(Router.self) private var router

    var body: some View {
        if purchases.hasPro {
            content()
        } else {
            PlainScreen {
                VStack(spacing: 20) {
                    ScreenHeader(title: LocalizedStringKey(feature.name), onBack: { router.pop() })
                    Spacer()
                    Image(systemName: feature.symbol).font(.system(size: 38, weight: .light))
                    Text(LocalizedStringKey(feature.title)).font(PlainFont.title).multilineTextAlignment(.center)
                    Text(LocalizedStringKey(feature.detail)).font(PlainFont.body).multilineTextAlignment(.center)
                        .foregroundStyle(PlainPalette.inkSecondary)
                    PillButton("Explore Plain Pro") { router.present(.pro(feature)) }
                        .padding(.horizontal, 24)
                    Spacer()
                }
                .padding(.horizontal, 20)
            }
        }
    }
}
