import { test } from 'node:test';
import assert from 'node:assert/strict';
import { defaultProfile, suggestion, validateProfile, validateFood, emptyDiary, stats, streak, weekly, review, validateBackup, decodeBackup, encodeBackup, shiftDay, dateForDay, dayKey, uid, now, toDisplay, toMetric, weightAdvice, statisticsByDay } from '../src/core.js';
const profile = { ...defaultProfile, name: 'Alex' };
function diary() { const d = emptyDiary(); d.profile = { id: uid(), createdAt: now(), values: { ...profile } }; return d; }
function entry(key = dayKey(), values = {}) { return { id: uid(), createdAt: now(), values: { id: uid(), name: 'Test food', serving: '1 serving', calories: 100, protein: 10, carbs: 20, fat: 2, category: 'Protein', meal: 'Breakfast', quantity: 1, date: key === dayKey() ? now() : dateForDay(key), ...values } }; }
test('calorie calculations match native values and all activity multipliers', () => {
  assert.equal(suggestion(profile).bmr, 1638.75);
  assert.equal(suggestion(profile).tdee, 2253.28125);
  assert.equal(suggestion(profile).target, 1980);
  assert.equal(suggestion({ ...profile, sex: 'Female' }).bmr, 1472.75);
  for (const [activity, multiplier] of [['Sedentary', 1.2], ['Lightly active', 1.375], ['Moderately active', 1.55], ['Very active', 1.725]]) assert.equal(suggestion({ ...profile, activity }).tdee, 1638.75 * multiplier);
});
test('deficit, surplus, and minimum intake safeguards match native rules', () => {
  const deficit = suggestion({ ...profile, weeklyChange: 1 });
  assert.ok(deficit.adjusted);
  assert.ok(deficit.tdee - deficit.target <= Math.min(500, deficit.tdee * 0.2) + 5);
  assert.equal(suggestion({ ...profile, sex: 'Female', weight: 40, height: 145, age: 80, activity: 'Sedentary', weeklyChange: 1 }).target, 1200);
  assert.equal(suggestion({ ...profile, goal: 'Gain weight', weeklyChange: 1 }).target, Math.round((2253.28125 + 350) / 10) * 10);
});
test('profile validation rejects unsupported ages and low calorie goals', () => {
  assert.equal(validateProfile(profile), profile);
  for (const change of [{ name: '' }, { age: 17 }, { age: 22.5 }, { calories: 900 }, { weight: Infinity }, { activity: 'unknown' }, { water: 0 }]) assert.throws(() => validateProfile({ ...profile, ...change }));
});
test('food validation rejects invalid amounts, categories and future dates', () => {
  const f = entry().values;
  for (const change of [{ quantity: 0 }, { calories: -1 }, { protein: NaN }, { category: 'bad' }, { date: 'broken' }, { date: new Date(Date.now() + 86400000).toISOString() }]) assert.throws(() => validateFood({ ...f, ...change }));
});
test('nutrition multiplies snapshots by quantity and isolates local days', () => {
  const d = diary(); d.entries = [entry(dayKey(), { quantity: 2 }), entry(shiftDay(dayKey(), -1), { calories: 900 })];
  d.water = [{ id: uid(), amount: 250, date: now() }];
  const s = stats(d, dayKey());
  assert.equal(s.calories, 200); assert.equal(s.protein, 20); assert.equal(s.water, 250); assert.equal(s.entryCount, 1); assert.equal(s.meals.Breakfast, 200);
});
test('weekly averages exclude missing days', () => {
  const d = diary(); d.entries = [entry(), entry(shiftDay(dayKey(), -1), { calories: 300 })];
  const w = weekly(d); assert.equal(w.days.length, 7); assert.equal(w.logged, 2); assert.equal(w.averageCalories, 200);
});
test('streak tolerates not yet logged today and calendar shifting crosses DST', () => {
  const d = diary(); d.entries = [entry(shiftDay(dayKey(), -1)), entry(shiftDay(dayKey(), -2))];
  assert.equal(streak(d), 2); d.entries.push(entry()); assert.equal(streak(d), 3);
  assert.equal(shiftDay('2026-03-08', 1), '2026-03-09'); assert.equal(shiftDay('2026-11-01', -1), '2026-10-31');
});
test('empty diaries have no score and very low intake does not earn a perfect score', () => {
  const d = diary(); assert.equal(review(stats(d, dayKey()), profile, false).score, null);
  d.entries = [entry(dayKey(), { calories: 400, protein: 120 })]; d.water = [{ id: uid(), amount: 2500, date: now() }];
  assert.ok(review(stats(d, dayKey()), profile, true).score < 6);
});
test('complete balanced logging receives native perfect review score', () => {
  const d = diary(); d.entries = ['Breakfast', 'Lunch', 'Dinner'].map(meal => entry(dayKey(), { meal, calories: 1900 / 3, protein: 40, category: 'Vegetable' })); d.water = [{ id: uid(), amount: 2500, date: now() }];
  const r = review(stats(d, dayKey()), profile, true); assert.equal(r.score, 10); assert.equal(r.rating, 'Excellent');
});
test('backups round trip and imported reminders restart disabled', () => {
  const d = diary(); d.entries = [entry()]; d.settings.reminders[0].enabled = true;
  assert.doesNotThrow(() => validateBackup(d));
  const restored = decodeBackup(JSON.stringify(d)); assert.equal(restored.entries[0].values.calories, 100); assert.equal(restored.settings.reminders[0].enabled, false);
});
test('exported timestamps are compatible with native ISO8601 decoding', () => {
  const d = diary(); d.entries = [entry()]; d.webRevision = 3;
  const encoded = encodeBackup(d), restored = decodeBackup(encoded);
  assert.match(JSON.parse(encoded).exportedAt, /:\d\dZ$/);
  assert.doesNotMatch(encoded, /\.\d{3}Z/);
  assert.equal(restored.webRevision, undefined);
  assert.equal(restored.entries[0].values.quantity, 1);
});
test('malformed, unsupported and oversized backups are rejected', () => {
  assert.throws(() => decodeBackup('{bad'), /valid JSON/);
  assert.throws(() => decodeBackup(JSON.stringify({ ...diary(), version: 2 })), /version/);
  assert.throws(() => decodeBackup(' '.repeat(25000001)), /too large/);
});
test('backup validation rejects duplicate IDs, invalid records, and missing collections', () => {
  for (const alter of [d => { d.entries = [entry(), entry()]; d.entries[1].id = d.entries[0].id; }, d => { d.water = [{ id: uid(), amount: -1, date: now() }]; }, d => { d.measurements = [{ id: uid(), date: now(), weight: null, waist: null, notes: '' }]; }, d => { d.notes = [{ id: uid(), date: now(), text: '', steps: 1.1 }]; }, d => { d.settings.theme = 'bad'; }, d => { d.meals = [{ id: uid(), name: 'bad meal', createdAt: now(), foods: [] }]; }, d => { delete d.foods; }]) {
    const d = diary(); alter(d); assert.throws(() => validateBackup(d));
  }
});
test('diary entries remain snapshots when library food changes', () => {
  const d = diary(), f = d.foods[0]; d.entries.push(entry(dayKey(), { ...structuredClone(f.values), id: uid(), date: now() }));
  const before = stats(d, dayKey()).calories; f.values.calories = 999; assert.equal(stats(d, dayKey()).calories, before);
});
test('backup IDs cannot inject markup and unknown top-level fields are omitted', () => {
  const d = diary(); d.entries = [entry()];
  const unsafe = structuredClone(d); unsafe.entries[0].id = '" onclick="bad()';
  assert.throws(() => decodeBackup(JSON.stringify(unsafe)), /identifiers/);
  const raw = JSON.stringify(d).replace('"version":1', '"version":1,"__proto__":{"unsafe":true},"webRevision":999');
  const decoded = decodeBackup(raw);
  assert.equal(Object.hasOwn(decoded, '__proto__'), false); assert.equal(decoded.webRevision, undefined);
});
test('imperial round trips preserve valid profile and measurement boundaries', () => {
  for (const [unit, values] of [['lb', [30, 65, 350]], ['in', [30, 100, 250]]]) for (const value of values) {
    const displayed = Math.round(toDisplay(value, unit) * 10000) / 10000;
    assert.equal(toMetric(displayed, unit), value);
  }
});
test('historical weight advice uses the selected week and excludes later measurements', () => {
  const d = diary(), ending = shiftDay(dayKey(), -60);
  d.entries = Array.from({ length: 4 }, (_, i) => entry(shiftDay(ending, -i)));
  d.measurements = [{ id: uid(), date: dateForDay(shiftDay(ending, -7)), weight: 65, waist: null, notes: '' }, { id: uid(), date: dateForDay(ending), weight: 64.8, waist: null, notes: '' }, { id: uid(), date: now(), weight: 30, waist: null, notes: '' }];
  assert.match(weightAdvice(d, ending), /gradual weight loss/);
  assert.match(weightAdvice(d), /few more logged days/);
});
test('malformed calendar dates and future measurements, notes and water are rejected', () => {
  const d = diary();
  for (const date of ['2026-02-31T12:00:00Z', '2026-13-01T12:00:00Z', '2026-01-01T25:00:00Z', '01/01/2026']) assert.throws(() => validateFood({ ...entry().values, date }));
  const future = new Date(Date.now() + 30000).toISOString();
  for (const change of [d => d.water.push({ id: uid(), date: future, amount: 250 }), d => d.measurements.push({ id: uid(), date: future, weight: 65, waist: null, notes: '' }), d => d.notes.push({ id: uid(), date: future, text: '', steps: 0 }), d => { d.profile = false; }]) { const copy = structuredClone(d); change(copy); assert.throws(() => validateBackup(copy)); }
});
test('import normalizes offset timestamps so chronological sorting is consistent', () => {
  const d = diary(); d.entries = [entry('2026-01-01', { date: '2026-01-01T10:00:00+05:30' })];
  const decoded = decodeBackup(JSON.stringify(d));
  assert.equal(decoded.entries[0].values.date, '2026-01-01T04:30:00.000Z');
});
test('daily aggregation handles a large history without counting water-only days as food logs', () => {
  const d = diary();
  d.entries = Array.from({ length: 5000 }, (_, i) => entry(shiftDay(dayKey(), -i % 100)));
  const waterDay = shiftDay(dayKey(), -101); d.water.push({ id: uid(), date: dateForDay(waterDay), amount: 250 });
  const totals = statisticsByDay(d);
  assert.equal(totals.size, 101); assert.equal(totals.get(dayKey()).entryCount, 50); assert.equal(totals.get(dayKey()).calories, 5000);
  assert.equal(totals.get(waterDay).entryCount, 0); assert.equal(totals.get(waterDay).water, 250);
  assert.deepEqual(weekly(d, dayKey(), totals), weekly(d));
});
