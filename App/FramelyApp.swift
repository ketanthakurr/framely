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
    @State private var showSplash = true
    /// Home's first photos are decoded; the splash waits for this (briefly) so Home opens drawn.
    @State private var homeReady = false

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
        .overlay {
            if showSplash {
                SplashView(ready: homeReady) { withAnimation(.easeOut(duration: 0.35)) { showSplash = false } }
                    .transition(.opacity)
            }
        }
        .task {
            if DebugLaunch.lockStudio, let first = model.sets.first { router.path = [.set(first.id)] }
            if let i = DebugLaunch.openSet, model.sets.indices.contains(i) { router.path = [.set(model.sets[i].id)] }
            if DebugLaunch.paywall { router.showPaywall = true }
        }
        .task {
            await ThumbnailCache.shared.preloadHome(sets: model.sets)
            homeReady = true
        }
        .onOpenURL { url in
            if let link = DeepLink(url: url) { router.open(link) }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task {
                await store.refreshEntitlements()
                await model.syncAllAlbums(gate: store.gate)
                model.warmWidgetImages()
            }
        }
    }
}

/// Cold-launch splash. Starts on the launch-screen color, so there's no flash, then:
/// the frame settles in, the sun rises over the hills, the name fades up. ~1.4s; tap to skip.
struct SplashView: View {
    /// Home's photos are decoded. The splash ends after its animation once this is true.
    var ready: Bool
    var onFinish: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var frameIn = false
    @State private var sun: CGFloat = 0
    @State private var nameIn = false
    @State private var finished = false
    @State private var played = false

    var body: some View {
        ZStack {
            Color("LaunchBackground")
            RadialGradient(colors: [Brand.coral.opacity(0.35), .clear], center: .center, startRadius: 0, endRadius: 360)
                .opacity(sun)

            VStack(spacing: 28) {
                ZStack {
                    // Ghost arch slides out from behind: the next photo.
                    ArchShape()
                        .fill(.white.opacity(0.14))
                        .overlay { ArchShape().stroke(.white.opacity(0.3), lineWidth: 1.5) }
                        .frame(width: 150 * 420 / 640, height: 150)
                        .rotationEffect(.degrees(frameIn ? 9 : 0))
                        .offset(x: frameIn ? 20 : 0, y: frameIn ? -6 : 0)

                    ArchMark(height: 150, sunProgress: sun)
                        .shadow(color: .black.opacity(0.45), radius: 20, y: 10)
                }
                .scaleEffect(frameIn ? 1 : 0.92)
                .opacity(frameIn ? 1 : 0)

                VStack(spacing: 6) {
                    Text("Framely")
                        .font(.system(size: 40, weight: .heavy, design: .rounded))
                        .tracking(-0.5)
                        .foregroundStyle(.white)
                    Text("Your photos, on every screen.")
                        .font(Brand.body.weight(.medium))
                        .foregroundStyle(.white.opacity(0.7))
                }
                .opacity(nameIn ? 1 : 0)
                .offset(y: nameIn ? 0 : 8)
            }
        }
        .ignoresSafeArea()
        .contentShape(Rectangle())
        .onTapGesture { finish() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Framely")
        .task { await run() }
        .onChange(of: ready) { _, isReady in
            if isReady && played { finish() }
        }
    }

    private func run() async {
        if reduceMotion {
            frameIn = true; sun = 1; nameIn = true
            try? await Task.sleep(for: .milliseconds(600))
        } else {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.9)) { frameIn = true }
            try? await Task.sleep(for: .milliseconds(200))
            withAnimation(.easeOut(duration: 0.7)) { sun = 1 }
            try? await Task.sleep(for: .milliseconds(350))
            withAnimation(.easeOut(duration: 0.35)) { nameIn = true }
            try? await Task.sleep(for: .milliseconds(850))
        }
        played = true
        if ready { return finish() }
        // Photos still decoding (huge library, cold disk): wait a little, never long.
        try? await Task.sleep(for: .milliseconds(1200))
        finish()
    }

    private func finish() {
        guard !finished else { return }
        finished = true
        onFinish()
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
