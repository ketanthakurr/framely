import SwiftUI

@main
struct FramelyApp: App {
    @State private var model = AppModel()
    @State private var store = StoreManager()
    @State private var router = Router()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .environment(store)
                .environment(router)
        }
    }
}

enum Route: Hashable {
    case set(UUID)
    case settings
    case wallpaperGuide
    case widgetGuide
}

@Observable
@MainActor
final class Router {
    var path: [Route] = []
    var showPaywall = false
    var showNewSet = false

    func open(_ link: DeepLink) {
        switch link {
        case .set(let id): path = [.set(id)]
        case .newSet: path = []; showNewSet = true
        case .pro: showPaywall = true
        }
    }
}

struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(StoreManager.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.scenePhase) private var scenePhase

    @State private var onboardingDone = SharedStore.shared.onboardingDone

    var body: some View {
        @Bindable var router = router
        ZStack {
            if onboardingDone {
                NavigationStack(path: $router.path) {
                    HomeView() // declares the navigation destinations (needs its zoom namespace)
                }
                .transition(.opacity.combined(with: .scale(scale: 1.04)))
            } else {
                OnboardingView {
                    SharedStore.shared.onboardingDone = true
                    withAnimation(.easeInOut(duration: 0.6)) { onboardingDone = true }
                }
                .transition(.opacity)
            }
        }
        .tint(Brand.lavender)
        .sheet(isPresented: $router.showPaywall) { PaywallView() }
        .sheet(isPresented: $router.showNewSet) { NewSetSheet() }
        .alert("Something went wrong", isPresented: Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.errorMessage ?? "")
        }
        .overlay(alignment: .bottom) { ProgressToast() }
        .onOpenURL { url in
            if let link = DeepLink(url: url) { router.open(link) }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task {
                await store.refreshEntitlements()
                await model.syncAllAlbums(gate: store.gate)
            }
        }
    }
}

/// Floating glass pill shown while importing or syncing.
struct ProgressToast: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Group {
            if let progress = model.progress {
                HStack(spacing: 12) {
                    ProgressView(value: progress)
                        .progressViewStyle(.circular)
                        .tint(Brand.lavender)
                    Text("\(model.progressLabel) · \(Int(progress * 100))%")
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .contentTransition(.numericText())
                        .monospacedDigit()
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .glassCapsule()
                .padding(.bottom, 24)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(Brand.spring, value: model.progress == nil)
    }
}
