/* Boltrush moved to its own site: this worker removes itself and its old cache */
self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', e => { e.waitUntil(caches.keys().then(ks => Promise.all(ks.filter(k => k.startsWith('boltrush-')).map(k => caches.delete(k)))).then(() => self.registration.unregister())); });
