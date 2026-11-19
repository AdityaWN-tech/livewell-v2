# Travel Mode content: clinical review (T-TRV-01, D-86)

Everything Travel Mode shows (FR-TRV-02) and the daily travel steps that replace the plan's step while a trip is on (FR-TRV-01). All `pending` until approved: the dev build shows it, staging and prod show "being reviewed" and keep the plan's own step. Change `review_status` to `approved` in `travel.json` (and copy it to `apps/mobile/assets/travel/`) once signed off.

Rules: invitations, never orders or guilt; about an 8th-grade reading level; movement stays beginner or moderate and shows "Check with your clinician first" for people whose activity is limited (movement steps are never their daily step). **Not in v2:** medication, supplements or sleep aids (including melatonin), fasting, calorie targets, weight loss, alcohol advice. A daily step's title can be said by the coach inside an approved Moment line, so it must read well aloud.

Questions for the reviewers: is the hotel-room routine right for beginners and older adults? Are the jet-lag tips (daylight, short naps, bedtime shifts) right, and should anything be added for people with sleep conditions? Is a 1-minute 4-in / 6-out breath fine in public?

## Eat Well (`eat_well`)

Simple ways to eat well away from your own kitchen.

| id | Title | Text | Min | Movement | Approved? |
|---|---|---|---|---|---|
| `eat_plate` | Build a travel plate | At a buffet or a menu, start with vegetables or salad, add a protein you enjoy, then a small side. Enjoy every bite. | 2 | no | ☐ |
| `eat_snacks` | Pack two easy snacks | A piece of fruit and a small bag of nuts or roasted chickpeas keep you steady on long days and delays. | 5 | no | ☐ |
| `eat_water` | Keep a water bottle with you | Planes and hotel rooms are dry. Refill a bottle when you can and sip through the day. | 1 | no | ☐ |

## Move Well (`move_well`)

Short routines you can do in a hotel room or an airport.

| id | Title | Text | Min | Movement | Approved? |
|---|---|---|---|---|---|
| `move_hotel_room` | 10-minute hotel-room routine | No equipment needed. March in place for 2 minutes. Do 10 slow sit-to-stands from the bed or a chair. Do 10 wall push-ups. Finish with gentle shoulder rolls and a calf stretch. Rest whenever you need to. | 10 | yes | ☐ |
| `move_seat` | Seat stretches on the go | On a plane, train or car seat: circle your ankles, lift your heels and toes, and roll your shoulders. Stand up and walk the aisle when it's safe. | 3 | yes | ☐ |
| `move_explore` | Explore on foot | Walk to a nearby park, market or sight at an easy pace. It's a gentle way to see a new place and get some daylight. | 15 | yes | ☐ |

## Sleep and Recover (`sleep_recover`)

Rest well in a new bed and help your body clock catch up.

| id | Title | Text | Min | Movement | Approved? |
|---|---|---|---|---|---|
| `sleep_room` | Set up your room for sleep | Make the room dark and a little cool. Turn the clock away, put your phone across the room, and keep the same bedtime steps you use at home. | 5 | no | ☐ |
| `sleep_jet_lag_light` | Jet lag: use daylight | Daylight is the strongest signal for your body clock. Spend some time outside in the morning light at your destination, and keep evenings dim. | 15 | no | ☐ |
| `sleep_jet_lag_nap` | Jet lag: keep naps short | If you need a nap, keep it to about 20 minutes and before mid-afternoon local time, so you can still sleep at night. | 20 | no | ☐ |

## Breathe and Reset (`breathe_reset`)

Calm moments for busy airports and long days.

| id | Title | Text | Min | Movement | Approved? |
|---|---|---|---|---|---|
| `breathe_gate` | One-minute reset at the gate | Sit back, drop your shoulders and breathe in for 4, out for 6. Repeat for a minute. If you feel dizzy or unwell, stop and breathe normally. | 1 | no | ☐ |
| `breathe_arrive` | Arrive and settle | When you reach your room, put your bag down, sit for a moment and notice five things you can see. Then unpack one small thing that feels like home. | 3 | no | ☐ |

## Jet-lag tips

Chosen from the time difference between home and the trip's time zone (3 hours or more: east or west).

| id | When | Title | Text | Approved? |
|---|---|---|---|---|
| `jl_small` | small | A small time change | Your body will catch up quickly. Keep your usual bedtime steps and get some daylight in the morning. | ☐ |
| `jl_east` | east | You're travelling ahead in time | Going east usually feels harder. Get morning daylight at your destination, keep evenings dim, and go to bed a little earlier for the first few nights. | ☐ |
| `jl_west` | west | You're travelling back in time | Going west, try to stay up until a normal local bedtime. Afternoon daylight helps you stay awake a little longer. | ☐ |

## Daily travel steps

One per trip day, in this order.

| id | Pillar | Step | Smaller step | Why | Movement | Approved? |
|---|---|---|---|---|---|---|
| `step_hotel_room` | move_well | Do the 10-minute hotel-room routine (10 min) | March in place for 3 minutes (3 min) | A short routine keeps you moving when your day looks different. | yes | ☐ |
| `step_water` | eat_well | Refill your water bottle twice today (2 min) | Drink one glass of water now (1 min) | Travel days are dry. Water helps you feel more awake. | no | ☐ |
| `step_daylight` | sleep_recover | Spend 15 minutes in morning daylight (15 min) | Open the curtains and sit by the window for 5 minutes (5 min) | Daylight helps your body clock settle into the new time zone. | no | ☐ |
| `step_breathe` | breathe_reset | Take a one-minute breathing reset (1 min) | — | A calm minute helps on busy travel days. | no | ☐ |
| `step_plate` | eat_well | Start one meal with vegetables or salad (5 min) | Add one piece of fruit to your day (2 min) | Adding something good is easier than cutting things out. | no | ☐ |
| `step_walk` | move_well | Take a 10-minute walk outside (10 min) | Take a 5-minute walk (5 min) | An easy walk is a nice way to get to know a new place. | yes | ☐ |
| `step_wind_down` | sleep_recover | Dim the lights an hour before bed (5 min) | — | A calm, dark room helps you sleep in a new place. | no | ☐ |
