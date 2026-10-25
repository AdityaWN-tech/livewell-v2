# Avatar Moment scripts: clinical review (T-DLY-03)

Every line the coach can say in an Avatar Moment. All are `pending` until approved; the app uses only approved lines outside the dev build. Placeholders in `{braces}` are filled from the person's own data (first name, Why, the name they gave their coach), their plan (step, minutes), or an activity's approved name from the routine catalog (T-GOL-03e); nothing else.

Rules the lines follow: invitations, never orders or guilt; about an 8th-grade reading level; one step plus a smaller option; steps come only from the person's plan; no portal or course mentions; safety, crisis and medical messages are never Avatar Moments (they use the safety cards and the neutral voice).

## morning

When: Morning briefing (7:00 by default, user-set). Expression: waving. Buttons: check_in (also: start_step, make_smaller).

| id | Line | Approved? |
|---|---|---|
| `morning.m1` | Good {time_of_day}, {first_name}! Hope you slept well. Remember your why: {why}. Today's step: {step_title}. Short on time? {smaller_minutes} minutes still counts. How are you feeling today? | ☐ |
| `morning.m2` | Good {time_of_day}, {first_name}! A new day is a fresh start. Today's step: {step_title}. Want to check in first and tell me how you feel? | ☐ |
| `morning.m3` | Hi {first_name}, good {time_of_day}! You are doing this for a reason: {why}. One small step today: {step_title}. How are you feeling? | ☐ |
| `morning.m4` | Good {time_of_day}! Today's step: {step_title}. Even {smaller_minutes} minutes counts. How are you feeling today? | ☐ |
| `morning.m5` | Good {time_of_day}, {first_name}! How are you feeling today? Let's find a small step that fits your day. | ☐ |
| `morning.m6` | Good {time_of_day}! How are you feeling today? Let's find a small step that fits your day. | ☐ |

## step_reminder

When: Step reminder at the habit's anchor (13:00 by default). Expression: encouraging. Buttons: start_step (also: done, make_smaller, not_today).

| id | Line | Approved? |
|---|---|---|
| `step_reminder.r1` | Hi {first_name}, it's a great time for your step: {step_title}. Shall we go? | ☐ |
| `step_reminder.r2` | Ready for your step, {first_name}? It's this one: {step_title}. Want to start now? | ☐ |
| `step_reminder.r3` | Hi {first_name}! Your step is waiting: {step_title}. Short on time? {smaller_minutes} minutes still counts. | ☐ |
| `step_reminder.r4` | It's a good moment for your step: {step_title}. Shall we start? | ☐ |
| `step_reminder.r5` | Your step is ready when you are: {step_title}. Want to give it a try? | ☐ |

## step_done

When: Right after the person taps Done. Expression: celebrating. Buttons: close.

| id | Line | Approved? |
|---|---|---|
| `step_done.d1` | You did it! That's day {streak_days}. I'm proud of you. | ☐ |
| `step_done.d2` | You did it, {first_name}! Every small step adds up. | ☐ |
| `step_done.d3` | Nice work! That's done for today. Enjoy the rest of your day. | ☐ |
| `step_done.d4` | Well done! One more small step for you today. | ☐ |

## evening

When: Evening reflection (20:30 by default). Expression: listening. Buttons: reply (also: not_today).

| id | Line | Approved? |
|---|---|---|
| `evening.e1` | Hi {first_name}, how did today go? What went well, and what got in the way? | ☐ |
| `evening.e2` | Good evening, {first_name}. Take a moment: what is one thing that went well today? | ☐ |
| `evening.e3` | How did today go? Tell me one thing that went well. | ☐ |
| `evening.e4` | Good evening! What went well today, even if it was something small? | ☐ |

## gentle

When: After a check-in with low mood or high stress (gentle day). Expression: calm. Buttons: start_step (also: not_today).

| id | Line | Approved? |
|---|---|---|
| `gentle.g1` | Thanks for telling me how you feel, {first_name}. Let's keep today gentle. One small step is enough: {step_title}. | ☐ |
| `gentle.g2` | I'm glad you checked in. Today can be a gentle day. If you feel up to it, try this: {step_title}. If not, that's okay too. | ☐ |
| `gentle.g3` | Thanks for telling me, {first_name}. Let's go easy today. Rest is part of the plan too. | ☐ |
| `gentle.g4` | Thanks for telling me. Let's go easy today. Rest is part of the plan too. | ☐ |

## missed_day

When: The morning after a day with no step done and no check-in. Expression: encouraging. Buttons: restart (also: check_in).

