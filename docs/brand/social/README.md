# Social sign-in logos (T-ONB-03a)

Official brand artwork, used unchanged: not recoloured, distorted or redrawn.

| File | Source | Used as |
|---|---|---|
| `google-logo-light-pill.svg`, `google-logo-dark-pill.svg` | Google Identity "Sign in with Google" branding kit, `signin-assets.zip` (developers.google.com/static/identity/images/signin-assets.zip), *Android + Web, Show text = No, Shape = Pill* | Reference. The app bundles the kit's own PNGs (1x to 4x) from the same set as `apps/mobile/assets/brand/social/google_light.png` / `google_dark.png`, because the SVGs use blur filters and an embedded HTML gradient that Flutter can't draw. |
| `apple-logo-black-on-white-square.svg`, `apple-logo-white-on-black-square.svg` | Apple Design Resources, *Sign in with Apple Logo* (devimages-cdn.apple.com/design/resources/download/Logo-Sign-in-with-Apple.dmg), logo-only "Square" artwork | The app draws Apple's logo path from this file (`apple_logo.dart`) inside a circular mask, which Apple's guidelines allow for logo-only buttons. |

Theme pairing:
- **Google:** the light button (white, `#747775` outline) on light screens; the dark button (`#131314`, `#8E918F` outline) on dark screens.
- **Apple:** black button with a white logo on light screens; white button with a black logo on dark screens.

**Guidelines followed:**
- Logo-only buttons, at the same size as each other.
- Both have an accessible label ("Continue with Google" / "Continue with Apple").
- Sign in with Apple is offered wherever Google is (App Store rule 4.8).

Re-download the kits when the brands update their artwork.
