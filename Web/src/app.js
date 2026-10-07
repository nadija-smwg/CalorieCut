import './style.css';
import { MEALS, CATEGORIES, ACTIVITIES, defaultProfile, uid, now, dayKey, shiftDay, timestampForDay, suggestion, validateProfile, validateFood, emptyDiary, streak, weekly, review, validateBackup, decodeBackup, encodeBackup, weightAdvice, toDisplay, toMetric, statisticsByDay, emptyStatistics } from './core.js';
import { loadDiary, saveDiary } from './db.js';

const app = document.querySelector('#app'), modal = document.querySelector('#modal');
let data, view = 'home', selectedDay = dayKey(), period = '30', metric = 'weight', installPrompt, pendingImport, activeEntry, libraryTab = 'all', savedFocus;
let busy = false, dayTotals = new Map();
const dayStats = key => dayTotals.get(key) || emptyStatistics();
const icons = {
  leaf: '<path d="M19 4C7 3 3 9 6 16c3 6 12 4 14-3 1-4 0-7-1-9Z"/><path d="m5 21 10-11"/>',
  home: '<path d="m3 10 9-7 9 7v10H3Z"/><path d="M9 20v-7h6v7"/>',
  diary: '<rect x="4" y="3" width="16" height="18" rx="3"/><path d="M8 3v18m4-12h4m-4 4h4"/>',
  progress: '<path d="M4 4v16h17M7 15l4-5 4 2 5-7"/>',
  review: '<path d="M7 3h10l3 4v14H4V7Z"/><path d="m8 12 3 3 5-6"/>',
  settings: '<path d="M4 7h16M4 17h16"/><circle cx="9" cy="7" r="3"/><circle cx="16" cy="17" r="3"/>',
  plus: '<path d="M12 5v14M5 12h14"/>',
  arrow: '<path d="M5 12h14m-5-5 5 5-5 5"/>',
  chevron: '<path d="m9 5 7 7-7 7"/>',
  close: '<path d="m6 6 12 12M6 18 18 6"/>',
  water: '<path d="M12 3C9 7 5 11 5 15a7 7 0 0 0 14 0c0-4-4-8-7-12Z"/>',
  sun: '<circle cx="12" cy="12" r="4"/><path d="M12 2v2m0 16v2M2 12h2m16 0h2M5 5l1 1m12 12 1 1M5 19l1-1M18 6l1-1"/>',
  moon: '<path d="M20 15A9 9 0 0 1 9 4a9 9 0 1 0 11 11Z"/>',
  snack: '<path d="m6 18 3-11 8 8-11 3Zm7-12 2-3m2 7 4-1m-7-2 5-4"/>',
  fire: '<path d="M12 3c2 5-3 7-2 11 3 0 4-2 5-4 7 10-1 14-6 10-4-3-4-8 3-17Z"/>',
  check: '<path d="m5 12 4 4L19 6"/>',
  download: '<path d="M12 3v12m-5-5 5 5 5-5M4 16v5h16v-5"/>',
  upload: '<path d="M12 16V4m-5 5 5-5 5 5M4 16v5h16v-5"/>',
  edit: '<path d="m4 16 12-12 4 4L8 20H4Zm9-9 4 4"/>',
  star: '<path d="m12 3 3 6 7 1-5 5 1 7-6-3-6 3 1-7-5-5 7-1Z"/>',
  shield: '<path d="m12 3 8 3v6c0 5-8 9-8 9s-8-4-8-9V6Z"/><path d="m8 12 3 3 5-6"/>',
  wifi: '<path d="M3 8a14 14 0 0 1 18 0M6 12a9 9 0 0 1 12 0m-9 4a4 4 0 0 1 6 0"/><circle cx="12" cy="20" r="1"/>',
  search: '<circle cx="10" cy="10" r="6"/><path d="m15 15 5 5"/>'
};
const icon = (name, extra = '') => `<svg ${extra} viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${icons[name] || icons.leaf}</svg>`;
const escape = value => String(value ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const fmt = (n, decimals = 0) => Number(n).toLocaleString(undefined, { maximumFractionDigits: decimals });
const fullDate = key => new Date(`${key}T12:00:00`).toLocaleDateString(undefined, { weekday: 'long', month: 'long', day: 'numeric' });
const shortDate = key => new Date(`${key}T12:00:00`).toLocaleDateString(undefined, { month: 'short', day: 'numeric' });
const profile = () => data.profile.values;
const weight = n => toDisplay(n, data.settings.weightUnit);
const length = n => toDisplay(n, data.settings.lengthUnit);
const unitWeight = () => data.settings.weightUnit, unitLength = () => data.settings.lengthUnit;
const button = (action, label, cls = 'button', extra = '') => `<button type="button" class="${cls}" data-action="${action}" ${extra}>${label}</button>`;
const empty = (title, text, action = '', label = '') => `<div class="empty-state"><span class="empty-icon">${icon('leaf')}</span><h3>${title}</h3><p>${text}</p>${action ? button(action, label, 'button secondary') : ''}</div>`;
function toast(message) { const el = document.querySelector('#toast'); el.textContent = message; el.classList.add('show'); clearTimeout(toast.timer); toast.timer = setTimeout(() => el.classList.remove('show'), 4500); }
function showDialog(title, body, wide = false) {
  savedFocus = document.activeElement;
  modal.className = wide ? 'wide' : '';
  modal.innerHTML = `<div class="modal-header"><h2 id="modal-title">${title}</h2>${button('close', icon('close'), 'icon-button', 'aria-label="Close dialog"')}</div>${body}<p id="form-error" class="error" role="alert"></p>`;
  if (!modal.open) modal.showModal();
}
modal.addEventListener('close', () => { if (savedFocus?.isConnected) savedFocus.focus(); });
function error(message) { const el = modal.open && document.querySelector('#form-error'); if (el) el.textContent = message; else toast(message); }
async function commit(change, message) {
  if (busy) return false;
  busy = true;
  app.setAttribute('aria-busy', 'true');
  modal.setAttribute('aria-busy', 'true');
  const controls = [...document.querySelectorAll('button, input, select, textarea')].filter(control => !control.disabled);
  controls.forEach(control => { control.disabled = true; });
  try {
    const next = structuredClone(data);
    change(next);
    next.exportedAt = now();
    validateBackup(next);
    await saveDiary(next, data.webRevision || 0);
    data = next;
    render();
    if (message) toast(message);
    return true;
  } catch (e) { error(e.message); return false; } finally { busy = false; controls.forEach(control => { control.disabled = false; }); app.removeAttribute('aria-busy'); modal.removeAttribute('aria-busy'); }
}
function theme() {
  const dark = data.settings.theme === 'Dark' || (data.settings.theme === 'System' && matchMedia('(prefers-color-scheme: dark)').matches);
  document.documentElement.dataset.theme = dark ? 'dark' : 'light';
  document.querySelector('meta[name="theme-color"]').content = dark ? '#000000' : '#f6f7f2';
}
function render() {
  theme();
  if (!data.profile) { renderWelcome(); return; }
  dayTotals = statisticsByDay(data);
  const tabs = [['home', 'Overview'], ['diary', 'Diary'], ['progress', 'Progress'], ['review', 'Reflection'], ['settings', 'Settings']];
  const titles = { home: 'Your daily balance', diary: 'One meal at a time', progress: 'The bigger picture', review: 'A moment to reflect', settings: 'Make it yours' };
  app.innerHTML = `<aside class="sidebar"><a class="brand" href="#home">${icon('leaf')}<span>CalorieCut<span class="brand-dot">.</span></span></a><p class="sidebar-label">YOUR EVERYDAY COMPANION</p><nav aria-label="Main navigation">${tabs.map(([key, title]) => `<button data-action="nav" data-view="${key}" class="nav-item ${view === key ? 'active' : ''}" ${view === key ? 'aria-current="page"' : ''}>${icon(key)}<span>${title}</span></button>`).join('')}</nav><div class="sidebar-bottom"><div class="private-badge">${icon('shield')}<span>Just you & your journey.<small>Stored privately on this device.</small></span></div><div class="profile-badge"><span class="avatar">${escape(profile().name.trim()[0].toUpperCase())}</span><span>${escape(profile().name)}<small>${escape(profile().goal)}</small></span>${button('profile', icon('edit'), 'icon-button', 'aria-label="Edit profile"')}</div></div></aside>
  <main><header class="topbar"><div class="mobile-brand">${icon('leaf')} CalorieCut<span>.</span></div><div class="breadcrumb">MY SPACE <span>/</span> ${tabs.find(t => t[0] === view)[1].toUpperCase()}</div><span class="connection">${icon(navigator.onLine ? 'wifi' : 'shield')}<span>${navigator.onLine ? 'On your device' : 'Offline · still saving'}</span></span></header><div class="page"><div class="page-heading"><div><p class="eyebrow">${view === 'home' ? `HELLO, ${escape(profile().name.toUpperCase())}` : 'A LITTLE MORE MINDFUL, EVERY DAY'}</p><h1>${titles[view]}<span>.</span></h1><p class="subtitle">${({ home: 'Small steps. Real progress. A day that feels good.', diary: 'A simple record of what nourishes you.', progress: 'Look for patterns, not perfection.', review: 'Build a routine that works for you.', settings: 'Your goals, your preferences, your data.' })[view]}</p></div>${['home', 'diary', 'review'].includes(view) ? dateControl() : ''}</div>${({ home: homeView, diary: diaryView, progress: progressView, review: reviewView, settings: settingsView })[view]() }<footer class="page-footer">Made for your everyday. <span>CalorieCut ${icon('leaf')}</span></footer></div></main><nav class="mobile-nav" aria-label="Mobile navigation">${tabs.map(([key, title]) => `<button data-action="nav" data-view="${key}" class="${view === key ? 'active' : ''}" ${view === key ? 'aria-current="page"' : ''}>${icon(key)}<span>${title}</span></button>`).join('')}</nav>`;
}
function dateControl() {
  return `<div class="date-control">${button('prev-day', icon('chevron'), 'icon-button previous', 'aria-label="Previous day"')}<label><span>${selectedDay === dayKey() ? 'Today' : shortDate(selectedDay)}</span><input aria-label="Diary date" type="date" id="day" value="${selectedDay}" max="${dayKey()}" /></label>${button('next-day', icon('chevron'), 'icon-button', `aria-label="Next day" ${selectedDay === dayKey() ? 'disabled' : ''}`)}</div>`;
}
function renderWelcome() {
  app.innerHTML = `<div class="welcome"><a class="brand" href="#">${icon('leaf')}<span>CalorieCut<span class="brand-dot">.</span></span></a><div class="welcome-layout"><div><span class="pill">YOUR EVERYDAY, A LITTLE LIGHTER</span><h1>Find your<br>daily <em>balance.</em></h1><p>A food diary that makes space for real life.<br>Simple tracking. Gentle guidance. All yours.</p><button class="button" data-action="profile">Let’s get started ${icon('arrow')}</button><button class="text-button" data-action="import">Restore a backup</button><div class="welcome-benefits"><span>${icon('shield')} No accounts or ads</span><span>${icon('wifi')} Works offline</span></div><p class="fine-print">Install on iPhone or Android. Your diary stays on this device.<br>Calorie guidance is designed for adults aged 18 and over.</p></div><div class="welcome-art" aria-hidden="true"><span class="art-label">A HEALTHIER RELATIONSHIP WITH YOUR EVERYDAY</span><div class="art-circle"><span>${icon('leaf')}</span><p>Nourish.<br>Notice.<br>Grow.</p></div><div class="art-tag">A little consistency goes a long way ${icon('check')}</div><div class="art-dot one"></div><div class="art-dot two"></div></div></div></div>`;
}
function macros(s) {
  return `<div class="macro-grid">${[['protein', 'Protein', 'protein'], ['carbs', 'Carbs', 'carbs'], ['fat', 'Fat', 'fat']].map(([key, label, cls]) => `<div class="macro"><div><i class="${cls}"></i>${label}<span>${fmt(profile()[key])} g goal</span></div><p><strong>${fmt(s[key], 1)}</strong><small> g</small></p><div class="meter ${cls}"><span style="width:${Math.min(100, s[key] / profile()[key] * 100)}%"></span></div></div>`).join('')}</div>`;
}
function mealRows(meal, compact = false) {
  const entries = data.entries.filter(e => dayKey(e.values.date) === selectedDay && e.values.meal === meal);
  const total = entries.reduce((s, e) => s + e.values.calories * e.values.quantity, 0);
  const mealIcon = { Breakfast: 'sun', Lunch: 'sun', Dinner: 'moon', Snacks: 'snack' }[meal];
  return `<section class="meal-section"><div class="meal-heading"><span class="meal-symbol ${meal.toLowerCase()}">${icon(mealIcon)}</span><h3>${meal}<small>${entries.length ? `${fmt(total)} kcal` : 'Nothing logged yet'}</small></h3>${entries.length && !compact ? button('save-meal', 'Save as meal', 'text-button', `data-meal="${meal}"`) : ''}${button('add', icon('plus'), 'icon-button add-circle', `data-meal="${meal}" aria-label="Add food to ${meal}"`)}</div>${entries.map(e => `<button class="food-row" data-action="edit-entry" data-id="${e.id}"><span class="food-dot ${e.values.category.toLowerCase()}">${icon(e.values.category === 'Drink' ? 'water' : 'leaf')}</span><span>${escape(e.values.name)}<small>${fmt(e.values.quantity, 2)} × ${escape(e.values.serving)}${!compact ? ` · P ${fmt(e.values.protein * e.values.quantity, 1)} · C ${fmt(e.values.carbs * e.values.quantity, 1)} · F ${fmt(e.values.fat * e.values.quantity, 1)} g` : ''}</small></span><strong>${fmt(e.values.calories * e.values.quantity)}<small>kcal</small></strong>${icon('chevron')}</button>`).join('')}</section>`;
}
function homeView() {
  const s = dayStats(selectedDay), remaining = profile().calories - s.calories;
  const percent = Math.min(100, s.calories / profile().calories * 100);
  const recent = [...data.measurements].filter(m => m.weight != null).sort((a, b) => b.date.localeCompare(a.date))[0];
  return `<div class="overview-grid"><section class="card energy-card"><div class="card-heading"><h2>Daily energy</h2><span class="pill subtle">${s.entryCount ? 'YOUR DAY SO FAR' : 'A FRESH START'}</span></div><div class="energy-content"><div class="energy-ring" style="--progress:${percent}%" role="img" aria-label="${fmt(s.calories)} of ${fmt(profile().calories)} calories"><div><span>${remaining >= 0 ? 'REMAINING' : 'ABOVE GOAL'}</span><strong>${fmt(Math.abs(remaining))}</strong><small>kcal</small></div></div><div class="energy-detail"><div><i class="dot green"></i><span>Consumed</span><strong>${fmt(s.calories)} <small>kcal</small></strong></div><div><i class="dot gray"></i><span>Daily goal</span><strong>${fmt(profile().calories)} <small>kcal</small></strong></div><p>Your goal is a guide.<br>Every day doesn’t have to be perfect.</p></div></div>${macros(s)}</section><section class="card water-card"><div class="card-heading"><h2>Stay hydrated</h2>${icon('water')}</div><p class="water-value">${fmt(s.water / 1000, 2)} <small>/ ${fmt(profile().water / 1000, 2)} L</small></p><p class="muted">A little sip, a little reset.</p><div class="water-glasses" aria-hidden="true">${Array.from({ length: 8 }, (_, i) => `<span class="${s.water / profile().water * 8 > i ? 'filled' : ''}">${icon('water')}</span>`).join('')}</div><div class="water-actions">${button('water', `${icon('plus')} 250 ml`, 'button', 'data-amount="250"')}${button('water', '+ 500', 'button secondary', 'data-amount="500"')}${button('water-custom', icon('plus'), 'icon-button', 'aria-label="Custom water amount"')}</div>${button('water-history', 'View water logs', 'text-button')}</section></div><div class="quick-stats"><section class="mini-card"><span class="stat-icon">${icon('fire')}</span><div><p>Logging streak</p><strong>${streak(data)} <small>day${streak(data) === 1 ? '' : 's'}</small></strong></div><span class="mini-note">Keep showing up.</span></section><section class="mini-card"><span class="stat-icon">${icon('progress')}</span><div><p>Latest weight</p><strong>${recent ? fmt(weight(recent.weight), 1) : '—'} <small>${unitWeight()}</small></strong></div>${button('measurement', icon('plus'), 'icon-button', 'aria-label="Add measurement"')}</section><section class="mini-card goal-mini"><div><p>A reminder for today</p><strong>Progress, at your pace.</strong></div>${icon('leaf')}</section></div><div class="section-heading"><div><p class="eyebrow">THE GOOD STUFF</p><h2>On the menu</h2></div>${button('nav', `Open diary ${icon('arrow')}`, 'text-button', 'data-view="diary"')}</div><div class="card meal-card">${MEALS.map(m => mealRows(m, true)).join('')}</div>`;
}
function calendar() {
  const current = new Date(`${selectedDay}T12:00:00`), year = current.getFullYear(), month = current.getMonth();
  const count = new Date(year, month + 1, 0).getDate(), offset = new Date(year, month, 1).getDay();
  return `<section class="card calendar-card"><div class="card-heading"><h2>${current.toLocaleDateString(undefined, { month: 'long', year: 'numeric' })}</h2><div>${button('prev-month', '‹', 'icon-button', 'aria-label="Previous month"')}${button('next-month', '›', 'icon-button', `aria-label="Next month" ${month === new Date().getMonth() && year === new Date().getFullYear() ? 'disabled' : ''}`)}</div></div><div class="calendar-grid">${['S', 'M', 'T', 'W', 'T', 'F', 'S'].map(d => `<span class="calendar-weekday">${d}</span>`).join('')}${'<span></span>'.repeat(offset)}${Array.from({ length: count }, (_, i) => { const key = dayKey(new Date(year, month, i + 1)); const s = dayStats(key); const color = !s.entryCount ? 'none' : Math.abs(s.calories - profile().calories) <= profile().calories * 0.1 ? 'balanced' : s.calories <= profile().calories * 1.25 ? 'logged' : 'above'; return `<button class="calendar-day ${key === selectedDay ? 'selected' : ''}" data-action="select-day" data-day="${key}" aria-label="${fullDate(key)}, ${color === 'none' ? 'no food logged' : color}" ${key > dayKey() ? 'disabled' : ''}>${i + 1}<i class="${color}"></i></button>`; }).join('')}</div><p class="calendar-legend"><span><i class="balanced"></i>Within 10%</span><span><i class="logged"></i>Logged</span><span><i class="above"></i>Over 125%</span></p><p class="fine-print">Compared with your current calorie goal.</p></section>`;
}
function diaryView() {
  const s = dayStats(selectedDay), note = data.notes.find(n => dayKey(n.date) === selectedDay);
  return `<div class="diary-layout"><div><div class="card diary-summary"><span>${fullDate(selectedDay)}</span><strong>${fmt(s.calories)} <small>/ ${fmt(profile().calories)} kcal</small></strong></div><div class="card meal-card">${MEALS.map(m => mealRows(m)).join('')}</div><section class="card notes-card"><div class="card-heading"><h2>Little notes</h2>${icon('diary')}</div><form id="notes-form"><label>How did your day feel?<textarea name="text" rows="3" maxlength="10000" placeholder="Energy, mood, a small win…">${escape(note?.text || '')}</textarea></label><div class="notes-bottom"><label>Steps (optional)<input name="steps" type="number" min="0" max="100000" step="1" value="${note?.steps || 0}" /></label><button class="button secondary" type="submit">Save notes</button></div></form></section></div><aside>${calendar()}<section class="card little-card"><h3>Your personal food shelf</h3><p>Find your favorites, make a meal, and keep everyday logging easy.</p>${button('library', `Open food library ${icon('arrow')}`, 'text-button')}</section><section class="card little-card"><h3>Keep your water in view</h3><p>${fmt(s.water)} / ${fmt(profile().water)} ml logged</p>${button('water-history', 'Manage water logs', 'text-button')}${button('water-custom', '+ Add water', 'text-button')}</section></aside></div>`;
}
function chart(points, label, unit) {
  if (!points.length) return empty('Your story starts here', `Add ${label.toLowerCase()} records to see your trend.`);
  const values = points.map(p => p.value), min = Math.min(...values), max = Math.max(...values), padding = Math.max((max - min) * 0.2, 1), low = min - padding, high = max + padding;
  const firstDay = Date.parse(`${points[0].key}T12:00:00Z`), lastDay = Date.parse(`${points.at(-1).key}T12:00:00Z`);
  const positions = points.map(p => [50 + (firstDay === lastDay ? 270 : (Date.parse(`${p.key}T12:00:00Z`) - firstDay) / (lastDay - firstDay) * 540), 180 - (p.value - low) / (high - low) * 145]);
  return `<div class="chart"><svg viewBox="0 0 640 225" role="img" aria-label="${escape(label)} chart with ${points.length} records; ${fmt(min, 1)} to ${fmt(max, 1)} ${unit}">${[0, 1, 2].map(i => { const y = 35 + i * 72.5; return `<line x1="50" x2="600" y1="${y}" y2="${y}" class="chart-grid"/><text x="5" y="${y + 4}">${fmt(high - i * (high - low) / 2, 1)}</text>`; }).join('')}<path d="M${positions.map(p => p.join(',')).join(' L')}" class="chart-line"/>${positions.map(([x, y]) => `<circle cx="${x}" cy="${y}" r="4" class="chart-point"/>`).join('')}<text x="50" y="215">${shortDate(points[0].key)}</text><text x="590" y="215" text-anchor="end">${shortDate(points.at(-1).key)}</text></svg></div><details class="chart-data"><summary>View ${label.toLowerCase()} data</summary><table><thead><tr><th>Date</th><th>${label} (${unit})</th></tr></thead><tbody>${points.map(p => `<tr><td>${shortDate(p.key)}</td><td>${fmt(p.value, 1)}</td></tr>`).join('')}</tbody></table></details>`;
}
function progressView() {
  const cutoff = period === 'all' ? '0000-01-01' : shiftDay(dayKey(), -Number(period) + 1);
  const measurements = data.measurements.filter(m => dayKey(m.date) >= cutoff).sort((a, b) => a.date.localeCompare(b.date));
  const keys = [...new Set(data.entries.map(e => dayKey(e.values.date)))].filter(d => d >= cutoff).sort();
  const points = ['weight', 'waist'].includes(metric) ? measurements.filter(m => m[metric] != null).map(m => ({ key: dayKey(m.date), value: metric === 'weight' ? weight(m.weight) : length(m.waist) })) : keys.map(key => ({ key, value: dayStats(key)[metric] }));
  const names = { weight: 'Weight', waist: 'Waist', calories: 'Calories', protein: 'Protein' }, units = { weight: unitWeight(), waist: unitLength(), calories: 'kcal', protein: 'g' };
  const weights = measurements.filter(m => m.weight != null);
  const latest = weights.at(-1), first = weights[0];
  return `<div class="progress-top"><div class="mini-card"><div><p>Latest weight</p><strong>${latest ? fmt(weight(latest.weight), 1) : '—'} <small>${unitWeight()}</small></strong></div></div><div class="mini-card"><div><p>Change in this period</p><strong>${weights.length > 1 ? `${latest.weight - first.weight > 0 ? '+' : ''}${fmt(weight(latest.weight - first.weight), 1)}` : '—'} <small>${unitWeight()}</small></strong></div></div><div class="mini-card"><div><p>Your target weight</p><strong>${fmt(weight(profile().targetWeight), 1)} <small>${unitWeight()}</small></strong></div></div></div><section class="card trend-card"><div class="card-heading"><div><h2>See your rhythm</h2><p class="muted">Small changes add up over time.</p></div>${button('measurement', `${icon('plus')} Add measurement`, 'button')}</div><div class="chart-controls"><div class="segmented">${Object.entries(names).map(([key, name]) => button('metric', name, metric === key ? 'selected' : '', `data-metric="${key}" aria-pressed="${metric === key}"`)).join('')}</div><select id="period" aria-label="Chart date range">${[['7', '7 days'], ['30', '30 days'], ['90', '3 months'], ['all', 'All time']].map(([key, text]) => `<option value="${key}" ${period === key ? 'selected' : ''}>${text}</option>`).join('')}</select></div>${chart(points, names[metric], units[metric])}<p class="fine-print">Calorie and protein trends include logged days only. Goals use your current settings.</p></section><section class="card history-card"><div class="card-heading"><h2>Measurement journal</h2><span class="muted">${measurements.length} records</span></div>${measurements.length ? measurements.slice().reverse().map(m => `<button class="measurement-row" data-action="measurement" data-id="${m.id}"><span>${shortDate(dayKey(m.date))}<small>${escape(m.notes || 'A moment to check in')}</small></span><strong>${m.weight != null ? `${fmt(weight(m.weight), 1)} ${unitWeight()}` : '—'} <small>${m.waist != null ? `${fmt(length(m.waist), 1)} ${unitLength()} waist` : ''}</small></strong>${icon('chevron')}</button>`).join('') : empty('Make room for the bigger picture', 'Weight and waist measurements are optional. Record them at your own pace.')}</section>`;
}
function reviewView() {
  const s = dayStats(selectedDay), r = review(s, profile(), selectedDay < dayKey()), w = weekly(data, selectedDay, dayTotals);
  return `<div class="reflection-grid"><section class="card reflection-score"><span class="pill">${selectedDay === dayKey() ? 'A WORK IN PROGRESS' : 'YOUR LOGGED DAY'}</span><div class="score-orbit"><strong>${r.score ?? '—'}<small>/ 10</small></strong></div><h2>${r.rating}</h2><p>A reflection on your logs,<br>not a measure of your worth.</p></section><section class="card reflection-notes"><p class="eyebrow">THINGS TO NOTICE</p><h2>A little perspective</h2>${r.messages.map(m => `<div class="reflection-note">${icon('leaf')}<p>${m}</p></div>`).join('')}</section></div><section class="card weekly-card"><div class="card-heading"><div><p class="eyebrow">CONSISTENCY OVER PERFECTION</p><h2>Your last seven days</h2></div><span class="pill subtle">${w.logged} OF 7 DAYS LOGGED</span></div><div class="week-bars">${w.days.map(d => `<div><div class="week-bar ${!d.entryCount ? 'unlogged' : ''}" style="--height:${d.entryCount ? Math.max(8, Math.min(100, d.calories / Math.max(profile().calories * 1.4, ...w.days.map(x => x.calories)) * 100)) : 0}%"><span>${d.entryCount ? fmt(d.calories) : '—'}</span><i></i></div><small>${new Date(`${d.key}T12:00:00`).toLocaleDateString(undefined, { weekday: 'short' })}</small></div>`).join('')}</div><div class="weekly-averages"><p>Average calories<strong>${w.logged ? fmt(w.averageCalories) : '—'} <small>kcal</small></strong></p><p>Average protein<strong>${w.logged ? fmt(w.averageProtein, 1) : '—'} <small>g</small></strong></p><p>Days within 10% of calorie goal<strong>${w.days.filter(d => d.entryCount && Math.abs(d.calories - profile().calories) <= profile().calories * 0.1).length} <small>/ ${w.logged}</small></strong></p></div><p class="fine-print">Averages exclude days without food entries. An entry does not certify a complete diary.</p></section><section class="card insight"><span class="stat-icon">${icon('progress')}</span><div><h3>Looking ahead</h3><p>${weightAdvice(data, selectedDay)}</p></div></section>`;
}
function settingsView() {
  const p = profile();
  return `<div class="settings-grid"><section class="card"><div class="card-heading"><h2>Your daily intentions</h2>${button('profile', 'Edit goals', 'text-button')}</div><div class="goal-list">${[['Calories', p.calories, 'kcal'], ['Protein', p.protein, 'g'], ['Carbs', p.carbs, 'g'], ['Fat', p.fat, 'g'], ['Water', p.water, 'ml']].map(([name, value, unit]) => `<div><span>${name}</span><strong>${fmt(value)} <small>${unit}</small></strong></div>`).join('')}</div><p class="fine-print">General estimates for adults, not a medical diagnosis. Personal needs vary.</p></section><section class="card"><h2>Your kind of comfortable</h2><form id="settings-form"><label>Appearance<select name="theme" aria-label="Appearance">${['System', 'Light', 'Dark'].map(t => `<option ${data.settings.theme === t ? 'selected' : ''}>${t}</option>`).join('')}</select></label><div class="form-grid"><label>Weight unit<select name="weightUnit" aria-label="Weight unit">${['kg', 'lb'].map(t => `<option ${data.settings.weightUnit === t ? 'selected' : ''}>${t}</option>`).join('')}</select></label><label>Length unit<select name="lengthUnit" aria-label="Length unit">${['cm', 'in'].map(t => `<option ${data.settings.lengthUnit === t ? 'selected' : ''}>${t}</option>`).join('')}</select></label></div><button class="button secondary" type="submit">Save preferences</button></form></section><section class="card"><span class="section-icon">${icon('download')}</span><h2>Your data belongs to you</h2><p class="muted">Your diary is saved on this device, in this browser. Export a backup regularly, especially before clearing browser data or changing phones. Backups contain personal information.</p><div class="button-row">${button('export', `${icon('download')} Export backup`)}${button('import', `${icon('upload')} Import backup`, 'button secondary')}</div><p class="fine-print">Supports CalorieCut native and web JSON backups. Import replaces the current diary.</p><button class="text-button" data-action="storage">Keep storage on this device</button></section><section class="card"><span class="section-icon">${icon('leaf')}</span><h2>A home on your Home Screen</h2><p class="muted">Open CalorieCut like any app. Once it’s loaded, you can log your day without an internet connection.</p>${button('install', `How to install ${icon('arrow')}`, 'button secondary')}<p class="fine-print">Safari on iPhone · Chrome on Android. No account, app-store fee, or signing expiry.</p></section><section class="card"><h2>A gentle nudge</h2><p class="muted">For daily reminders, set a repeating alarm in your phone’s Clock or Calendar app. This version does not send scheduled alerts while closed.</p></section><section class="card danger-card"><h2>Start fresh</h2><p class="muted">Delete your diary, profile, food library, and measurements from this device. Export a backup first if you want to keep them.</p>${button('reset', 'Delete all data', 'button danger')}</section></div>`;
}
function field(name, label, value, type = 'number', attrs = '') { return `<label>${label}<input name="${name}" type="${type}" value="${escape(value)}" ${attrs} /></label>`; }
function select(name, label, options, value) { return `<label>${label}<select name="${name}" aria-label="${escape(label)}">${options.map(o => `<option value="${escape(o)}" ${o === value ? 'selected' : ''}>${escape(o)}</option>`).join('')}</select></label>`; }
function profileDialog() {
  const p = data.profile?.values || defaultProfile, isNew = !data.profile;
  showDialog(isNew ? 'A plan that feels like you' : 'Your profile & goals', `<p class="muted">${isNew ? 'Start with a few details. You can change everything later.' : 'Profile changes do not replace your measurement history.'}</p><form id="profile-form">${field('name', 'What should we call you?', p.name, 'text', 'required maxlength="80" autocomplete="given-name"')}<p class="form-section">A LITTLE ABOUT YOU</p><div class="form-grid">${field('age', 'Age', p.age, 'number', 'min="18" max="100" required')}${select('sex', 'Sex used in calorie estimate', ['Male', 'Female'], p.sex)}${field('height', `Height (${unitLength()})`, fmtInput(length(p.height)), 'number', 'min="0" step="any" required')}${field('weight', `Current weight (${unitWeight()})`, fmtInput(weight(p.weight)), 'number', 'min="0" step="any" required')}${field('targetWeight', `Target weight (${unitWeight()})`, fmtInput(weight(p.targetWeight)), 'number', 'min="0" step="any" required')}${field('waist', `Waist (${unitLength()})`, fmtInput(length(p.waist)), 'number', 'min="0" step="any" required')}</div>${select('activity', 'Typical activity', Object.keys(ACTIVITIES), p.activity)}<div class="form-grid">${select('goal', 'Your intention', ['Lose fat', 'Maintain weight', 'Gain weight'], p.goal)}${field('weeklyChange', 'Weekly change (kg/week)', p.weeklyChange, 'number', 'min="0" max="1" step="0.05" required')}</div><div class="suggestion-box"><div><small>ESTIMATED CALORIE GOAL</small><strong id="suggestion">${fmt(suggestion(p).target)} kcal</strong></div>${button('suggest', 'Use estimate', 'button secondary')}</div><p class="fine-print">Mifflin–St Jeor estimate. Deficits are capped at 20% of maintenance or 500 kcal. General adult guidance; your needs may differ.</p><p class="form-section">YOUR DAILY GOALS</p><div class="form-grid">${field('calories', 'Calories (kcal)', p.calories, 'number', `min="${p.sex === 'Male' ? 1500 : 1200}" max="6000" step="any" required`)}${field('protein', 'Protein (g)', p.protein, 'number', 'min="1" max="500" step="any" required')}${field('carbs', 'Carbs (g)', p.carbs, 'number', 'min="1" max="1000" step="any" required')}${field('fat', 'Fat (g)', p.fat, 'number', 'min="1" max="300" step="any" required')}${field('water', 'Water (ml)', p.water, 'number', 'min="500" max="6000" step="any" required')}</div><button class="button full" type="submit">${isNew ? 'Start my diary' : 'Save profile & goals'} ${icon('arrow')}</button></form>`, true);
}
function fmtInput(n) { return Math.round(n * 10000) / 10000; }
function profileFromForm(form) {
  const values = Object.fromEntries(new FormData(form));
  for (const key of Object.keys(defaultProfile)) if (typeof defaultProfile[key] === 'number') values[key] = Number(values[key]);
  values.weight = toMetric(values.weight, unitWeight()); values.targetWeight = toMetric(values.targetWeight, unitWeight());
  values.height = toMetric(values.height, unitLength()); values.waist = toMetric(values.waist, unitLength());
  return values;
}
function libraryDialog(meal = 'Breakfast') {
  activeEntry = { meal };
  showDialog('Your food shelf', `<div class="library-toolbar"><div class="search-box">${icon('search')}<input id="food-search" aria-label="Search foods" type="search" placeholder="Find a food…" /></div>${button('custom-food', `${icon('plus')} New food`, 'button secondary')}</div><div class="segmented library-tabs">${[['all', 'All foods'], ['favorites', 'Favorites'], ['meals', 'Saved meals']].map(([key, title]) => button('library-tab', title, libraryTab === key ? 'selected' : '', `data-tab="${key}"`)).join('')}</div><p class="fine-print">Sample foods are approximate. Check packaging and adjust for your recipe.</p><div id="food-results"></div>${button('compose', `${icon('plus')} Create saved meal`, 'text-button')}`, true);
  renderFoodResults();
}
function renderFoodResults() {
  const query = (document.querySelector('#food-search')?.value || '').trim().toLowerCase();
  const items = (libraryTab === 'meals' ? data.meals : data.foods.filter(f => libraryTab !== 'favorites' || f.favorite)).filter(f => (f.name || f.values.name).toLowerCase().includes(query)).sort((a, b) => Number(b.favorite || false) - Number(a.favorite || false) || (b.lastUsedAt || '').localeCompare(a.lastUsedAt || '') || (a.name || a.values.name).localeCompare(b.name || b.values.name));
  document.querySelector('#food-results').innerHTML = items.length ? items.map(f => libraryTab === 'meals' ? `<div class="library-row"><button data-action="log-template" data-id="${f.id}"><strong>${escape(f.name)}</strong><small>${f.foods.length} foods · ${fmt(f.foods.reduce((s, food) => s + food.calories * food.quantity, 0))} kcal</small></button>${button('compose', icon('edit'), 'icon-button', `data-id="${f.id}" aria-label="Edit ${escape(f.name)}"`)}</div>` : `<div class="library-row"><button data-action="pick-food" data-id="${f.id}"><strong>${escape(f.values.name)}</strong><small>${escape(f.values.serving)} · ${fmt(f.values.calories)} kcal</small></button>${button('favorite', icon('star'), `icon-button ${f.favorite ? 'favorite' : ''}`, `data-id="${f.id}" aria-label="${f.favorite ? 'Unfavorite' : 'Favorite'} ${escape(f.values.name)}" aria-pressed="${f.favorite}"`)}${button('edit-food', icon('edit'), 'icon-button', `data-id="${f.id}" aria-label="Edit ${escape(f.values.name)}"`)}</div>`).join('') : empty('A little room on your shelf', query ? 'No foods match your search.' : 'Add a food or save a meal to make it easy to find again.');
}
function localDateTime(date) { const d = new Date(date); return `${dayKey(d)}T${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`; }
function entryDialog(entry = null, food = null, libraryEdit = false) {
  const meal = entry?.values.meal || activeEntry?.meal || 'Breakfast';
  const f = entry?.values || { ...(food?.values || { name: '', serving: '1 serving', calories: 0, protein: 0, carbs: 0, fat: 0, category: 'Other', quantity: 1 }), meal, date: timestampForDay(selectedDay) };
  activeEntry = { id: entry?.id, foodId: food?.id, libraryEdit, meal };
  showDialog(libraryEdit ? 'Edit library food' : entry ? 'Edit food entry' : 'Log a little nourishment', `<form id="entry-form"><div class="form-grid">${field('name', 'Food name', f.name, 'text', 'required maxlength="200"')}${field('serving', 'One serving', f.serving, 'text', 'required maxlength="200"')}</div><p class="form-section">NUTRITION PER SERVING</p><div class="form-grid">${[['calories', 'Calories (kcal)', 10000], ['protein', 'Protein (g)', 1000], ['carbs', 'Carbs (g)', 2000], ['fat', 'Fat (g)', 1000]].map(([key, label, max]) => field(key, label, f[key], 'number', `min="0" max="${max}" step="any" required`)).join('')}</div>${select('category', 'Food category', CATEGORIES, f.category)}${!libraryEdit ? `<div class="form-grid">${field('quantity', 'Number of servings', f.quantity, 'number', 'min="0.01" max="100" step="any" required')}${select('meal', 'Meal', MEALS, f.meal)}</div>${field('date', 'Date & time', localDateTime(f.date), 'datetime-local', `max="${localDateTime(now())}" required`)}<div class="entry-total">This entry <strong id="entry-calories">${fmt(f.calories * f.quantity)} kcal</strong></div>${!entry && !food ? '<label class="checkbox"><input type="checkbox" name="saveLibrary" checked /> Save to my food library</label>' : ''}` : '<p class="fine-print">Changes affect this library food only. Your diary keeps its original nutrition values.</p>'}<button class="button full" type="submit">${entry || libraryEdit ? 'Save changes' : 'Add to diary'}</button></form>${entry ? `<div class="button-row entry-actions">${button('duplicate', 'Duplicate', 'button secondary', `data-id="${entry.id}"`)}${button('copy-entry', 'Copy to another day', 'button secondary', `data-id="${entry.id}"`)}</div>${button('delete-entry', 'Delete entry', 'text-button danger-text', `data-id="${entry.id}"`)}` : libraryEdit ? button('delete-food', 'Delete library food', 'text-button danger-text', `data-id="${food.id}"`) : ''}`, true);
}
function measurementDialog(id) {
  const m = data.measurements.find(m => m.id === id);
  showDialog(m ? 'Edit your check-in' : 'A moment to check in', `<p class="muted">Measurements are optional. Look for a longer-term pattern.</p><form id="measurement-form" data-id="${m?.id || ''}">${field('date', 'Date', m ? dayKey(m.date) : selectedDay, 'date', `max="${dayKey()}" required`)}<div class="form-grid">${field('weight', `Weight (${unitWeight()})`, m?.weight != null ? fmtInput(weight(m.weight)) : '', 'number', 'min="0" step="any"')}${field('waist', `Waist (${unitLength()})`, m?.waist != null ? fmtInput(length(m.waist)) : '', 'number', 'min="0" step="any"')}</div>${field('notes', 'Notes (optional)', m?.notes || '', 'text', 'maxlength="1000"')}<button type="submit" class="button full">Save measurement</button></form>${m ? button('delete-measurement', 'Delete measurement', 'text-button danger-text', `data-id="${m.id}"`) : ''}`);
}
function composeDialog(id, meal) {
  const existing = data.meals.find(m => m.id === id);
  const foods = existing?.foods || (meal ? data.entries.filter(e => dayKey(e.values.date) === selectedDay && e.values.meal === meal).map(e => e.values) : []);
  // Existing snapshots remain available even when their library food was removed.
  const choices = [...foods.map(f => ({ ...f, id: uid(), selected: true })), ...data.foods.filter(f => !foods.some(s => s.name === f.values.name && s.serving === f.values.serving)).map(f => ({ ...f.values, selected: false }))];
  activeEntry = { choices, id: existing?.id, meal: meal || activeEntry?.meal || 'Breakfast' };
  showDialog(existing ? 'Edit saved meal' : 'Make an everyday favorite', `<form id="compose-form">${field('name', 'Meal name', existing?.name || '', 'text', 'maxlength="200" required placeholder="e.g. My usual breakfast"')}<p class="muted">Select foods and set the number of servings for each.</p><div class="compose-list">${choices.map((f, i) => `<div class="compose-row"><label class="checkbox"><input name="include-${i}" type="checkbox" ${f.selected ? 'checked' : ''} />${escape(f.name)}<small>${escape(f.serving)}</small></label><label class="quantity-field">Servings<input aria-label="Servings of ${escape(f.name)}" name="qty-${i}" type="number" min="0.01" max="100" step="any" value="${f.quantity}" /></label></div>`).join('')}</div><button class="button full" type="submit">Save meal</button></form>${existing ? button('delete-template', 'Delete saved meal', 'text-button danger-text', `data-id="${existing.id}"`) : ''}`, true);
}
function waterDialog() {
  showDialog('A little hydration', `<form id="water-form">${field('amount', 'Water (ml)', 250, 'number', 'min="1" max="3000" step="any" required')}<button class="button full" type="submit">Add water</button></form>`);
}
function waterHistory() {
  const logs = data.water.filter(w => dayKey(w.date) === selectedDay).sort((a, b) => b.date.localeCompare(a.date));
  showDialog('Water · ' + shortDate(selectedDay), `${logs.length ? logs.map(w => `<div class="library-row"><span><strong>${fmt(w.amount)} ml</strong><small>${new Date(w.date).toLocaleTimeString(undefined, { hour: '2-digit', minute: '2-digit' })}</small></span>${button('delete-water', 'Remove', 'text-button danger-text', `data-id="${w.id}"`)}</div>`).join('') : empty('A little sip goes a long way', 'No water logged on this day.')}${button('water-custom', '+ Add water', 'button full')}`);
}
function confirmDialog(title, message, action, extra = '') { showDialog(title, `<p class="muted">${message}</p><div class="button-row">${button('close', 'Cancel', 'button secondary')}${button(action, 'Confirm', 'button', extra)}</div>`); }
function download(name, text, type = 'application/json') {
  const url = URL.createObjectURL(new Blob([text], { type }));
  const a = document.createElement('a'); a.href = url; a.download = name; a.click(); setTimeout(() => URL.revokeObjectURL(url), 30000);
}
function chooseImport() {
  const input = document.createElement('input'); input.type = 'file'; input.accept = '.json,application/json';
  input.addEventListener('change', async () => {
    try {
      const file = input.files[0]; if (!file) return;
      if (file.size > 25000000) throw new Error('This backup is too large (maximum 25 MB).');
      pendingImport = decodeBackup(await file.text());
      confirmDialog('Replace your diary?', `This backup contains ${pendingImport.entries.length} food entries and ${pendingImport.measurements.length} measurements. It replaces your current diary. Export a backup first if you want to keep it.`, 'confirm-import');
    } catch (e) { toast(e.message); }
  });
  input.click();
}
document.addEventListener('click', async event => {
  const target = event.target.closest('[data-action]'); if (!target || busy) return;
  const { action, id, meal } = target.dataset;
  try {
    if (action === 'close') modal.close();
    else if (action === 'nav') { view = target.dataset.view; location.hash = view; render(); window.scrollTo(0, 0); }
    else if (action === 'profile') profileDialog();
    else if (action === 'suggest') { const p = profileFromForm(document.querySelector('#profile-form')); const result = suggestion(p); if (!Number.isFinite(result.target)) throw new Error('Complete your profile details first.'); document.querySelector('[name=calories]').value = result.target; }
    else if (action === 'prev-day' || action === 'next-day') { selectedDay = shiftDay(selectedDay, action === 'prev-day' ? -1 : 1); if (selectedDay > dayKey()) selectedDay = dayKey(); render(); }
    else if (action === 'prev-month' || action === 'next-month') { const date = new Date(`${selectedDay}T12:00:00`); date.setDate(1); date.setMonth(date.getMonth() + (action === 'prev-month' ? -1 : 1)); selectedDay = dayKey(date); render(); }
    else if (action === 'select-day') { selectedDay = target.dataset.day; render(); }
    else if (action === 'add' || action === 'library') { libraryTab = 'all'; libraryDialog(meal || 'Breakfast'); }
    else if (action === 'library-tab') { libraryTab = target.dataset.tab; modal.querySelectorAll('[data-tab]').forEach(b => b.classList.toggle('selected', b.dataset.tab === libraryTab)); renderFoodResults(); }
    else if (action === 'custom-food') entryDialog();
    else if (action === 'pick-food') entryDialog(null, data.foods.find(f => f.id === id));
    else if (action === 'edit-entry') entryDialog(data.entries.find(e => e.id === id));
    else if (action === 'edit-food') entryDialog(null, data.foods.find(f => f.id === id), true);
    else if (action === 'favorite') { if (await commit(d => { const food = d.foods.find(f => f.id === id); food.favorite = !food.favorite; })) renderFoodResults(); }
    else if (action === 'water') await commit(d => d.water.push({ id: uid(), date: timestampForDay(selectedDay), amount: Number(target.dataset.amount) }), 'Water logged.');
    else if (action === 'water-custom') waterDialog();
    else if (action === 'water-history') waterHistory();
    else if (action === 'delete-water') { if (await commit(d => { d.water = d.water.filter(w => w.id !== id); }, 'Water log removed.')) waterHistory(); }
    else if (action === 'measurement') measurementDialog(id);
    else if (action === 'metric') { metric = target.dataset.metric; render(); }
    else if (action === 'duplicate') { if (await commit(d => { const entry = structuredClone(d.entries.find(e => e.id === id)); entry.id = uid(); entry.values.id = uid(); entry.createdAt = now(); d.entries.push(entry); }, 'Entry duplicated.')) modal.close(); }
    else if (action === 'copy-entry') showDialog('Copy to another day', `<form id="copy-form" data-id="${id}">${field('date', 'Copy to', selectedDay, 'date', `max="${dayKey()}" required`)}${select('meal', 'Meal', MEALS, data.entries.find(e => e.id === id).values.meal)}<button class="button full" type="submit">Copy entry</button></form>`);
    else if (['delete-entry', 'delete-food', 'delete-measurement', 'delete-template'].includes(action)) confirmDialog('Delete this record?', action === 'delete-food' || action === 'delete-template' ? 'Logged diary entries will be preserved.' : 'This record will be removed from your diary.', `confirm-${action}`, `data-id="${id}"`);
    else if (action.startsWith('confirm-delete-')) { const collection = { 'confirm-delete-entry': 'entries', 'confirm-delete-food': 'foods', 'confirm-delete-measurement': 'measurements', 'confirm-delete-template': 'meals' }[action]; if (await commit(d => { d[collection] = d[collection].filter(r => r.id !== id); }, 'Record deleted.')) modal.close(); }
    else if (action === 'save-meal' || action === 'compose') composeDialog(id, meal);
    else if (action === 'log-template') {
      const template = data.meals.find(m => m.id === id);
      showDialog('Log ' + escape(template.name), `<form id="log-template-form" data-id="${id}">${select('meal', 'Meal', MEALS, activeEntry?.meal || 'Breakfast')}${field('date', 'Date', selectedDay, 'date', `max="${dayKey()}" required`)}${field('quantity', 'Meal portions', 1, 'number', 'min="0.01" max="100" step="any" required')}<p class="muted">${template.foods.length} foods · ${fmt(template.foods.reduce((s, f) => s + f.calories * f.quantity, 0))} kcal per meal portion</p><button class="button full" type="submit">Add meal to diary</button></form>`);
    }
    else if (action === 'export') { const backup = structuredClone(data); backup.exportedAt = now(); download(`CalorieCut-${dayKey()}.json`, encodeBackup(backup)); toast('Backup exported. Keep it somewhere safe.'); }
    else if (action === 'import') chooseImport();
    else if (action === 'confirm-import') { if (await commit(d => { const revision = d.webRevision; Object.keys(d).forEach(key => delete d[key]); Object.assign(d, pendingImport); d.webRevision = revision; d.webAppearanceVersion = 1; }, 'Backup restored.')) { pendingImport = null; selectedDay = dayKey(); view = 'home'; render(); modal.close(); } }
    else if (action === 'reset') confirmDialog('Delete all your data?', 'This deletes everything stored by CalorieCut on this device. This cannot be undone without an exported backup.', 'confirm-reset');
    else if (action === 'confirm-reset') { if (await commit(d => { const revision = d.webRevision; Object.keys(d).forEach(key => delete d[key]); Object.assign(d, emptyDiary(), { webRevision: revision }); }, 'Your diary has been cleared.')) modal.close(); }
    else if (action === 'storage') { const granted = await navigator.storage?.persist?.(); toast(granted ? 'Persistent storage granted. Keep exporting backups for extra peace of mind.' : 'Your browser manages storage. Regular backups are the best way to keep your diary safe.'); }
    else if (action === 'install') {
      if (installPrompt) { await installPrompt.prompt(); installPrompt = null; }
      else showDialog('Keep CalorieCut close', `<div class="install-step"><span>1</span><div><h3>iPhone / iPad</h3><p>Open this website in Safari. Tap Share, then <strong>Add to Home Screen</strong>. If shown, keep “Open as Web App” enabled and tap Add.</p></div></div><div class="install-step"><span>2</span><div><h3>Android</h3><p>Open this website in Chrome. Tap the menu (⋮), then <strong>Install app</strong> or <strong>Add to Home screen</strong>.</p></div></div><p class="fine-print">Installation and offline mode need a website served over HTTPS. Open it once while connected. Data is local to this browser or installed app; use backups to move between them.</p>`);
    }
    else if (action === 'reload') location.reload();
    else if (action === 'export-raw') download('CalorieCut-recovery.json', JSON.stringify(await loadDiary(), null, 2));
  } catch (e) { error(e.message); }
});
document.addEventListener('input', event => {
  if (event.target.id === 'food-search') renderFoodResults();
  if (event.target.form?.id === 'profile-form') { const result = suggestion(profileFromForm(event.target.form)); document.querySelector('#suggestion').textContent = Number.isFinite(result.target) ? `${fmt(result.target)} kcal` : 'Complete your details'; document.querySelector('[name=calories]').min = event.target.form.elements.sex.value === 'Male' ? 1500 : 1200; }
  if (event.target.form?.id === 'entry-form' && document.querySelector('#entry-calories')) { const f = new FormData(event.target.form); document.querySelector('#entry-calories').textContent = `${fmt(Number(f.get('calories')) * Number(f.get('quantity')))} kcal`; }
});
document.addEventListener('change', event => {
  if (event.target.id === 'day' && event.target.value && event.target.value <= dayKey()) { selectedDay = event.target.value; render(); }
  if (event.target.id === 'period') { period = event.target.value; render(); }
});
document.addEventListener('submit', async event => {
  event.preventDefault(); if (busy) return;
  const form = event.target, f = Object.fromEntries(new FormData(form));
  try {
    let success = false;
    if (form.id === 'profile-form') {
      const p = validateProfile(profileFromForm(form));
      success = await commit(d => {
        if (!d.profile) { d.profile = { id: uid(), createdAt: now(), values: p }; d.measurements.push({ id: uid(), date: now(), weight: p.weight, waist: p.waist, notes: 'Starting point' }); }
        else d.profile.values = p;
      }, 'Your goals are saved.');
    } else if (form.id === 'entry-form') {
      const edit = { ...activeEntry };
      const values = validateFood({ id: uid(), name: f.name.trim(), serving: f.serving.trim(), calories: Number(f.calories), protein: Number(f.protein), carbs: Number(f.carbs), fat: Number(f.fat), category: f.category, quantity: edit.libraryEdit ? 1 : Number(f.quantity), meal: edit.libraryEdit ? 'Breakfast' : f.meal, date: edit.libraryEdit ? now() : new Date(f.date).toISOString() });
      success = await commit(d => {
        if (edit.libraryEdit) d.foods.find(food => food.id === edit.foodId).values = values;
        else if (edit.id) { const entry = d.entries.find(e => e.id === edit.id); values.id = entry.values.id; entry.values = values; }
        else { d.entries.push({ id: uid(), createdAt: now(), values }); if (edit.foodId) d.foods.find(food => food.id === edit.foodId).lastUsedAt = now(); if (f.saveLibrary) d.foods.push({ id: uid(), createdAt: now(), lastUsedAt: now(), favorite: false, sample: false, values: { ...values, id: uid(), quantity: 1 } }); }
      }, edit.libraryEdit ? 'Food library updated.' : 'Food saved to your diary.');
    } else if (form.id === 'measurement-form') {
      const m = { id: form.dataset.id || uid(), date: timestampForDay(f.date), weight: f.weight === '' ? null : toMetric(Number(f.weight), unitWeight()), waist: f.waist === '' ? null : toMetric(Number(f.waist), unitLength()), notes: f.notes.trim() };
      success = await commit(d => { const index = d.measurements.findIndex(record => record.id === m.id); if (index === -1) d.measurements.push(m); else d.measurements[index] = m; }, 'Measurement saved.');
    } else if (form.id === 'water-form') success = await commit(d => d.water.push({ id: uid(), date: timestampForDay(selectedDay), amount: Number(f.amount) }), 'Water logged.');
    else if (form.id === 'notes-form') { await commit(d => { let note = d.notes.find(n => dayKey(n.date) === selectedDay); if (!note) { note = { id: uid(), date: timestampForDay(selectedDay), text: '', steps: 0 }; d.notes.push(note); } note.text = f.text; note.steps = Number(f.steps); }, 'Notes saved.'); return; }
    else if (form.id === 'settings-form') { await commit(d => Object.assign(d.settings, f), 'Preferences saved.'); return; }
    else if (form.id === 'copy-form') success = await commit(d => { const source = structuredClone(d.entries.find(e => e.id === form.dataset.id)); source.id = uid(); source.values.id = uid(); source.values.date = timestampForDay(f.date); source.values.meal = f.meal; source.createdAt = now(); d.entries.push(source); }, 'Entry copied.');
    else if (form.id === 'compose-form') {
      const foods = activeEntry.choices.flatMap((food, i) => f[`include-${i}`] ? [{ ...food, id: uid(), quantity: Number(f[`qty-${i}`]), date: now() }] : []);
      foods.forEach(food => delete food.selected);
      const id = activeEntry.id || uid();
      success = await commit(d => { const index = d.meals.findIndex(m => m.id === id); const m = { id, name: f.name.trim(), createdAt: index === -1 ? now() : d.meals[index].createdAt, foods }; if (index === -1) d.meals.push(m); else d.meals[index] = m; }, 'Meal saved to your shelf.');
    } else if (form.id === 'log-template-form') success = await commit(d => { const m = d.meals.find(m => m.id === form.dataset.id); m.foods.forEach(food => d.entries.push({ id: uid(), createdAt: now(), values: { ...food, id: uid(), quantity: food.quantity * Number(f.quantity), meal: f.meal, date: timestampForDay(f.date) } })); }, 'Meal added to your diary.');
    if (success) modal.close();
  } catch (e) { error(e.message); }
});
window.addEventListener('beforeinstallprompt', event => { event.preventDefault(); installPrompt = event; });
function updateConnection() {
  const indicator = document.querySelector('.connection');
  if (indicator) indicator.innerHTML = `${icon(navigator.onLine ? 'wifi' : 'shield')}<span>${navigator.onLine ? 'On your device' : 'Offline · still saving'}</span>`;
}
window.addEventListener('online', updateConnection);
window.addEventListener('offline', updateConnection);
window.addEventListener('hashchange', () => { const name = location.hash.slice(1); if (name !== view && ['home', 'diary', 'progress', 'review', 'settings'].includes(name)) { view = name; if (data) render(); } });
window.addEventListener('beforeunload', event => { if (busy) { event.preventDefault(); event.returnValue = ''; } });
matchMedia('(prefers-color-scheme: dark)').addEventListener('change', () => data && theme());
async function init() {
  try {
    const loaded = await loadDiary();
    if (loaded) validateBackup(loaded);
    data = loaded || emptyDiary();
    // Restore the requested original black appearance once, preserving later choices.
    if (data.webAppearanceVersion !== 1) {
      const next = structuredClone(data);
      next.settings.theme = 'Dark';
      next.webAppearanceVersion = 1;
      await saveDiary(next, data.webRevision || 0);
      data = next;
    }
    if (['home', 'diary', 'progress', 'review', 'settings'].includes(location.hash.slice(1))) view = location.hash.slice(1);
    render();
  } catch (e) {
    app.innerHTML = `<main class="recovery"><h1>Your diary needs a moment.</h1><p>${escape(e.message)}</p><p>Your saved data has not been overwritten.</p>${button('reload', 'Try again')}${button('export-raw', 'Export stored data for recovery', 'button secondary')}</main>`;
  }
}
await init();
if (import.meta.env.PROD && 'serviceWorker' in navigator) {
  navigator.serviceWorker.register(`${import.meta.env.BASE_URL}sw.js`).then(registration => {
    const notify = () => { if (registration.waiting) toast('An update is ready. Close and reopen CalorieCut to use it.'); };
    registration.addEventListener('updatefound', () => registration.installing?.addEventListener('statechange', notify));
    notify();
  }).catch(() => toast('Offline setup could not finish. Reopen while connected to try again.'));
}
