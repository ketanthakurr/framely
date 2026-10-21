import Foundation

/// Launch arguments for checking screens in the Simulator without tapping through the app.
/// Compiled out of Release builds, so TestFlight and App Store builds ignore them.
enum DebugLaunch {
    /// `-debugLockStudio`: opens the first set straight onto Style › Lock Screen.
    static let lockStudio: Bool = {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-debugLockStudio")
        #else
        false
        #endif
    }()

    /// `-debugOpenSet N`: opens the Nth set (0-based) on launch.
    static let openSet: Int? = {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-debugOpenSet"), args.indices.contains(i + 1) else { return nil }
        return Int(args[i + 1])
        #else
        nil
        #endif
    }()

    /// `-debugPaywall`: opens the paywall on launch (App Review screenshots).
    static let paywall: Bool = {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-debugPaywall")
        #else
        false
        #endif
    }()
}
