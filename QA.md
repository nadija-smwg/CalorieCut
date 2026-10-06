# CalorieCut device QA

Run `Scripts/verify_on_mac.sh` first. The following checks require Xcode/simulator or a physical iPhone and were **not run on the Linux authoring host**. Record device, OS, Xcode version, and results before approving a release.

## Build and first launch

- [ ] Build Debug and Release with Xcode 16+ for an iOS 17+ simulator and physical iPhone; inspect warnings and resolve any that affect behavior.
- [ ] Run all tests with ⌘U. Check the `.xcresult` for calculation, backup, SwiftData, notification-construction, and UI test results.
- [ ] Launch a clean normal install: welcome → profile → goals → Home. Edit the default name and other values; ensure they appear in Settings.
- [ ] Change the equation/activity/weekly goal; confirm BMR/TDEE/target respond correctly. Apply the suggestion; manually override within the supported range.
- [ ] Attempt blank name, out-of-range measurements, and a calorie goal below the supported floor. Ensure Save fails with visible guidance and onboarding does not advance.
- [ ] Kill/relaunch the app after onboarding. Onboarding should not reappear.

## Diary, library, and saved meals

- [ ] Log Milk Rice: one serving described as “2 pieces,” 400 kcal, 8 g protein, 55 g carbs, 16 g fat. Quantity 1 must log those values; quantity 2 must double them.
- [ ] Add Full Cream Milk at 110 kcal; breakfast total with one Milk Rice entry should be 510 kcal. Check Home, Diary, Review, and the calorie chart agree.
- [ ] Edit an entry's quantity and macros, duplicate it, move it from breakfast to dinner, and copy it to yesterday. Check all affected date/meal totals.
- [ ] Delete using both a swipe action and context menu; confirm only the intended entry disappears.
- [ ] Use search and favorites. Quick-add a single serving; tap a row to adjust quantity. Recently used foods should sort first.
- [ ] Create a reusable food. Change its values later, then confirm already logged entries still have their original snapshots. Delete the reusable food without deleting history.
- [ ] Create “My Breakfast” with two eggs, two bread servings, a banana, and tea. Compare the computed total with ingredient values. Log the meal once and confirm exactly four entries appear with their saved quantities.
- [ ] Edit/delete saved meals; confirm existing logged entries survive and deleted meal components do not remain in the database.
- [ ] Log on different dates/times, including a day across daylight-saving change. Confirm local-day grouping, no future logging, and date navigation behavior.

## Daily tracking and persistence

- [ ] Add 250 ml and 500 ml; total must be 750 ml. Add custom water and swipe-delete a water log; verify totals update everywhere.
- [ ] Set a custom water goal. The dashboard and Review should use it.
- [ ] Add weight-only, waist-only, and combined readings with notes. Switch kg/lb and cm/in; input and display must convert accurately.
- [ ] Edit and delete measurements; check charts and previous/current/change comparisons. Adding an older weight must not replace the profile's latest recorded weight.
- [ ] Add/update daily notes and steps for two dates. Confirm the records do not bleed between days.
- [ ] Kill/relaunch after food, water, notes, meals, favorites, settings, and measurements. Verify all survive. Turn Airplane Mode on and repeat logging and relaunch.
- [ ] Advance the device date or leave the app open overnight; Home should refresh for the new day. Calendar and diary should still expose yesterday.

## Reviews, calendar, and charts

- [ ] Empty diaries show no score, rather than a rewarded zero-calorie day. Today's review is provisional.
- [ ] A day near calorie goal with protein/water goals, three fruit/vegetable entries, and three meal categories receives the expected score; changing each factor changes the score.
- [ ] Very low/very high calorie days receive adequate-intake or balanced trend messages without food shaming. Do not compensate by recommending fasting or severe restriction.
- [ ] Calendar: near goal green, other below/close days yellow, >125% red, no entries gray. Future dates disabled. Tap a date and verify diary content.
- [ ] Switch 7-day, 30-day, 3-month, and All Time chart filters. Check empty states, single measurements, multiple same-day readings, and chart units/goals.
- [ ] Weekly report shows exactly seven calendar dates. Missing days are excluded from averages, and target counts still report out of seven days.
- [ ] Confirm gradual loss, overly rapid loss, and >=21-day stable weight guidance from the actual measurement history. Do not infer fat change from a single measurement.

## Notifications

- [ ] No system permission request on launch/onboarding or while all reminders are off.
- [ ] Enable one reminder and allow permission. Choose a time shortly ahead; background/lock the phone and verify delivery.
- [ ] Enable all six reminders with distinct times; inspect pending requests, then disable selected reminders and verify only their requests are removed.
- [ ] Deny permission; ensure the error is visible, preferences are not falsely saved, and Settings provides a link to iPhone settings.
- [ ] Relaunch and verify reminders retain settings and still fire. Test time-zone/DST changes on device. Scheduling failures should preserve previous requests where possible.

## Backup and restore

- [ ] Export through Share and Files. Open JSON and confirm profile, library, favorites, meals/components, food entries, measurements, water, notes/steps, preferences, and reminder times are present.
- [ ] Change/add data, import the earlier backup, review the replacement confirmation, and restore. Confirm exact nutrition/counts/history. Import twice; no duplicate entries/components should result.
- [ ] Cancel the replacement confirmation; data must remain unchanged.
- [ ] Try malformed JSON, unsupported version, duplicate IDs, negative values, and an oversized file; reject without deleting current data.
- [ ] Restored reminder times remain correct, and reminder switches start off. Re-enable explicitly and verify delivery.
- [ ] Export, delete all data, relaunch, finish onboarding, then import. Ensure the original history restores and default seeded foods do not duplicate it.

## Appearance and accessibility

- [ ] Test at least an iPhone SE-sized simulator and a large Pro Max-sized simulator, in portrait.
- [ ] Test System/Light/Dark appearance, large accessibility text, VoiceOver, and Reduce Motion.
- [ ] Verify cards/labels/keyboard fields fit, numeric input accepts the device's decimal separator, keyboard Done works, and sheets can be dismissed without saving.
- [ ] Verify VoiceOver labels for the calorie ring, chart summaries, meal actions, calendar status, quick add, and hydration controls.
- [ ] Check foreground/background transitions, local store failure messaging, and storage-low error handling. Existing data must not be silently reset.

## Final acceptance status

All requested feature implementations are included. This checklist distinguishes implementation from runtime validation; unchecked rows require the above tests on Apple tooling.

| Requirement | Source included | Runtime verified here |
|---|---|---|
| App builds successfully for iOS | Xcode project + scheme | No; Xcode unavailable |
| No backend or login | Yes | Source inspection |
| Offline operation | Yes; no network code | Source inspection; device test pending |
| SwiftData local storage, profile and food persistence | Yes | Integration tests included; not run |
| Daily calories, protein/carbs/fat totals | Yes | Foundation unit tests passed |
| Water totals | Yes | Foundation totals tests passed; UI/persistence pending |
| Weight/waist tracking | Yes | Units/trend tests passed; SwiftData/UI pending |
| Daily and weekly review calculations | Yes | Foundation unit tests passed |
| Charts and calendar | Yes | iOS runtime pending |
| Custom foods, saved meals, favorites | Yes | SwiftData/UI tests included; not run |
| Local notifications | Yes | Request tests included; permission/delivery pending |
| JSON encoding, decoding, validation | Yes | Foundation tests passed |
| JSON replacement restore | Yes | SwiftData integration tests included; not run |
| Dark mode | Yes | Source/assets inspected; visual runtime pending |
| Complete Xcode project delivered | Yes | Project structure/reference checks passed |
