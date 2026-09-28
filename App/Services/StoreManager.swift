import StoreKit
import SwiftUI
import WidgetKit

/// StoreKit 2 subscriptions + Apple offer codes.
///
/// Free Pro for friends: App Store Connect › your app › Subscriptions › (plan) › Offer Codes.
/// Create a *custom code* (e.g. FRAMELYFRIEND) or a batch of one-time codes, pick "Free" for N months,
/// and share them. Users redeem via Settings › "Redeem Code" (calls `offerCodeRedemption`).
@Observable
@MainActor
final class StoreManager {
    enum LoadState: Equatable { case idle, loading, loaded, failed(String) }

    private(set) var products: [Product] = []
    private(set) var isPro: Bool
    private(set) var activeProductID: String?
    private(set) var renewalDate: Date?
    private(set) var loadState: LoadState = .idle
    private(set) var isPurchasing = false
    var lastError: String?

    private var updatesTask: Task<Void, Never>?

    init() {
        isPro = SharedStore.shared.isProCached
        updatesTask = listenForTransactions()
        Task {
            await loadProducts()
            await refreshEntitlements()
        }
    }

    // MARK: Products

    var yearly: Product? { products.first { $0.id == ProConfig.yearlyProductID } }
    var monthly: Product? { products.first { $0.id == ProConfig.monthlyProductID } }

    /// e.g. 58 when yearly costs 42% of 12 × monthly.
    var yearlySavingsPercent: Int? {
        guard let y = yearly, let m = monthly, m.price > 0 else { return nil }
        let yearlyValue = NSDecimalNumber(decimal: y.price).doubleValue
        let monthlyValue = NSDecimalNumber(decimal: m.price).doubleValue * 12
        let pct = Int(((1 - yearlyValue / monthlyValue) * 100).rounded())
        return pct > 0 ? pct : nil
    }

    func loadProducts() async {
        guard loadState != .loading else { return }
        loadState = .loading
        do {
            let fetched = try await Product.products(for: ProConfig.productIDs)
            products = fetched.sorted { $0.price > $1.price }
            loadState = .loaded
        } catch {
            loadState = .failed(error.localizedDescription)
        }
    }

    /// Localized "7-day free trial" if the user can still get the intro offer.
    func introOfferText(for product: Product) async -> String? {
        guard let sub = product.subscription, let offer = sub.introductoryOffer,
              await sub.isEligibleForIntroOffer else { return nil }
        guard offer.paymentMode == .freeTrial else { return nil }
        let unit: String
        switch offer.period.unit {
        case .day: unit = "day"
        case .week: unit = "week"
        case .month: unit = "month"
        case .year: unit = "year"
        @unknown default: unit = "day"
        }
        return "\(offer.period.value)-\(unit) free trial"   // e.g. "1-week free trial"
    }

    // MARK: Purchase

    @discardableResult
    func purchase(_ product: Product) async -> Bool {
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            switch try await product.purchase() {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                await refreshEntitlements()
                return true
            case .userCancelled, .pending:
                return false
            @unknown default:
                return false
            }
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    func restore() async {
        do {
            try await AppStore.sync()
        } catch {
            lastError = error.localizedDescription
        }
        await refreshEntitlements()
        if !isPro { lastError = "No active Framely Pro subscription was found for this Apple ID." }
    }

    // MARK: Entitlements

    func refreshEntitlements() async {
        var pro = false
        var productID: String?
        var expiry: Date?
        for await result in StoreKit.Transaction.currentEntitlements {
            guard case .verified(let t) = result,
                  ProConfig.productIDs.contains(t.productID),
                  t.revocationDate == nil else { continue }
            pro = true
            productID = t.productID
            expiry = t.expirationDate
        }
        let changed = pro != isPro
        isPro = pro
        activeProductID = productID
        renewalDate = expiry
        SharedStore.shared.isProCached = pro
        if changed { WidgetCenter.shared.reloadAllTimelines() }
    }

    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await result in StoreKit.Transaction.updates {
                if case .verified(let t) = result { await t.finish() }
                await self?.refreshEntitlements()
            }
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let value): return value
        case .unverified: throw StoreError.failedVerification
        }
    }

    var gate: FeatureGate { FeatureGate(isPro: isPro || ProConfig.everythingFree) }
}

enum StoreError: LocalizedError {
    case failedVerification
    var errorDescription: String? { "The purchase couldn’t be verified with the App Store." }
}
