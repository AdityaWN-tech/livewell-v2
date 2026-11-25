# Feature flags in Firebase Remote Config (T-FND-11, D-73)

The app reads its feature flags (spec 10.2 kill switches) from Remote Config.
Each Firebase project (dev `my-livewell`, later staging and prod) has its own
values.

## What the app does
- Defaults live in the app (`apps/mobile/lib/core/config/feature_flags.dart`,
  `defaultFlagsFor`): every flag off in staging and prod; in dev the avatar
  maker and From my photo are on only with `LW_MEDIA_URL` (D-64).
- A parameter left at **"Use in-app default"** changes nothing.
- On start the app applies the values it fetched last time, then fetches new
  ones (at most every 5 min in dev, 1 h in staging, 12 h in prod) and applies
  them. Offline or without Firebase it keeps the cached values or defaults.
- Only `true` or `false` are read. Anything else is ignored (default stays).
- **Prod-locked** (`ff_voice_clone`, `ff_dr_gokula_voice`,
  `ff_avatar_from_photo`, `ff_loved_one_voice`, `ff_photoreal_streaming`): in
  prod, `false` works as a kill switch, but `true` is ignored unless the
  build was made with
  `--dart-define=LW_PROD_ALLOW_FLAGS=voiceClone,drGokulaVoice` (only after the
  sign-off for that flag is recorded in `docs/decisions.md`).
- Safety routing, consents, the frequency cap and the closed-script voice
  rule are not flags and cannot be changed from Remote Config.

## Publish the parameters (once per project)
The template is `firebase/remoteconfig.template.json` (every parameter set
to "Use in-app default", so publishing it changes nothing in the app).

```powershell
cd "D:\Adii voult\Adii\LiveWell"
firebase deploy --only remoteconfig --project my-livewell
```

Deploying **replaces** the project's whole Remote Config template, including
values set in the console. Before deploying again, pull the live one and
merge your changes into the file:

```powershell
firebase remoteconfig:get --project my-livewell -o current.json
```

`firebase.json` names the template, so a plain `firebase deploy` (no
`--only`) would also overwrite Remote Config. Always deploy with `--only`.

## Turn a flag on or off
Firebase console > the project > Remote Config > the `ff_...` parameter >
set the default value to `true` or `false` (or add a condition, e.g. a
platform) > **Publish changes**. Phones pick it up on their next start after
the fetch interval. To go back to the app's own value, choose "Use in-app
default".

Spec "Done when" (T-FND-11): each flag toggles behaviour in **staging**. The
staging project doesn't exist yet (`Flavor.staging` has no Firebase options),
so check it in dev now and repeat in staging once that project is created.
