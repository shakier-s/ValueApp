# ValueApp Recovery and Continuation Guide

Last updated: 26 August 2026 (Africa/Johannesburg)

This document is the recovery reference for ValueApp. It intentionally contains no passwords, database connection strings, Apple credentials, signing certificates, API keys, or session tokens. Those remain in GitHub, Railway, Apple Developer, App Store Connect, and the macOS Keychain accounts owned by Shakier Suleman.

## Project summary

ValueApp is an iOS voucher marketplace for shoppers and local shop owners.

- Guests can browse active deals without an account.
- Shoppers can create an account, save vouchers, redeem them in store, and review their redeemed-voucher history.
- Shop owners can create, edit, activate, deactivate, and delete only deals owned by their account.
- Supported discounts are buy-one-get-one-free, percentage off, and fixed South African rand amounts.
- Location is optional and is used to calculate nearby deals.
- Shoppers can optionally receive notifications about nearby offers.
- Voucher redemption requires the shop attendant's numeric code.

## Source repository

- GitHub: <https://github.com/shakier-s/ValueApp>
- Default branch: `main`
- Local project folder: `ValueAppiOS`
- Xcode project: `ValueAppiOS/ValueApp.xcodeproj`
- Xcode scheme: `ValueApp`
- Latest feature commit at the time of writing: `832ab7c` (`Add shopper redeemed voucher history`)

To recover onto another Mac:

```bash
git clone https://github.com/shakier-s/ValueApp.git
cd ValueApp/ValueAppiOS
open ValueApp.xcodeproj
```

Sign into Xcode with the Apple Developer account, select team `973PF7V52A`, allow automatic signing, and wait for Xcode to download provisioning assets.

## Apple configuration

- App name: ValueApp
- Bundle identifier: `com.datawiz.valueapp`
- Apple Developer Team ID: `973PF7V52A`
- App Store Connect app ID: `1632022332`
- App Store version being prepared: `1.1.0`
- Current source build number: `130`
- Most recently uploaded App Store build: `129`
- App Store Connect: <https://appstoreconnect.apple.com/apps/1632022332/distribution/ios/version/inflight>
- Xcode Cloud page: <https://appstoreconnect.apple.com/teams/a461db66-9e05-43d4-b232-274023b7e674/apps/1632022332/ci>

Xcode Cloud is not configured yet. App Store build 129 was archived, signed, validated, and uploaded directly with Xcode. Build 130 has been installed on the physical iPhone for testing but has not yet been uploaded to App Store Connect.

The version and build settings are stored in `ValueApp.xcodeproj/project.pbxproj`. `Config/Info.plist` uses `$(MARKETING_VERSION)` and `$(CURRENT_PROJECT_VERSION)`; do not replace these with hard-coded values.

## App Store listing

- Existing public version: `1.0.4` (previously removed from sale during this work)
- Update version: `1.1.0`
- Keywords: `Coupons, Value App, ValueApp, deals, meals`
- Support URL: <http://www.valuapp.co.za>
- Marketing URL: <http://www.valuapp.co.za>
- Copyright: `2022 DataWiz Consulting`
- Submission copy and review guidance: `APP_STORE_SUBMISSION.md`

Six 1242 × 2688 iPhone screenshots are stored in `AppStoreScreenshots/`:

1. `01-Save-More.png`
2. `02-Redeem-In-Seconds.png`
3. `03-Discover-Deals.png`
4. `04-Intro-Discover.png`
5. `05-Intro-Save.png`
6. `06-Intro-Redeem.png`

All six were added to the 6.5-inch iPhone screenshot section for version 1.1.0. The first three are used on installation sheets.

## Railway services

- Railway project ID: `4adefc34-4e30-4b99-b841-ed90e410a9aa`
- PostgreSQL service ID: `804823f4-acea-4d31-8aac-6fd49075b6f5`
- Production environment ID: `ea50d32c-926a-4a05-9704-1211b3cdd651`
- API service ID: `2113f139-8002-45f3-a5ef-8d15d60d8a7f`
- Live API: <https://valueapp-api-production.up.railway.app>
- Health check: <https://valueapp-api-production.up.railway.app/health>
- Railway project: <https://railway.com/project/4adefc34-4e30-4b99-b841-ed90e410a9aa>

Railway is connected to the GitHub repository. The backend is in `ValueAppiOS/backend`, uses Node.js/Express and PostgreSQL, and starts with `node src/server.js`. Railway must supply `DATABASE_URL`; never commit its value.

The server runs `backend/src/schema.sql` automatically when it starts. Main tables:

- `users`: email, password salt/hash, and shopper/merchant role
- `auth_sessions`: hashed bearer sessions with expiry dates
- `merchants`: shop records tied to owner account IDs
- `deals`: offers and inventory
- `vouchers`: shopper-specific voucher codes and redemption status

The `users` table was empty at the time this file was created. Older values such as `test-shopper-amina`, `test-shopper-lee`, and `test-shopper-thabo` are legacy test identifiers in voucher rows, not email/password accounts. Passwords are hashed with `scrypt` and cannot be recovered or viewed.

## Authentication and account isolation

Relevant files:

- `ValueApp/AuthSession.swift`
- `ValueApp/APIClient.swift`
- `backend/src/server.js`
- `backend/src/schema.sql`

