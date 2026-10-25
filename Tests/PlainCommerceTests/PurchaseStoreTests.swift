import XCTest
import StoreKit
import StoreKitTest
@testable import Plain

/// Exercises the real StoreKit 2 entitlement path; no debug unlock flag.
@MainActor
final class PurchaseStoreTests: XCTestCase {
    private var session: SKTestSession!

    override func setUpWithError() throws {
        let configuration = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "Plain", withExtension: "storekit"))
        session = try SKTestSession(contentsOf: configuration)
        session.disableDialogs = true
        session.clearTransactions()
        session.resetToDefaultState()
        session.disableDialogs = true
    }

    override func tearDownWithError() throws {
        session.clearTransactions()
        session = nil
    }

    func testFreshInstallIsFreeAndLoadsLocalizedProducts() async {
        let store = PurchaseStore()
        await store.prepare()
        XCTAssertTrue(store.hasCheckedAccess)
        XCTAssertFalse(store.hasPro)
        XCTAssertEqual(Set(store.products.map(\.id)), Set(PurchaseStore.Plan.allCases.map(\.productID)))
        XCTAssertTrue(store.products.allSatisfy { !$0.displayPrice.isEmpty })
        XCTAssertEqual(store.product(for: .annual)?.subscription?.subscriptionPeriod.unit, .year)
        XCTAssertEqual(store.product(for: .monthly)?.subscription?.subscriptionPeriod.unit, .month)
    }

    func testVerifiedAnnualPurchaseSurvivesARecreatedStore() async throws {
        let store = PurchaseStore()
        await store.prepare()
        let product = try XCTUnwrap(store.product(for: .annual))
        await store.purchase(product)
        XCTAssertTrue(store.hasPro)
        XCTAssertEqual(store.purchasedIDs, [PurchaseStore.Plan.annual.productID])

        let relaunched = PurchaseStore()
        await relaunched.refreshEntitlements()
        XCTAssertTrue(relaunched.hasPro)
    }

    func testRefundRevokesSubscriptionAccess() async throws {
        let transaction = try await session.buyProduct(identifier: PurchaseStore.Plan.annual.productID)
        let store = PurchaseStore()
        await store.refreshEntitlements()
        XCTAssertTrue(store.hasPro)

        try session.refundTransaction(identifier: UInt(transaction.id))
        await store.refreshEntitlements()
        XCTAssertFalse(store.hasPro)
    }

    func testExpiredSubscriptionLosesAccess() async throws {
        _ = try await session.buyProduct(identifier: PurchaseStore.Plan.annual.productID)
        let store = PurchaseStore()
        await store.refreshEntitlements()
        XCTAssertTrue(store.hasPro)

        try session.expireSubscription(productIdentifier: PurchaseStore.Plan.annual.productID)
        await store.refreshEntitlements()
        XCTAssertFalse(store.hasPro)
    }

    func testCancelingRenewalKeepsAccessUntilExpiration() async throws {
        let transaction = try await session.buyProduct(identifier: PurchaseStore.Plan.monthly.productID)
        try session.disableAutoRenewForTransaction(identifier: UInt(transaction.id))
        let store = PurchaseStore()
        await store.refreshEntitlements()
        XCTAssertTrue(store.hasPro)
    }

    func testFailedPurchaseDoesNotUnlockPro() async throws {
        let store = PurchaseStore()
        await store.prepare()
        let product = try XCTUnwrap(store.product(for: .annual))
        try await session.setSimulatedError(.generic(.notAvailableInStorefront), forAPI: .purchase)
        await store.purchase(product)
        XCTAssertFalse(store.hasPro)
        XCTAssertNotNil(store.notice)
    }

    func testRestoreFindsExistingPurchase() async throws {
        _ = try await session.buyProduct(identifier: PurchaseStore.Plan.annual.productID)
        let store = PurchaseStore()
        await store.restore()
        XCTAssertTrue(store.hasPro)
        XCTAssertFalse(store.isPurchasing)
    }

    func testPendingApprovalUnlocksOnlyAfterTransactionUpdate() async throws {
        session.askToBuyEnabled = true
        let store = PurchaseStore()
        await store.prepare()
        let product = try XCTUnwrap(store.product(for: .monthly))
        await store.purchase(product)
        XCTAssertFalse(store.hasPro)
        XCTAssertEqual(store.notice, .pending)

        let pending = try XCTUnwrap(session.allTransactions().first)
        try session.approveAskToBuyTransaction(identifier: pending.identifier)
        let deadline = Date.now.addingTimeInterval(5)
        while !store.hasPro && Date.now < deadline {
            try await Task.sleep(for: .milliseconds(100))
        }
        XCTAssertTrue(store.hasPro)
    }
}
