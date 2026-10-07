export const MEALS = ['Breakfast', 'Lunch', 'Dinner', 'Snacks'];
export const CATEGORIES = ['Other', 'Fruit', 'Vegetable', 'Protein', 'Grain', 'Dairy', 'Drink'];
export const ACTIVITIES = { Sedentary: 1.2, 'Lightly active': 1.375, 'Moderately active': 1.55, 'Very active': 1.725 };
export const defaultProfile = { name: '', age: 22, sex: 'Male', height: 175, weight: 65, targetWeight: 62, waist: 82, activity: 'Lightly active', goal: 'Lose fat', weeklyChange: 0.25, calories: 1900, protein: 120, carbs: 220, fat: 65, water: 2500 };
export const uid = () => crypto.randomUUID();
export const now = () => new Date().toISOString();
export function toDisplay(value, unit) { return unit === 'lb' ? value * 2.2046226218 : unit === 'in' ? value / 2.54 : value; }
export function toMetric(value, unit) { return Math.round((unit === 'lb' ? value / 2.2046226218 : unit === 'in' ? value * 2.54 : value) * 1000) / 1000; }
export function dayKey(date = new Date()) {
  const d = new Date(date);
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}
export function dateForDay(key) { return new Date(`${key}T12:00:00`).toISOString(); }
export function shiftDay(key, amount) { const d = new Date(`${key}T12:00:00`); d.setDate(d.getDate() + amount); return dayKey(d); }
export function timestampForDay(key) { return key === dayKey() ? now() : dateForDay(key); }
export function suggestion(p) {
  const bmr = 10 * p.weight + 6.25 * p.height - 5 * p.age + (p.sex === 'Male' ? 5 : -161);
  const tdee = bmr * ACTIVITIES[p.activity];
  const requested = Math.max(0, p.weeklyChange) * 7700 / 7;
  const adjustment = p.goal === 'Lose fat' ? -Math.min(requested, tdee * 0.2, 500) : p.goal === 'Gain weight' ? Math.min(requested, 350) : 0;
  const minimum = p.sex === 'Male' ? 1500 : 1200;
  return { bmr, tdee, target: Math.max(minimum, Math.round((tdee + adjustment) / 10) * 10), adjusted: tdee + adjustment < minimum || (p.goal === 'Lose fat' && requested > Math.min(tdee * 0.2, 500)) };
}
function requireThat(condition, message) { if (!condition) throw new Error(message); }
function number(value, min, max) { return typeof value === 'number' && Number.isFinite(value) && value >= min && value <= max; }
function text(value, max = 200) { return typeof value === 'string' && value.trim().length > 0 && value.length <= max; }
function identifier(value) { return typeof value === 'string' && /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(value); }
function date(value, tolerance = 60000) {
  if (typeof value !== 'string') return false;
  const match = /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})$/.exec(value);
  if (!match) return false;
  const [, year, month, day, hour, minute, second] = match.map(Number);
  const check = new Date(0); check.setUTCFullYear(year, month - 1, day);
  return check.getUTCFullYear() === year && check.getUTCMonth() === month - 1 && check.getUTCDate() === day && hour <= 23 && minute <= 59 && second <= 59 && Number.isFinite(Date.parse(value)) && Date.parse(value) <= Date.now() + tolerance;
}
export function validateProfile(p) {
  requireThat(p && text(p.name, 80), 'Please enter your name (up to 80 characters).');
  requireThat(number(p.age, 18, 100) && Number.isInteger(p.age), 'Calorie guidance is for adults aged 18–100.');
  requireThat(['Male', 'Female'].includes(p.sex) && Object.hasOwn(ACTIVITIES, p.activity) && ['Lose fat', 'Maintain weight', 'Gain weight'].includes(p.goal), 'Choose valid profile options.');
  requireThat(number(p.height, 100, 250), 'Height must be between 100 and 250 cm.');
  requireThat(number(p.weight, 30, 350) && number(p.targetWeight, 30, 350), 'Weights must be between 30 and 350 kg.');
  requireThat(number(p.waist, 30, 250), 'Waist must be between 30 and 250 cm.');
  requireThat(number(p.weeklyChange, 0, 1), 'Weekly change must be between 0 and 1 kg.');
  requireThat(number(p.calories, p.sex === 'Male' ? 1500 : 1200, 6000), `Calorie goal must be between ${p.sex === 'Male' ? 1500 : 1200} and 6,000 kcal.`);
  requireThat(number(p.protein, 1, 500) && number(p.carbs, 1, 1000) && number(p.fat, 1, 300), 'Enter positive macro goals within the displayed ranges.');
  requireThat(number(p.water, 500, 6000), 'Water goal must be between 500 and 6,000 ml.');
  return p;
}
export function validateFood(f) {
  requireThat(f && text(f.name) && text(f.serving), 'Enter a food name and serving description.');
  requireThat(number(f.quantity, 0.01, 100), 'Quantity must be between 0.01 and 100 servings.');
  requireThat(number(f.calories, 0, 10000) && number(f.protein, 0, 1000) && number(f.carbs, 0, 2000) && number(f.fat, 0, 1000), 'Enter valid, nonnegative nutrition values.');
  requireThat(MEALS.includes(f.meal) && CATEGORIES.includes(f.category), 'Choose a valid meal and food category.');
  requireThat(date(f.date), 'Food can only be logged for today or earlier.');
  return f;
}
const reminders = ['breakfast', 'lunch', 'dinner', 'water', 'weight', 'review'];
export function emptyDiary() {
  const createdAt = now();
  const samples = [
    ['Milk Rice', '2 pieces', 400, 8, 55, 16, 'Grain'], ['Plain Tea', '1 cup', 2, 0, 0.5, 0, 'Drink'],
    ['Full Cream Milk', '170 ml', 110, 5.7, 8.2, 6, 'Dairy'], ['Boiled Egg', '1 egg', 75, 6.3, 0.6, 5.3, 'Protein'],
    ['Chicken Breast', '100 g cooked', 165, 31, 0, 3.6, 'Protein'], ['Cooked White Rice', '1 cup', 200, 4.3, 44.5, 0.4, 'Grain'],
    ['Dhal', '1 serving', 150, 9, 22, 3, 'Protein'], ['Fish', '100 g cooked', 140, 24, 0, 5, 'Protein'],
    ['Banana', '1 medium', 100, 1.3, 26, 0.3, 'Fruit'], ['Apple', '1 medium', 95, 0.5, 25, 0.3, 'Fruit'],
    ['Plain Yogurt', '150 g', 95, 8, 10, 3, 'Dairy'], ['Bread', '1 slice', 80, 3, 15, 1, 'Grain'],
    ['Roti', '1 medium', 150, 4, 26, 4, 'Grain'], ['String Hoppers', '5 small', 180, 3, 40, 0.5, 'Grain']
  ];
  return { version: 1, exportedAt: createdAt, profile: null, entries: [], meals: [], measurements: [], water: [], notes: [],
    foods: samples.map(([name, serving, calories, protein, carbs, fat, category]) => ({ id: uid(), createdAt, favorite: false, sample: true, lastUsedAt: null, values: { id: uid(), name, serving, calories, protein, carbs, fat, category, quantity: 1, meal: 'Breakfast', date: createdAt } })),
    settings: { weightUnit: 'kg', lengthUnit: 'cm', theme: 'Dark', reminders: reminders.map((id, i) => ({ id, title: id, body: '', enabled: false, hour: [8, 13, 19, 15, 7, 21][i], minute: 0 })) }
  };
}
export function emptyStatistics() { return { calories: 0, protein: 0, carbs: 0, fat: 0, water: 0, entryCount: 0, produceCount: 0, meals: Object.fromEntries(MEALS.map(m => [m, 0])) }; }
export function statisticsByDay(data) {
  const days = new Map();
  const get = key => { if (!days.has(key)) days.set(key, emptyStatistics()); return days.get(key); };
  for (const { values: f } of data.entries) {
    const totals = get(dayKey(f.date));
    totals.entryCount++;
    for (const field of ['calories', 'protein', 'carbs', 'fat']) totals[field] += f[field] * f.quantity;
    totals.meals[f.meal] += f.calories * f.quantity;
    if (['Fruit', 'Vegetable'].includes(f.category)) totals.produceCount++;
  }
  for (const w of data.water) get(dayKey(w.date)).water += w.amount;
  return days;
}
export function stats(data, key) {
  return statisticsByDay(data).get(key) || emptyStatistics();
}
export function streak(data, today = dayKey()) {
  const days = new Set(data.entries.map(e => dayKey(e.values.date)));
  let cursor = days.has(today) ? today : shiftDay(today, -1), count = 0;
  while (days.has(cursor)) { count++; cursor = shiftDay(cursor, -1); }
  return count;
}
export function weekly(data, ending = dayKey(), totals = statisticsByDay(data)) {
  const days = Array.from({ length: 7 }, (_, i) => ({ key: shiftDay(ending, i - 6), ...(totals.get(shiftDay(ending, i - 6)) || emptyStatistics()) }));
  const logged = days.filter(d => d.entryCount);
  return { days, logged: logged.length, averageCalories: logged.length ? logged.reduce((s, d) => s + d.calories, 0) / logged.length : 0, averageProtein: logged.length ? logged.reduce((s, d) => s + d.protein, 0) / logged.length : 0 };
}
export function review(s, goals, complete) {
  if (!s.entryCount) return { score: null, rating: 'A fresh start', messages: ['Log a meal to start your daily reflection. An empty diary is not a completed day.'] };
  const ratio = s.calories / goals.calories;
  const value = Math.max(0, 1 - Math.abs(ratio - 1) / 0.5) * 4 + Math.min(1, s.protein / goals.protein) * 2 + Math.min(1, s.water / goals.water) * 1.5 + Math.min(1, s.produceCount / 3) * 1.5 + Math.min(1, Object.values(s.meals).filter(c => c > 0).length / 3);
  return { score: Math.round(Math.min(10, value) * 10) / 10, rating: value >= 8 ? 'Excellent' : value >= 6 ? 'Good' : value >= 4 ? 'Fair' : 'Keep building', messages: [
    ...(!complete ? ['Today’s reflection is provisional. Keep logging as your day continues.'] : []),
    ratio < 0.75 ? (complete ? 'Your logged intake is well below your goal. Check for missing entries and aim for enough food to support your day.' : 'There’s room for more meals as your day continues.') : ratio <= 1.05 ? 'Your calories are close to your goal. Sustainable consistency matters more than exact numbers.' : 'You logged above your calorie goal. One day is part of a longer trend; continue your usual routine tomorrow.',
    s.protein >= goals.protein ? 'You reached your protein goal.' : 'A protein source with your next meal can help you reach your goal.',
    s.water >= goals.water ? 'You reached your water logging goal.' : `${Math.round(goals.water - s.water)} ml left toward your water goal. Spread drinking comfortably through the day.`,
    ...(s.produceCount < 3 ? ['Consider adding fruit or vegetables to a meal. Choose their category when logging.'] : ['You made room for fruit and vegetables.'])
  ] };
}
export function validateBackup(data) {
  requireThat(data && data.version === 1, 'This backup version is not supported.');
  requireThat(date(data.exportedAt), 'Invalid backup export date.');
  requireThat(data.profile == null || (typeof data.profile === 'object' && !Array.isArray(data.profile)), 'Invalid profile record.');
  if (data.profile) { requireThat(identifier(data.profile.id) && date(data.profile.createdAt), 'Invalid profile record.'); validateProfile(data.profile.values); }
  const limits = { foods: 10000, entries: 100000, meals: 5000, measurements: 50000, water: 100000, notes: 50000 };
  const ids = new Set();
  const unique = id => { requireThat(identifier(id) && !ids.has(id), 'The backup contains invalid or duplicate record identifiers.'); ids.add(id); };
  for (const [key, limit] of Object.entries(limits)) {
    requireThat(Array.isArray(data[key]) && data[key].length <= limit, `Invalid or too many ${key} records.`);
    data[key].forEach(r => { requireThat(r && typeof r === 'object', `Invalid ${key} record.`); unique(r.id); });
  }
  for (const item of [...data.entries, ...data.foods]) { validateFood(item.values); requireThat(identifier(item.values.id) && date(item.createdAt), 'Invalid food record.'); }
  for (const item of data.foods) requireThat(typeof item.favorite === 'boolean' && typeof item.sample === 'boolean' && (item.lastUsedAt == null || date(item.lastUsedAt)), 'Invalid library food.');
  for (const item of data.meals) {
    requireThat(text(item.name) && date(item.createdAt) && Array.isArray(item.foods) && item.foods.length > 0 && item.foods.length <= 200, 'Invalid saved meal.');
    item.foods.forEach(f => { unique(f.id); validateFood(f); });
  }
  for (const m of data.measurements) requireThat(date(m.date, 0) && (m.weight != null || m.waist != null) && (m.weight == null || number(m.weight, 30, 350)) && (m.waist == null || number(m.waist, 30, 250)) && typeof m.notes === 'string', 'Invalid measurement.');
  for (const w of data.water) requireThat(date(w.date, 0) && number(w.amount, 1, 3000), 'Invalid water record.');
  for (const n of data.notes) requireThat(date(n.date, 0) && typeof n.text === 'string' && n.text.length <= 10000 && number(n.steps, 0, 100000) && Number.isInteger(n.steps), 'Invalid note or step count.');
  const s = data.settings;
  requireThat(s && ['kg', 'lb'].includes(s.weightUnit) && ['cm', 'in'].includes(s.lengthUnit) && ['System', 'Light', 'Dark'].includes(s.theme), 'Invalid display settings.');
  requireThat(Array.isArray(s.reminders) && s.reminders.length === 6 && new Set(s.reminders.map(r => r.id)).size === 6 && s.reminders.every(r => reminders.includes(r.id) && Number.isInteger(r.hour) && number(r.hour, 0, 23) && Number.isInteger(r.minute) && number(r.minute, 0, 59) && typeof r.enabled === 'boolean' && typeof r.title === 'string' && typeof r.body === 'string'), 'Invalid reminder preferences.');
  return data;
}
export function decodeBackup(raw) {
  requireThat(new TextEncoder().encode(raw).length <= 25000000, 'This backup is too large (maximum 25 MB).');
  let data;
  try { data = JSON.parse(raw); } catch { throw new Error('This file is not a valid JSON backup.'); }
  validateBackup(data);
  const normalize = record => { for (const key of ['createdAt', 'date', 'lastUsedAt']) if (record[key] != null) record[key] = new Date(record[key]).toISOString(); };
  data.exportedAt = new Date(data.exportedAt).toISOString();
  if (data.profile) normalize(data.profile);
  for (const collection of ['entries', 'foods', 'meals', 'measurements', 'water', 'notes']) data[collection].forEach(record => { normalize(record); if (record.values) normalize(record.values); if (record.foods) record.foods.forEach(normalize); });
  data.settings.reminders.forEach(r => { r.enabled = false; });
  return Object.fromEntries(['version', 'exportedAt', 'profile', 'entries', 'foods', 'meals', 'measurements', 'water', 'notes', 'settings'].map(key => [key, data[key]]));
}
export function encodeBackup(data) {
  validateBackup(data);
  // Swift JSONDecoder's ISO8601 strategy expects whole-second timestamps.
  return JSON.stringify(data, (key, value) => {
    if (key === 'webRevision' || key === 'webAppearanceVersion') return undefined;
    if (['date', 'createdAt', 'exportedAt', 'lastUsedAt'].includes(key) && typeof value === 'string') return new Date(value).toISOString().replace(/\.\d{3}Z$/, 'Z');
    return value;
  }, 2);
}
export function weightAdvice(data, ending = dayKey()) {
  const week = weekly(data, ending);
  if (week.logged < 4) return 'A few more logged days will make your averages more useful. Missing days are excluded, rather than counted as zero intake.';
  const measurements = data.measurements.filter(m => m.weight != null && dayKey(m.date) >= shiftDay(ending, -28) && dayKey(m.date) <= ending).sort((a, b) => a.date.localeCompare(b.date));
  if (measurements.length < 2) return 'Add regular measurements to see your longer-term weight trend.';
  const first = measurements[0], last = measurements.at(-1);
  const days = Math.round((Date.parse(`${dayKey(last.date)}T12:00:00Z`) - Date.parse(`${dayKey(first.date)}T12:00:00Z`)) / 86400000);
  if (days < 6) return 'More time between measurements is needed to assess your trend.';
  const change = (last.weight - first.weight) / days * 7;
  if (data.profile.values.goal === 'Lose fat' && change < -first.weight * 0.01) return 'Your recorded weight is dropping quickly. Consider increasing intake and discussing your goal with a qualified professional. Short-term changes can reflect water weight.';
  if (data.profile.values.goal === 'Lose fat' && days >= 21 && change > -0.1) return 'Your recorded weight has been fairly stable. Check logging completeness before considering a small goal adjustment. Keep your intake adequate.';
  if (data.profile.values.goal === 'Lose fat' && change < -0.1) return 'Your recorded trend is consistent with gradual weight loss. Watch the longer-term trend.';
  return 'Keep a consistent routine. Weight naturally fluctuates from day to day.';
}
