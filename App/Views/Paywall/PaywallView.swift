import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(StoreManager.self) private var store
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var selectedID = ProConfig.yearlyProductID
    @State private var trialText: [String: String] = [:]
    @State private var showRedeem = false
    @State private var heroImages: [UIImage] = []
    @State private var appeared = false

    private let features: [(String, String, String)] = [
        ("rectangle.stack.fill", "Unlimited sets & photos", "A widget for every mood"),
        ("paintpalette.fill", "Every frame, filter & theme", "Film, Glass, Arch, Noir and more"),
        ("square.grid.2x2.fill", "Mosaic & Photo + Info widgets", "Collages, countdowns, On this day"),
        ("iphone.gen3", "Rotating wallpaper", "Shortcuts action to change your wallpaper"),
        ("timer", "Faster rotation", "New photo every 5, 15 or 30 minutes"),
    ]

    private var selectedProduct: Product? { store.products.first { $0.id == selectedID } }

    var body: some View {
        ZStack {
            AnimatedBackground()

            ScrollView {
                VStack(spacing: 24) {
                    FloatingPolaroids(images: heroImages)
                        .frame(height: 230)
                        .padding(.top, 30)

                    VStack(spacing: 6) {
                        HStack(spacing: 8) {
                            Wordmark(size: 30)
                            Text("PRO")
                                .font(.system(size: 16, weight: .heavy, design: .rounded))
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .background(Brand.proGradient, in: Capsule())
                                .foregroundStyle(.black.opacity(0.75))
                        }
                        Text("Turn your iPhone into a living photo frame.")
                            .font(Brand.body).foregroundStyle(.secondary)
                    }

                    if store.isPro {
                        activeCard
                    } else {
                        featureList
                        plans
                        purchaseButton
                    }

                    footer
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)

            closeButton
        }
        .sheet(isPresented: $showRedeem) { RedeemCodeSheet() }
        .alert("Heads up", isPresented: Binding(get: { store.lastError != nil }, set: { if !$0 { store.lastError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(store.lastError ?? "") }
        .task {
            if store.products.isEmpty { await store.loadProducts() }
            for product in store.products {
                if let text = await store.introOfferText(for: product) { trialText[product.id] = text }
            }
            heroImages = await loadHeroImages()
        }
        .onAppear { withAnimation(Brand.bouncy.delay(0.1)) { appeared = true } }
        .sensoryFeedback(.success, trigger: store.isPro)
    }

    // MARK: Pieces

    private var closeButton: some View {
        VStack {
            HStack {
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.system(size: 15, weight: .bold)).foregroundStyle(.secondary)
                        .frame(width: 36, height: 36)
                }
                .glassCircle()
                .accessibilityLabel("Close")
            }
            Spacer()
        }
        .padding(16)
    }

    private var featureList: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(Array(features.enumerated()), id: \.offset) { _, f in
                HStack(spacing: 14) {
                    Image(systemName: f.0)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 38, height: 38)
                        .background(Brand.gradient, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(f.1).font(Brand.headline)
                        Text(f.2).font(Brand.caption).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(18)
        .glass(cornerRadius: 26)
    }

    @ViewBuilder
    private var plans: some View {
        switch store.loadState {
        case .loading, .idle:
            ProgressView().padding()
        case .failed:
            VStack(spacing: 10) {
                Text("Couldn’t reach the App Store.").font(Brand.body)
                Button("Try again") { Task { await store.loadProducts() } }
            }
            .padding()
        case .loaded:
            VStack(spacing: 12) {
                ForEach(store.products, id: \.id) { product in
                    Button { withAnimation(Brand.spring) { selectedID = product.id } } label: {
                        PlanCard(
                            product: product,
                            selected: selectedID == product.id,
                            badge: product.id == ProConfig.yearlyProductID ? store.yearlySavingsPercent.map { "Save \($0)%" } ?? "Best value" : nil,
                            trial: trialText[product.id]
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selectedID == product.id ? .isSelected : [])
                }
            }
            .sensoryFeedback(.selection, trigger: selectedID)
        }
    }

    private var purchaseButton: some View {
        Button {
            guard let product = selectedProduct else { return }
            Task {
                if await store.purchase(product) { dismiss() }
            }
        } label: {
            ZStack {
                if store.isPurchasing {
                    ProgressView().tint(.white)
                } else {
                    Text(trialText[selectedID] != nil ? "Start Free Trial" : "Continue")
                }
            }
        }
        .buttonStyle(PrimaryButtonStyle())
        .disabled(selectedProduct == nil || store.isPurchasing)
    }

    private var activeCard: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 44))
                .foregroundStyle(Brand.proGradient)
                .symbolEffect(.bounce, value: appeared)
            Text("You’re Pro ✨").font(Brand.title(24))
            if let date = store.renewalDate {
                Text("Renews or ends \(date.formatted(date: .abbreviated, time: .omitted))")
                    .font(Brand.caption).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .glass(cornerRadius: 26)
    }

    private var footer: some View {
        VStack(spacing: 12) {
            HStack(spacing: 18) {
                Button("Restore") { Task { await store.restore() } }
                Button("Redeem Code") { showRedeem = true }
            }
            .font(.system(.subheadline, design: .rounded).weight(.semibold))

            // Required disclosure for auto-renewable subscriptions (App Review 3.1.2).
            Text("Subscriptions renew automatically at the price shown unless cancelled at least 24 hours before the end of the current period. Payment is charged to your Apple ID. Manage or cancel anytime in Settings › Apple ID › Subscriptions. Any unused part of a free trial is forfeited when you subscribe.")
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 16) {
                Link("Terms of Use", destination: AppLinks.termsOfUse)
                Link("Privacy Policy", destination: AppLinks.privacyPolicy)
            }
            .font(.system(size: 12, weight: .medium, design: .rounded))
        }
        .padding(.top, 4)
    }

    private func loadHeroImages() async -> [UIImage] {
        let items = model.sets.flatMap(\.photos).prefix(3)
        var result: [UIImage] = []
        for item in items {
            if let img = await ThumbnailCache.shared.image(for: item, maxPixel: 400) { result.append(img) }
        }
        return result
    }
}

