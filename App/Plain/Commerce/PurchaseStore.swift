import Foundation
import Observation
import StoreKit

/// Access comes exclusively from App Store verified transactions. No persisted
/// Boolean can unlock Pro, and refunds/expiration are observed while running.
@MainActor
@Observable
final class PurchaseStore {
    enum Plan: String, CaseIterable, Identifiable {
        case monthly, annual
        var id: String { rawValue }
        var productID: String {
            let bundle = Bundle.main.bundleIdentifier ?? "com.onur6541.plain"
            return "\(bundle).pro.\(rawValue)"
        }
    }

    enum Notice: Equatable {
        case unavailable, failed, unverified, pending, restored, nothingToRestore
        var text: String {
            switch self {
            case .unavailable: "Purchases are unavailable right now. Please try again."
            case .failed: "The purchase could not be completed. You have not unlocked Pro."
            case .unverified: "Apple could not verify this purchase. Please try restoring purchases."
            case .pending: "Your purchase is awaiting approval. Pro will unlock when Apple confirms it."
            case .restored: "Your Pro purchase has been restored."
            case .nothingToRestore: "No active Pro purchase was found for this Apple Account."
            }
        }
    }

    private(set) var products: [Product] = []
    private(set) var purchasedIDs: Set<String> = []
    private(set) var hasCheckedAccess = false
    private(set) var isLoading = false
    private(set) var isPurchasing = false
    var notice: Notice?

    @ObservationIgnored private var updatesTask: Task<Void, Never>?
    @ObservationIgnored private var expirationTask: Task<Void, Never>?
    @ObservationIgnored private var refreshGeneration = 0

    var hasPro: Bool { !purchasedIDs.isEmpty }

    init() {
        updatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                guard !Task.isCancelled else { return }
                guard case .verified(let transaction) = result,
                      Plan.allCases.contains(where: { $0.productID == transaction.productID }) else { continue }
                await self?.refreshEntitlements()
                await transaction.finish()
            }
        }
    }

    deinit {
        updatesTask?.cancel()
        expirationTask?.cancel()
    }

    func product(for plan: Plan) -> Product? {
        products.first { $0.id == plan.productID }
    }

    func prepare() async {
        await refreshEntitlements()
        // Recover a transaction interrupted between granting access and finish.
        for await result in Transaction.unfinished {
            guard case .verified(let transaction) = result,
                  Plan.allCases.contains(where: { $0.productID == transaction.productID }) else { continue }
            await transaction.finish()
        }
        await loadProducts()
    }

    func loadProducts() async {
        guard !isLoading else { return }
        isLoading = true
        notice = nil
        defer { isLoading = false }
        do {
            products = try await Product.products(for: Plan.allCases.map(\.productID)).filter(isExpectedProduct)
            if products.isEmpty { notice = .unavailable }
        } catch {
            notice = .unavailable
        }
    }

    func refreshEntitlements() async {
        refreshGeneration += 1
        let generation = refreshGeneration
        var verified: Set<String> = []
        var nextExpiration: Date?
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  transaction.productType == .autoRenewable,
                  transaction.revocationDate == nil,
                  !transaction.isUpgraded,
                  Plan.allCases.contains(where: { $0.productID == transaction.productID }) else { continue }
            // StoreKit's currentEntitlements also includes a subscription in its
            // billing grace period; preserve that entitlement until Apple ends it.
            verified.insert(transaction.productID)
            if let date = transaction.expirationDate, date > .now {
                nextExpiration = min(nextExpiration ?? date, date)
            }
        }
        guard generation == refreshGeneration else { return }
        purchasedIDs = verified
        hasCheckedAccess = true
        expirationTask?.cancel()
        if let nextExpiration {
            expirationTask = Task { [weak self] in
                do { try await Task.sleep(for: .seconds(max(nextExpiration.timeIntervalSinceNow + 1, 1))) }
                catch { return }
                await self?.refreshEntitlements()
            }
        }
    }

    func purchase(_ product: Product) async {
        guard !isPurchasing, isExpectedProduct(product) else { return }
        isPurchasing = true
        notice = nil
        defer { isPurchasing = false }
        do {
            switch try await product.purchase() {
            case .success(let result):
                guard case .verified(let transaction) = result else {
                    notice = .unverified
                    return
                }
                await refreshEntitlements()
                await transaction.finish()
            case .pending:
                notice = .pending
            case .userCancelled:
                break
            @unknown default:
                notice = .failed
            }
        } catch {
            notice = .failed
        }
    }

    func restore() async {
        guard !isPurchasing else { return }
        isPurchasing = true
        notice = nil
        defer { isPurchasing = false }
        do {
            // sync may request Apple Account authentication; only call on tap.
            try await AppStore.sync()
            await refreshEntitlements()
            notice = hasPro ? .restored : .nothingToRestore
        } catch {
            notice = .unavailable
        }
    }

    private func isExpectedProduct(_ product: Product) -> Bool {
        guard let plan = Plan.allCases.first(where: { $0.productID == product.id }),
              product.type == .autoRenewable,
              let period = product.subscription?.subscriptionPeriod else { return false }
        return period.value == 1 && period.unit == (plan == .annual ? .year : .month)
    }
}

enum ProFeature: String, CaseIterable, Identifiable {
    case writing, history, pdf, assistant
    var id: String { rawValue }
    var title: String {
        switch self {
        case .writing: "A little more room to think"
        case .history: "Find the words you had before"
        case .pdf: "Ready to send, beautifully"
        case .assistant: "A second look at your words"
        }
    }
    var name: String {
        switch self {
        case .writing: "Focused writing"
        case .history: "Version history"
        case .pdf: "PDF export"
        case .assistant: "On-device assistance"
        }
    }
    var detail: String {
        switch self {
        case .writing: "Focus mode and typewriter scrolling keep you with the sentence."
        case .history: "Preview and restore up to 25 earlier versions of each note."
        case .pdf: "Turn your Markdown into a clean, paginated PDF."
        case .assistant: "Suggest titles, tags and summaries on supported Apple Intelligence devices."
        }
    }
    var symbol: String {
        switch self {
        case .writing: "text.cursor"
        case .history: "clock.arrow.circlepath"
        case .pdf: "doc.richtext"
        case .assistant: "sparkles"
        }
    }
}
