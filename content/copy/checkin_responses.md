# Check-in responses (Home, after the daily check-in)

Fixed template list for T-DLY-02 (no AI yet). **DRAFT: needs review by the Clinical Content and Safety Committee.**
Each line is `- <ARB key>: "<text>"`. The app's `lib/l10n/app_en.arb` must hold exactly these texts; `test/checkin/checkin_copy_test.dart` fails if they differ.
Reading level about 8th grade; kind, never shaming.

| When | Rule |
|---|---|
| Gentle day | mood 1-2, or stress 4-5, or a red flag in "Anything that could make today hard?" |
| High | mood 4-5 and not a gentle day |
| Steady | mood 3 and not a gentle day |

- checkinResponseHigh: "Love that energy. Let's use it well today."
- checkinResponseSteady: "Thanks for checking in. One small step is plenty today."
- checkinResponseGentle: "Thanks for telling me. Let's keep today gentle."
