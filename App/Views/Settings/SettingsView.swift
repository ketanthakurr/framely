import SwiftUI
import StoreKit
import WidgetKit

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(StoreManager.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.requestReview) private var requestReview

    @State private var showRedeem = false
    @State private var showManage = false
    @State private var storage = ""
    @State private var cleaned = false

    private var version: String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let b = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(v) (\(b))"
    }

    var body: some View {
        List {
            Section {
                proHeader
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
            }

            Section("Subscription") {
                if store.isPro {
                    Button { showManage = true } label: { row("Manage Subscription", "creditcard.fill", Brand.lavender) }
                } else {
                    Button { router.showPaywall = true } label: { row("Upgrade to Pro", "crown.fill", Brand.gold) }
                }
                Button { showRedeem = true } label: { row("Redeem Code", "giftcard.fill", Brand.coral) }
                Button { Task { await store.restore() } } label: { row("Restore Purchases", "arrow.clockwise", Brand.mint) }
            }

            Section("Customize") {
                NavigationLink(value: Route.wallpaperGuide) { row("Rotating Wallpaper", "iphone.gen3", Brand.coral) }
                NavigationLink(value: Route.widgetGuide) { row("Add Widgets", "square.grid.2x2.fill", Brand.lavender) }
                Button {
                    WidgetCenter.shared.reloadAllTimelines()
                } label: { row("Refresh All Widgets", "arrow.triangle.2.circlepath", Brand.mint) }
                Button {
                    SharedStore.shared.onboardingDone = false
                } label: { row("Show Welcome Again (next launch)", "sparkles", Brand.gold) }
            }

            Section {
                HStack {
                    row("Photos stored", "internaldrive.fill", .gray)
                    Spacer()
                    Text(storage).foregroundStyle(.secondary).monospacedDigit()
                }
                Button {
                    model.cleanUpStorage()
                    ThumbnailCache.shared.removeAll()
                    storage = model.storageUsed
                    cleaned.toggle()
                } label: { row("Clean Up Unused Files", "sparkles.rectangle.stack", .gray) }
            } header: {
                Text("Storage")
            } footer: {
                Text("Framely keeps small copies of your chosen photos so widgets load instantly. Nothing is uploaded anywhere.")
            }

            Section("About") {
                Button { requestReview() } label: { row("Rate Framely", "star.fill", Brand.gold) }
                Link(destination: AppLinks.support) { row("Contact Support", "envelope.fill", Brand.lavender) }
                Link(destination: AppLinks.privacyPolicy) { row("Privacy Policy", "hand.raised.fill", Brand.mint) }
                Link(destination: AppLinks.termsOfUse) { row("Terms of Use", "doc.text.fill", .gray) }
                HStack {
                    Text("Version").font(Brand.body)
                    Spacer()
                    Text(version).foregroundStyle(.secondary)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(AnimatedBackground())
        .navigationTitle("Settings")
        .sheet(isPresented: $showRedeem) { RedeemCodeSheet() }
        .manageSubscriptionsSheet(isPresented: $showManage)
        .sensoryFeedback(.success, trigger: cleaned)
        .onAppear { storage = model.storageUsed }
    }

    private var proHeader: some View {
        HStack(spacing: 14) {
            Image(systemName: store.isPro ? "crown.fill" : "sparkles")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 58, height: 58)
                .background(store.isPro ? AnyShapeStyle(Brand.proGradient) : AnyShapeStyle(Brand.gradient),
                            in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(store.isPro ? "Framely Pro" : "Framely Free").font(Brand.title(22))
                Text(store.isPro ? "Everything unlocked. Thank you! 💜" : "\(model.sets.count) of \(ProConfig.freeMaxSets) set · up to \(ProConfig.freeMaxPhotosPerSet) photos")
                    .font(Brand.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(18)
        .glass(cornerRadius: 26)
    }

    private func row(_ title: String, _ symbol: String, _ color: Color) -> some View {
        Label {
            Text(title).font(Brand.body).foregroundStyle(.primary)
        } icon: {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(color.gradient, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }
}
