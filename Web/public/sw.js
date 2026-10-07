const root = new URL('./', self.location.href);
const PREFIX = `caloriecut-${root.pathname}-`;
const CACHE = PREFIX + '__VERSION__';
const FILES = /* __PRECACHE__ */ [];
self.addEventListener('install', event => {
  event.waitUntil(caches.open(CACHE).then(cache => cache.addAll(FILES.map(file => new URL(file, root).href))));
});
self.addEventListener('activate', event => {
  event.waitUntil(caches.keys().then(keys => Promise.all(keys.filter(key => key.startsWith(PREFIX) && key !== CACHE).map(key => caches.delete(key)))).then(() => self.clients.claim()));
});
self.addEventListener('fetch', event => {
  const url = new URL(event.request.url);
  if (event.request.method !== 'GET' || url.origin !== root.origin || !url.pathname.startsWith(root.pathname)) return;
  if (event.request.mode === 'navigate') {
    event.respondWith(caches.open(CACHE).then(async cache => (await cache.match(new URL('index.html', root).href)) || fetch(event.request)));
  } else {
    // Precached same-origin files are identical across Origin request headers.
    // Static hosts may emit Vary: Origin; module requests still need to work offline.
    event.respondWith(caches.open(CACHE).then(async cache => (await cache.match(event.request, { ignoreVary: true })) || fetch(event.request)));
  }
});
