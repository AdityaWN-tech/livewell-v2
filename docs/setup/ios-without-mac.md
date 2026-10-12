# iOS work from a Windows PC

Flutter code, Android builds and all tests run on Windows. iOS **compiles and signs only on macOS**. Use Codemagic (cloud Macs, spec 10.3) for builds and TestFlight. Some steps need hands-on Xcode, so plan for Mac access (own, borrowed, or a rented cloud Mac) by the time widget work starts.

| Step | Where | When |
|---|---|---|
| Apple Developer Program enrolment (organisation account, D-U-N-S number) | Web (developer.apple.com) | Now; it can take 1–2 weeks |
| App ids, capabilities (Push, Sign in with Apple, App Groups), APNs auth key (.p8), upload key to Firebase | Web (Apple portal + Firebase console) | Before push / Apple sign-in |
| App Store Connect API key for Codemagic automatic signing | Web | Before the first iOS build |
| Per-flavor Xcode build configs + schemes (Debug-dev, Release-prod, …) and per-flavor `GoogleService-Info.plist` | **Mac** (Xcode) or a scripted Codemagic step | Before the first iOS build |
| CocoaPods / Swift packages, building, running on simulator or iPhone | **Mac** or Codemagic | Every iOS build |
| Info.plist entries (Google sign-in URL scheme, phone-auth reCAPTCHA scheme, camera/mic usage text) | Windows (text edit), verified on Mac/Codemagic | With auth work |
| **WidgetKit extension and watchOS app targets** (FR-TCH-03/05) | **Mac required**: new Xcode targets can't be created on Windows or by Codemagic | Widget phase |
| TestFlight upload | Codemagic | Beta |
