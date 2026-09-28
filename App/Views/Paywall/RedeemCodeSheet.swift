import SwiftUI
import StoreKit
import UIKit

/// In-app field for Apple offer codes.
///
/// Apple validates every code — Framely never unlocks anything itself (App Review 3.1.1).
/// • With `AppLinks.appStoreID` set: opens Apple's redemption page with the code pre-filled.
/// • Otherwise: copies the code and opens Apple's redeem sheet, where it can be pasted.
///
/// Note: Apple's redeem sheet only works on a real iPhone signed into the App Store
/// (TestFlight or the live app). In the Simulator or with Xcode's local .storekit file
/// it may appear empty or not at all — that's an Apple limitation, not a bug here.
struct RedeemCodeSheet: View {
    @Environment(StoreManager.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var code = ""
    @State private var showAppleSheet = false
    @State private var copied = false
    @FocusState private var focused: Bool

    private var cleanCode: String {
        code.uppercased().filter { $0.isLetter || $0.isNumber }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 22) {
                Image(systemName: "giftcard.fill")
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 88, height: 88)
                    .background(Brand.proGradient, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
                    .shadow(color: Brand.coral.opacity(0.5), radius: 16, y: 8)
                    .symbolEffect(.bounce, value: copied)
                    .padding(.top, 12)

                VStack(spacing: 6) {
                    Text("Redeem a code").font(Brand.title(26))
                    Text("Got a Framely Pro code from a friend? Enter it below.")
                        .font(Brand.body).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                TextField("ENTER CODE", text: $code)
                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                    .multilineTextAlignment(.center)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .keyboardType(.asciiCapable)
                    .submitLabel(.go)
                    .onSubmit(redeem)
                    .focused($focused)
                    .padding(.vertical, 18)
                    .glass(cornerRadius: 20)
                    .overlay(alignment: .trailing) {
                        if code.isEmpty {
                            Button {
                                if let pasted = UIPasteboard.general.string { code = pasted }
                            } label: {
                                Image(systemName: "doc.on.clipboard").font(.headline)
                            }
                            .padding(.trailing, 16)
                        }
                    }

                Button(action: redeem) {
                    Text("Redeem")
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(cleanCode.count < 4)
                .opacity(cleanCode.count < 4 ? 0.5 : 1)

                if copied {
                    Label("Code copied — paste it into Apple’s field", systemImage: "checkmark.circle.fill")
                        .font(Brand.caption)
                        .foregroundStyle(Brand.mint)
                        .transition(.scale.combined(with: .opacity))
                }

                Button("Use Apple’s redeem screen instead") { showAppleSheet = true }
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))

                Spacer()

                Text("Codes are checked by Apple and linked to your Apple ID. Pro unlocks automatically when you come back to Framely.")
                    .font(Brand.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(24)
            .background(AnimatedBackground(tint: Brand.gold))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
            }
            .animation(Brand.spring, value: copied)
        }
        .presentationDetents([.large])
        .presentationCornerRadius(32)
        .offerCodeRedemption(isPresented: $showAppleSheet) { _ in
            Task {
                await store.refreshEntitlements()
                if store.isPro { dismiss() }
            }
        }
        .onAppear { focused = true }
        .onChange(of: store.isPro) { _, isPro in if isPro { dismiss() } }
    }

    private func redeem() {
        let c = cleanCode
        guard c.count >= 4 else { return }
        if let appID = AppLinks.appStoreID,
           let url = URL(string: "https://apps.apple.com/redeem?ctx=offercodes&id=\(appID)&code=\(c)") {
            openURL(url)
        } else {
            UIPasteboard.general.string = c
            copied = true
            focused = false
            Task { try? await Task.sleep(for: .milliseconds(600)); showAppleSheet = true }
        }
    }
}
