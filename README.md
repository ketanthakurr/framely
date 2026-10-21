# Framely

An iPhone app that puts your favorite photos on the Home Screen, Lock Screen and StandBy as widgets that rotate on a schedule. It also rotates your real wallpaper through a Shortcuts action.

- **Stack:** SwiftUI, WidgetKit, AppIntents, StoreKit 2
- **Minimum iOS:** 17 (uses Liquid Glass automatically on iOS 26+)
- **Devices:** iPhone only
- **Bundle ID:** `com.widget.framely`
- **Widget bundle ID:** `com.widget.framely.widgets`
- **App Group:** `group.com.widget.framely`

---

## 1. Open it in Xcode

```bash
brew install xcodegen          # once
cd iphone-widget/Framely
xcodegen generate              # creates Framely.xcodeproj from project.yml
open Framely.xcodeproj
```

Then in Xcode:

1. Select the **Framely** target, open **Signing & Capabilities**, and choose your **Team**. Do the same for **FramelyWidgets**.
2. On both targets, check that the App Group `group.com.widget.framely` is ticked. If Xcode says the group is taken, change it in `project.yml`, in `Shared/AppGroup.swift` → `AppGroup.groupID`, and in both entitlements, then run `xcodegen generate` again.
3. Run on a real iPhone. The simulator works too, but widgets refresh more reliably on a device.
4. To test purchases locally, the scheme already uses `App/Resources/Framely.storekit`. Pick **Debug › StoreKit › Manage Transactions** in Xcode to reset.

> Add or rename files by editing folders, then run `xcodegen generate` again. Don't edit the `.xcodeproj` by hand; it's generated.

## 2. Project layout

```
Framely/
├─ project.yml                 XcodeGen spec (targets, capabilities, Info.plist keys)
├─ Shared/                     Compiled into BOTH app and widget
│  ├─ AppGroup.swift           Group ID, deep links, legal URLs  ← edit links before release
│  ├─ Models/                  PhotoSet, WidgetStyle, Theme, ProConfig (free vs Pro)
│  ├─ Storage/                 SharedStore (JSON), ImageStore (downsampled JPEGs), PhotoScheduler
│  ├─ Intents/                 Widget configuration intents + "Next photo" button intent
│  └─ Design/                  FramedPhotoView: the frame styles used by widgets and in-app previews
├─ App/
│  ├─ FramelyApp.swift         Entry point, router, deep links
│  ├─ Services/                AppModel, AlbumSyncService, StoreManager, WallpaperIntent (Shortcuts)
│  ├─ Views/                   Home, SetDetail, Style studio, Paywall, Settings, Onboarding, Guides
│  └─ Resources/               Assets (icon), Framely.storekit, PrivacyInfo.xcprivacy
└─ Widget/                     Widget bundle: Photo, Mosaic, Photo + Info, Lock Screen
```

## 3. How it works

- **Photos:** photos you pick (PhotosPicker, no permission prompt) or from a linked album (needs Photos access) are resized to 1400 px and copied into the App Group container. Widgets can't read the Photos library, so they read these copies.
- **Rotation:** `PhotoScheduler` is deterministic. Each widget timeline contains up to 48 future entries, one per rotation slot, so rotation keeps going even when the app isn't open. Shuffle shows every photo once before any repeats.
- **"Next" button:** an interactive widget button (`NextPhotoIntent`) bumps a per-set offset stored in shared UserDefaults.
- **Color-matched looks:** each photo's average color is saved when it's imported. The `Auto` theme and the glow use that color.
- **Wallpaper:** apps can't change the wallpaper directly. `GetFramelyPhotoIntent` appears in Shortcuts as **Get Framely Photo**. The user builds this automation: Time of Day → Get Framely Photo → Set Wallpaper Photo.

## 4. Free vs Pro

All limits live in **`Shared/Models/ProConfig.swift`**: number of sets, photos per set, which frames, filters, themes and intervals are free, and whether mosaic, info, album sync and wallpaper are Pro. Set `everythingFree = true` when taking App Store screenshots.

## 5. App Store Connect setup

1. **Create the app** with bundle ID `com.widget.framely`, iPhone only.
2. **Subscriptions:** create a group called **Framely Pro** with two auto-renewable subscriptions:
   - `PRO_0001` (monthly) and `PRO_0002` (yearly), plus the non-consumable `LIFETIME_0001` (lifetime)

   Set your prices (e.g. ₹99/mo, ₹499/yr). Add a free trial as an Introductory Offer if you want one; the paywall shows it automatically.
3. **Giving Pro away for free (Offer Codes):**
   1. Open **Subscriptions → (plan) → Offer Codes → Create**.
   2. Choose **Free** for a duration (e.g. 1 year) and eligibility (new, existing, expired).
   3. Generate one-time codes, or create a **custom code** like `FRAMELYFRIEND` with a redemption limit.
   4. Friends redeem the code in **Framely → Settings → Redeem Code**, or on the paywall.
   5. You can also share `https://apps.apple.com/redeem?ctx=offercodes&id=<APP_ID>&code=<CODE>`.
4. **App Privacy:** choose "Data Not Collected". Framely has no analytics and no server.
5. **Before you submit:**
   - [ ] Replace `AppLinks.privacyPolicy` and `AppLinks.support` in `Shared/AppGroup.swift` with real pages. App Review checks these.
   - [ ] After creating the app, set `AppLinks.appStoreID` (App Store Connect › App Information › Apple ID) so the in-app code field opens Apple’s redemption page pre-filled.
   - [ ] Replace the placeholder app icon in `App/Resources/Assets.xcassets/AppIcon.appiconset` if you want your own design.
   - [ ] Screenshots: 6.9" and 6.5" iPhone. Show the Home Screen with widgets, the Style studio and the Lock Screen.
   - [ ] In the review notes, explain that widgets need photos added first, and give reviewers an offer code so they can test Pro.
   - [ ] Increment `CURRENT_PROJECT_VERSION` in `project.yml` for each upload.
6. **Archive:** **Product › Archive**, then **Distribute App › App Store Connect**.

## 6. Known platform limits (by design)

- iOS decides when widgets actually refresh. Very short intervals can arrive late in Low Power Mode.
- iOS draws Lock Screen widgets in a tinted/monochrome style.
- StandBy shows small widgets side by side (no full-screen third-party widgets), and tints them red at night.
- On iOS 18+ tinted Home Screens, photos are tinted to match the theme (`accentedDesaturated`).
- Albums sync when the app opens (at most every 10 minutes), not in the background.
