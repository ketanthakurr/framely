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
    /// Owns the one-time Lifetime purchase (bought, or from a lifetime offer code).
    private(set) var hasLifetime = false
    /// Has a running subscription (shown so it can be managed or cancelled, also next to Lifetime).
    private(set) var hasSubscription = false
    private(set) var loadState: LoadState = .idle
    private(set) var isPurchasing = false
    private(set) var isRestoring = false
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
    var lifetime: Product? { products.first { $0.id == ProConfig.lifetimeProductID } }

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
            // Unknown product IDs come back as an empty list, not an error. Surface it
            // (with Try again) rather than showing no plans and a dead Continue button.
            guard !fetched.isEmpty else {
                loadState = .failed("No subscriptions found for this app.")
                return
            }
            let rank = { (p: Product) in ProConfig.productIDs.firstIndex(of: p.id) ?? .max }
            products = fetched.sorted { rank($0) < rank($1) }
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
        return "\(offer.period.value) \(unit) free trial"   // e.g. "1 week free trial"
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
            case .pending:
                // Ask to Buy or bank approval: say so, or the spinner just stops and people tap again.
                lastError = "Your purchase is waiting for approval. Pro unlocks automatically once it’s approved."
                return false
            case .userCancelled:
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
        guard !isRestoring else { return }  // repeated taps would stack sign-in prompts
        isRestoring = true
        defer { isRestoring = false }
        do {
            try await AppStore.sync()
        } catch StoreKitError.userCancelled {
            return
        } catch {
            lastError = error.localizedDescription
            return
        }
        await refreshEntitlements()
        if !isPro { lastError = "No Framely Pro purchase or active subscription was found for this Apple ID." }
    }

    // MARK: Entitlements

    func refreshEntitlements() async {
        var lifetime = false
        var subscription: (id: String, expiry: Date?)?
        for await result in StoreKit.Transaction.currentEntitlements {
            guard case .verified(let t) = result,
                  ProConfig.productIDs.contains(t.productID),
                  t.revocationDate == nil else { continue }
            if t.productID == ProConfig.lifetimeProductID {
                lifetime = true
            } else {
                subscription = (t.productID, t.expirationDate)
            }
        }
        let pro = lifetime || subscription != nil
        let changed = pro != isPro
        isPro = pro
        hasLifetime = lifetime
        hasSubscription = subscription != nil
        // Lifetime wins: it never ends, so there's no renewal date to show.
        activeProductID = lifetime ? ProConfig.lifetimeProductID : subscription?.id
        renewalDate = lifetime ? nil : subscription?.expiry
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
