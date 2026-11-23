/* Ashfall offline support: the game (and its 3D engine, fonts and images) are saved on the device so solo modes work with no internet.
   index.html is always fetched fresh when online (network first), so updates arrive right away. */
const CACHE = 'ashfall-v2';
const CORE = ['./', 'index.html', 'ashfall-192.png', 'ashfall-512.png', 'ashfall-touch.png', 'ashfall-icon.svg', 'manifest.webmanifest', 'studio/ninebolt-dark.png', 'studio/ninebolt-icon-round.png',
  'https://cdnjs.cloudflare.com/ajax/libs/three.js/r128/three.min.js', 'https://unpkg.com/peerjs@1.5.4/dist/peerjs.min.js'];
self.addEventListener('install', e => { e.waitUntil(caches.open(CACHE).then(c => Promise.all(CORE.map(u => c.add(u).catch(() => {})))).then(() => self.skipWaiting())); });
self.addEventListener('activate', e => { e.waitUntil(caches.keys().then(ks => Promise.all(ks.filter(k => k !== CACHE).map(k => caches.delete(k)))).then(() => self.clients.claim())); });
const CACHEABLE = /^(https:\/\/(cdnjs\.cloudflare\.com|unpkg\.com|fonts\.googleapis\.com|fonts\.gstatic\.com|www\.gstatic\.com\/firebasejs)\/)/;
self.addEventListener('fetch', e => {
  const req = e.request; if (req.method !== 'GET') return;
  const url = new URL(req.url), same = url.origin === self.location.origin;
  if (same && url.searchParams.has('c')) return; // the game's own "is there a newer version?" check must always hit the network
  if (same && (req.mode === 'navigate' || url.pathname.endsWith('/') || url.pathname.endsWith('index.html'))) {
    // never hang on a slow connection: if the network takes more than 4 s, open the saved copy instead
    const cached = () => caches.match('index.html').then(r => r || caches.match('./'));
    const net = fetch(req).then(r => { if (r && r.ok) { const cp = r.clone(); caches.open(CACHE).then(c => c.put('index.html', cp)); } return r; });
    e.respondWith(new Promise(resolve => {
      let done = false; const finish = r => { if (!done && r) { done = true; resolve(r); } };
      const t = setTimeout(() => cached().then(r => finish(r)), 4000);
      net.then(r => { clearTimeout(t); finish(r); }).catch(() => { clearTimeout(t); cached().then(r => r ? finish(r) : net.catch(() => finish(Response.error()))); });
    }));
    return;
  }
  if (same || CACHEABLE.test(req.url)) {
    e.respondWith(caches.match(req).then(hit => {
      const net = fetch(req).then(r => { if (r && (r.ok || r.type === 'opaque')) { const cp = r.clone(); caches.open(CACHE).then(c => c.put(req, cp)); } return r; }).catch(() => hit);
      return hit || net;
    }));
  }
});
