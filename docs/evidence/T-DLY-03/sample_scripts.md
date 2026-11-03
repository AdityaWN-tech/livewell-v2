# Avatar Moment scripts: sample output (T-DLY-03a)

What the script builder produces for Priya (Why: "Energy to travel with my family.", step: "Walk for 10 minutes after lunch", smaller: 5 minutes, streak 9, 5 steps this week) on three days in a row. Made by the builder from `content/coach/moments` (all lines pending clinical review; see REVIEW.md).

| Moment | Day | message_id | Expression | Buttons | Script |
|---|---|---|---|---|---|
| morning | Oct 14 | `morning.m2@v1` | waving | checkIn (+ startStep, makeSmaller) | Good morning, Priya! A new day is a fresh start. Today's step: walk for 10 minutes after lunch. Want to check in first and tell me how you feel? |
| morning | Oct 15 | `morning.m3@v1` | waving | checkIn (+ startStep, makeSmaller) | Hi Priya, good morning! You are doing this for a reason: energy to travel with my family. One small step today: walk for 10 minutes after lunch. How are you feeling? |
| morning | Oct 16 | `morning.m1@v1` | waving | checkIn (+ startStep, makeSmaller) | Good morning, Priya! Hope you slept well. Remember your why: energy to travel with my family. Today's step: walk for 10 minutes after lunch. Short on time? 5 minutes still counts. How are you feeling today? |
| stepReminder | Oct 14 | `step_reminder.r2@v1` | encouraging | startStep (+ done, makeSmaller, notToday) | Ready for your step, Priya? It's this one: walk for 10 minutes after lunch. Want to start now? |
| stepReminder | Oct 15 | `step_reminder.r3@v1` | encouraging | startStep (+ done, makeSmaller, notToday) | Hi Priya! Your step is waiting: walk for 10 minutes after lunch. Short on time? 5 minutes still counts. |
| stepReminder | Oct 16 | `step_reminder.r1@v1` | encouraging | startStep (+ done, makeSmaller, notToday) | Hi Priya, it's a great time for your step: walk for 10 minutes after lunch. Shall we go? |
| stepDone | Oct 14 | `step_done.d3@v1` | celebrating | close | Nice work! That's done for today. Enjoy the rest of your day. |
| stepDone | Oct 15 | `step_done.d4@v1` | celebrating | close | Well done! One more small step for you today. |
| stepDone | Oct 16 | `step_done.d1@v1` | celebrating | close | You did it! That's day 9. I'm proud of you. |
| evening | Oct 14 | `evening.e1@v1` | listening | reply (+ notToday) | Hi Priya, how did today go? What went well, and what got in the way? |
| evening | Oct 15 | `evening.e2@v1` | listening | reply (+ notToday) | Good evening, Priya. Take a moment: what is one thing that went well today? |
| evening | Oct 16 | `evening.e1@v1` | listening | reply (+ notToday) | Hi Priya, how did today go? What went well, and what got in the way? |
| gentle | Oct 14 | `gentle.g1@v1` | calm | startStep (+ notToday) | Thanks for telling me how you feel, Priya. Let's keep today gentle. One small step is enough: walk for 5 minutes after lunch. |
| gentle | Oct 15 | `gentle.g2@v1` | calm | startStep (+ notToday) | I'm glad you checked in. Today can be a gentle day. If you feel up to it, try this: walk for 5 minutes after lunch. If not, that's okay too. |
| gentle | Oct 16 | `gentle.g1@v1` | calm | startStep (+ notToday) | Thanks for telling me how you feel, Priya. Let's keep today gentle. One small step is enough: walk for 5 minutes after lunch. |
| missedDay | Oct 14 | `missed_day.x1@v1` | encouraging | restart (+ checkIn) | Good morning, Priya. Yesterday was a rest day, and that's okay. Let's restart with a small step: walk for 10 minutes after lunch. |
| missedDay | Oct 15 | `missed_day.x2@v1` | encouraging | restart (+ checkIn) | Welcome back, Priya! Rest days are part of the plan. Today's step: walk for 10 minutes after lunch. Want to give it a try? |
| missedDay | Oct 16 | `missed_day.x1@v1` | encouraging | restart (+ checkIn) | Good morning, Priya. Yesterday was a rest day, and that's okay. Let's restart with a small step: walk for 10 minutes after lunch. |
| weeklyReview | Oct 14 | `weekly_review.w1@v1` | happy | seeWeek | This week you completed 5 steps. Great work, Priya! Want to see your week? |
| weeklyReview | Oct 15 | `weekly_review.w2@v1` | happy | seeWeek | Look at your week: 5 steps done. Every one counts. Shall we look at it together? |
| weeklyReview | Oct 16 | `weekly_review.w1@v1` | happy | seeWeek | This week you completed 5 steps. Great work, Priya! Want to see your week? |