The app supports account creation and login using email, password, and one fixed role (`shopper` or `merchant`). The API returns a bearer token. The iOS app stores that token in the Keychain, never in source control. Shop-owner API mutations verify ownership in SQL. Shopper voucher queries use the authenticated shopper ID. Signing out removes private voucher and owned-deal state from the on-device store.

Legacy `X-User-ID` support still exists in the API for old test data. Remove that fallback before a strict production security launch, after migrating any data that must be retained. Consider Sign in with Apple as a future authentication option.

## iOS source layout

- `ValueApp/ValueAppApp.swift`: app entry point and shared environment objects
- `ValueApp/LaunchFlowView.swift`: splash, three-page onboarding, and screenshot-only launch modes
- `ValueApp/RootView.swift`: guest/shopper/shop-owner routing, login, registration, and tabs
- `ValueApp/ShopperViews.swift`: discovery, deal detail, saved vouchers, redemption, and redeemed history
- `ValueApp/MerchantViews.swift`: owner dashboard, creation, editing, deletion, and redemption metrics
- `ValueApp/DealStore.swift`: app state, persistence, API synchronization, and ownership checks
- `ValueApp/APIClient.swift`: production API requests and authentication header
- `ValueApp/AuthSession.swift`: authenticated user state and Keychain token management
- `ValueApp/ProximityService.swift`: location and nearby-deal notifications
- `ValueApp/Models.swift`: `Deal`, `Voucher`, and discount models
- `Config/Info.plist`: iOS metadata and location permission text

## Build and verification commands

List available devices:

```bash
xcrun devicectl list devices
xcrun simctl list devices available
```

Build for a simulator:

```bash
xcodebuild -project ValueApp.xcodeproj -scheme ValueApp -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' build
```

Build for a connected iPhone (replace `DEVICE_ID`):

```bash
xcodebuild -project ValueApp.xcodeproj -scheme ValueApp -configuration Debug \
  -destination 'platform=iOS,id=DEVICE_ID' \
  -derivedDataPath /private/tmp/ValueAppDevice \
  -allowProvisioningUpdates build
```

Install and launch on a connected iPhone:

```bash
xcrun devicectl device install app --device DEVICE_ID \
  /private/tmp/ValueAppDevice/Build/Products/Debug-iphoneos/ValueApp.app

xcrun devicectl device process launch --device DEVICE_ID \
  --terminate-existing com.datawiz.valueapp
```

Check backend JavaScript syntax:

```bash
node --check backend/src/server.js
```

## Creating an App Store build

1. Increase `CURRENT_PROJECT_VERSION` in both Debug and Release settings.
2. Commit and push the change to `main`.
3. Archive using the generic iOS destination.
4. Export with destination `upload` and method `app-store-connect`.
5. Wait for processing in App Store Connect/TestFlight.
6. Complete export-compliance questions if Apple requests them.
7. Select the new build on version 1.1.0 and save. Do not submit for review unless specifically intended.

Archive example:

```bash
xcodebuild -project ValueApp.xcodeproj -scheme ValueApp -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath /private/tmp/ValueApp.xcarchive \
  -allowProvisioningUpdates archive
```

The export options plist should use:

```xml
<key>destination</key><string>upload</string>
<key>method</key><string>app-store-connect</string>
<key>signingStyle</key><string>automatic</string>
<key>teamID</key><string>973PF7V52A</string>
<key>manageAppVersionAndBuildNumber</key><false/>
```

Then upload:

```bash
xcodebuild -exportArchive \
  -archivePath /private/tmp/ValueApp.xcarchive \
  -exportPath /private/tmp/ValueApp-export \
  -exportOptionsPlist /private/tmp/ValueApp-ExportOptions.plist \
  -allowProvisioningUpdates
```

## Functional test checklist

### Guest

- Complete or skip onboarding.
- Browse and search active deals.
- Confirm saving a voucher asks the guest to sign in or create a shopper account.

### Shopper

- Create a shopper account with a unique email and an 8+ character password.
- Save a voucher and confirm it appears under My Vouchers.
- Redeem it using the correct shop attendant code.
- Confirm it appears under Redeemed with merchant, code, date, and time.
- Sign out and confirm private voucher history disappears from the device UI.

### Shop owner

- Create a shop-owner account.
- Create BOGO, percentage, and fixed-value deals.
- Edit, deactivate, reactivate, and delete an owned deal.
- Confirm the owner cannot modify deals belonging to another account.
- Confirm redemption totals update after shopper redemption.

### Location and notifications

- Permit location while using the app.
- Confirm distances use the device's actual Cape Town location when location simulation is disabled.
- Enable nearby-deal notifications and adjust the distance slider.

## Important recovery notes

- Keep GitHub, Railway, Apple Developer, and App Store Connect account recovery methods current.
- Back up signing certificates/private keys through Apple/Xcode-approved methods; Git does not contain them.
- Do not commit `.env` files, `DATABASE_URL`, Apple passwords, app-specific passwords, tokens, or exported signing keys.
- The database is the authoritative source for production accounts, deals, and vouchers. Configure Railway backups before public launch.
- Xcode Cloud still needs to be created in Xcode if automatic Apple builds are desired.
- App Store review information must be updated with working shopper and shop-owner test credentials after test accounts are created.
- Review `APP_STORE_SUBMISSION.md`; some older wording describes the pre-login prototype and must be refreshed before submission.