| id | Line | Approved? |
|---|---|---|
| `missed_day.x1` | Good {time_of_day}, {first_name}. Yesterday was a rest day, and that's okay. Let's restart with a small step: {step_title}. | ☐ |
| `missed_day.x2` | Welcome back, {first_name}! Rest days are part of the plan. Today's step: {step_title}. Want to give it a try? | ☐ |
| `missed_day.x3` | Good {time_of_day}! Yesterday was a rest day, and that's okay. Let's restart with one small step. | ☐ |

## weekly_review

When: Sunday 08:00. Expression: happy. Buttons: see_week.

| id | Line | Approved? |
|---|---|---|
| `weekly_review.w1` | This week you completed {weekly_count} steps. Great work, {first_name}! Want to see your week? | ☐ |
| `weekly_review.w2` | Look at your week: {weekly_count} steps done. Every one counts. Shall we look at it together? | ☐ |
| `weekly_review.w3` | A new week is a fresh start. Want to look back at your week together? | ☐ |
| `weekly_review.w4` | You made time for {routine_win} on {routine_win_days} days this week, {first_name}! Small steps add up. Want to see your week? | ☐ |
| `weekly_review.w5` | This week you made time for {routine_win} on {routine_win_days} days. That's a habit taking root. Want to see your week? | ☐ |

## first_hello

When: Once, on Home right after onboarding (avatar, voice and Why chosen). Expression: waving, then happy. Buttons: start_step (also: close).

| id | Line | Approved? |
|---|---|---|
| `first_hello.h1` | Hi {first_name}, I'm {coach_name}, your Live Well coach. You told me your why: {why}. Let's start with one small step: {step_title}. | ☐ |
| `first_hello.h2` | Hi {first_name}, I'm {coach_name}, your Live Well coach. Let's start with one small step: {step_title}. | ☐ |
| `first_hello.h3` | Hi {first_name}, I'm {coach_name}, your Live Well coach. I'm here to help you take one small step at a time. | ☐ |
| `first_hello.h4` | Hi, I'm {coach_name}, your Live Well coach. I'm here to help you take one small step at a time. | ☐ |
| `first_hello.h5` | Hi, I'm your Live Well coach. I'm here to help you take one small step at a time. | ☐ |
| `first_hello.h6` | Hello! I'm your Live Well coach. Let's take one small step at a time, together. | ☐ |
| `first_hello.h7` | Hi {first_name}, I'm your Live Well coach. You told me your why: {why}. Let's start with one small step: {step_title}. | ☐ |
| `first_hello.h8` | Hi {first_name}, I'm your Live Well coach. Let's start with one small step: {step_title}. | ☐ |

## checkin_good

When: Right after a check-in with a good mood (4 or 5) and no gentle day. Expression: happy. Buttons: close (also: start_step).

| id | Line | Approved? |
|---|---|---|
| `checkin_good.c1` | Love that energy, {first_name}! Thanks for checking in. | ☐ |
| `checkin_good.c2` | Love that energy! Thanks for checking in. | ☐ |
| `checkin_good.c3` | Great to hear you feel good, {first_name}. Your step is ready when you are: {step_title}. | ☐ |
| `checkin_good.c4` | Great to hear! Your step is ready when you are: {step_title}. | ☐ |

## checkin_okay

When: Right after a check-in with an okay mood (3) and no gentle day. Expression: happy. Buttons: close (also: start_step).

| id | Line | Approved? |
|---|---|---|
| `checkin_okay.o1` | Thanks for checking in, {first_name}. | ☐ |
| `checkin_okay.o2` | Thanks for checking in. One small step at a time. | ☐ |
| `checkin_okay.o3` | Thanks for checking in, {first_name}. Want to try today's step? It's this one: {step_title}. | ☐ |
| `checkin_okay.o4` | Thanks for checking in. Today's step is ready when you are: {step_title}. | ☐ |

## streak_milestone

When: Instead of step_done when the streak reaches 7, 14 or 30 days. Expression: celebrating. Buttons: close.

| id | Line | Approved? |
|---|---|---|
| `streak_milestone.s1` | That's {streak_days} days in a row, {first_name}! That's a real habit now. | ☐ |
| `streak_milestone.s2` | {streak_days} days in a row! Every small step adds up. | ☐ |
| `streak_milestone.s3` | Wow, {first_name}, {streak_days} days in a row! I'm proud of you. | ☐ |
| `streak_milestone.s4` | {streak_days} days in a row. That's a real habit now! | ☐ |
