# My Daily Routine lines: clinical review (T-GOL-03)

Every activity a person can add from the catalog, and every line the coach can say when it's time for one. All are `pending` until approved; the app uses only approved lines outside the dev build. Placeholders: `{first_name}` (the person's first name) and `{time}` (the item's time). Nothing else.

Rules: invitations, never orders or guilt; about an 8th-grade reading level; movement stays beginner or moderate. Movement items are off by default for people who said an activity limits them, and show "Check with your clinician first" (FR-GOL-03). **Not in v2:** fasting, calorie targets, weight loss, medication or supplements.

**Custom items** (typed by the person) are shown as text only. The coach never speaks them (closed-script rule, FR-VOC-05); it says one of the general lines at the end.

## Wake up (`wake_up`)

Icon: sunrise. Kind: rest. Movement: no. Default: 07:00, 5 min.

| id | Line | Approved? |
|---|---|---|
| `wake_up.w1` | Good morning, {first_name}! Time to wake up and start your day gently. | ☐ |
| `wake_up.w2` | Good morning! It's {time}. Time to wake up and stretch your arms. | ☐ |

## Drink water (`drink_water`)

Icon: water. Kind: nourish. Movement: no. Default: 07:15, 2 min.

| id | Line | Approved? |
|---|---|---|
| `drink_water.d1` | Hi {first_name}! Time for a glass of water. | ☐ |
| `drink_water.d2` | It's {time}. A glass of water is a nice way to look after yourself. | ☐ |

## Morning stretch (`morning_stretch`)

Icon: stretch. Kind: move. Movement: yes. Default: 07:30, 5 min.

| id | Line | Approved? |
|---|---|---|
| `morning_stretch.s1` | Hi {first_name}! It's {time}, time for a little stretch. Go slowly and only as far as feels good. | ☐ |
| `morning_stretch.s2` | Ready for a gentle stretch? A few easy minutes is plenty. | ☐ |

## Morning walk (`morning_walk`)

Icon: walk. Kind: move. Movement: yes. Default: 07:45, 10 min.

| id | Line | Approved? |
|---|---|---|
| `morning_walk.m1` | Good morning, {first_name}! How about a short walk at an easy pace? | ☐ |
| `morning_walk.m2` | It's {time}. A short, easy walk is a nice way to start the day. | ☐ |

## Breathing break (`breathing_break`)

Icon: breathe. Kind: mind. Movement: no. Default: 11:00, 2 min.

| id | Line | Approved? |
|---|---|---|
| `breathing_break.b1` | Hi {first_name}, let's take a short breathing break. Breathe in slowly, and out even slower. | ☐ |
| `breathing_break.b2` | Time for a breathing break. Two calm minutes, just for you. | ☐ |

## Healthy breakfast (`healthy_breakfast`)

Icon: breakfast. Kind: nourish. Movement: no. Default: 08:00, 15 min.

| id | Line | Approved? |
|---|---|---|
| `healthy_breakfast.h1` | Good morning, {first_name}! Time for breakfast. Enjoy it, there's no rush. | ☐ |
| `healthy_breakfast.h2` | It's {time}, a good time for breakfast. Sit down and enjoy it. | ☐ |

## Work break (`work_break`)

Icon: pause. Kind: rest. Movement: no. Default: 15:00, 5 min.

| id | Line | Approved? |
|---|---|---|
| `work_break.k1` | Hi {first_name}, time for a short break. Stand up, look away from the screen and relax your shoulders. | ☐ |
| `work_break.k2` | You've been at it a while. How about a five-minute break? | ☐ |

## Walk after a meal (`walk_after_meal`)

Icon: walk. Kind: move. Movement: yes. Default: 13:30, 10 min.

| id | Line | Approved? |
|---|---|---|
| `walk_after_meal.a1` | Hi {first_name}! How about a short, easy walk after your meal? | ☐ |
| `walk_after_meal.a2` | It's {time}. A gentle walk after eating can feel really good. | ☐ |

## Family time (`family_time`)

Icon: family. Kind: social. Movement: no. Default: 19:00, 30 min.

| id | Line | Approved? |
|---|---|---|
| `family_time.f1` | Hi {first_name}, it's time for family time. Enjoy being together. | ☐ |
| `family_time.f2` | It's {time}. A good moment to spend time with the people you love. | ☐ |

## Read (`read`)

Icon: book. Kind: mind. Movement: no. Default: 20:30, 15 min.

| id | Line | Approved? |
|---|---|---|
| `read.r1` | Hi {first_name}! Time to relax with something to read. | ☐ |
| `read.r2` | It's {time}. How about a few pages of a good book? | ☐ |

## Prayer or quiet time (`quiet_time`)

Icon: quiet. Kind: mind. Movement: no. Default: 06:45, 10 min.

| id | Line | Approved? |
|---|---|---|
| `quiet_time.q1` | Hi {first_name}, it's time for a few quiet minutes, just for you. | ☐ |
| `quiet_time.q2` | It's {time}. Time for your quiet time. | ☐ |

## Screen off (`screen_off`)

Icon: screen_off. Kind: sleep. Movement: no. Default: 21:30, 5 min.

| id | Line | Approved? |
|---|---|---|
| `screen_off.o1` | Hi {first_name}, it's time to put the screens away for the night. | ☐ |
| `screen_off.o2` | It's {time}. Screens off helps your mind slow down for sleep. | ☐ |

## Sleep wind-down (`sleep_wind_down`)

Icon: moon. Kind: sleep. Movement: no. Default: 22:00, 15 min.

| id | Line | Approved? |
|---|---|---|
| `sleep_wind_down.n1` | Hi {first_name}, time to wind down. Dim the lights and take it slow. | ☐ |
| `sleep_wind_down.n2` | It's {time}. A calm wind-down helps you sleep well. | ☐ |

## Bedtime (`bedtime`)

Icon: bed. Kind: sleep. Movement: no. Default: 22:30, 5 min.

| id | Line | Approved? |
|---|---|---|
| `bedtime.t1` | Good night, {first_name}. It's bedtime. Sleep well. | ☐ |
| `bedtime.t2` | It's {time}, bedtime. You did well today. Sleep well. | ☐ |

## Custom items (general lines)

| id | Line | Approved? |
|---|---|---|
| `custom.c1` | Hi {first_name}, it's time for your next routine step. | ☐ |
| `custom.c2` | It's {time}. Time for your next routine step. | ☐ |

## Quick-start templates

The person picks one and edits it. Movement items are left out for people whose activity is limited.

| Template | Days | Items |
|---|---|---|
| Morning starter (`morning_starter`) | everyDay | 07:00 Wake up, 07:10 Drink water, 07:20 Morning stretch, 07:45 Healthy breakfast |
| Workday (`workday`) | weekdays | 06:45 Wake up, 07:00 Drink water, 07:30 Healthy breakfast, 11:00 Work break, 13:30 Walk after a meal, 16:00 Breathing break, 21:30 Screen off, 22:30 Bedtime |
| Weekend (`weekend`) | weekend | 08:00 Wake up, 08:10 Drink water, 09:00 Morning walk, 17:00 Family time, 21:00 Read, 23:00 Bedtime |
| Travel day (`travel_day`) | oneDay | 08:00 Drink water, 12:00 Breathing break, 13:30 Walk after a meal, 22:00 Sleep wind-down |

## Weekly review names

The coach's weekly review can say "you made time for {name} on {days} days this week" for a catalog activity done on at least 4 days (never a custom item).

| Activity | Spoken name |
|---|---|
| Wake up (`wake_up`) | an easy start to your day |
| Drink water (`drink_water`) | a glass of water |
| Morning stretch (`morning_stretch`) | a morning stretch |
| Morning walk (`morning_walk`) | a morning walk |
| Breathing break (`breathing_break`) | a breathing break |
| Healthy breakfast (`healthy_breakfast`) | a good breakfast |
| Work break (`work_break`) | a short break |
| Walk after a meal (`walk_after_meal`) | a walk after your meal |
| Family time (`family_time`) | family time |
| Read (`read`) | some reading |
| Prayer or quiet time (`quiet_time`) | some quiet time |
| Screen off (`screen_off`) | a screen-free evening |
| Sleep wind-down (`sleep_wind_down`) | a calm wind-down |
| Bedtime (`bedtime`) | a regular bedtime |