private struct PlanCard: View {
    let product: Product
    let selected: Bool
    let badge: String?
    let trial: String?

    private var period: String {
        product.id == ProConfig.yearlyProductID ? "Yearly" : "Monthly"
    }

    private var perMonth: String? {
        guard product.id == ProConfig.yearlyProductID else { return nil }
        let monthly = product.price / 12
        return monthly.formatted(product.priceFormatStyle) + " / month"
    }

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                .font(.title2)
                .foregroundStyle(selected ? AnyShapeStyle(Brand.gradient) : AnyShapeStyle(.secondary))
                .contentTransition(.symbolEffect(.replace))
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(period).font(Brand.headline)
                    if let badge {
                        Text(badge)
                            .font(.system(size: 10, weight: .heavy, design: .rounded))
                            .padding(.horizontal, 7).padding(.vertical, 3)
                            .background(Brand.proGradient, in: Capsule())
                            .foregroundStyle(.black.opacity(0.75))
                    }
                }
                if let trial {
                    Text(trial).font(Brand.caption).foregroundStyle(Brand.lavender)
                } else if let perMonth {
                    Text(perMonth).font(Brand.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                Text(product.displayPrice).font(Brand.headline)
                Text(product.id == ProConfig.yearlyProductID ? "per year" : "per month")
                    .font(Brand.caption).foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(selected ? AnyShapeStyle(Brand.gradient) : AnyShapeStyle(.white.opacity(0.15)), lineWidth: selected ? 2.5 : 1)
        }
        .glass(cornerRadius: 22, interactive: true)
        .scaleEffect(selected ? 1.02 : 1)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
