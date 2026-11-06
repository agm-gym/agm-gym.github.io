// AGM Gym : met l'appli en cache pour qu'elle s'ouvre même sans réseau
const CACHE = 'agm-gym-v20';
const FILES = ['./', './index.html', './manifest.webmanifest', './icon-192.png', './icon-512.png', './favicon.svg', './apple-touch-icon.png'];
self.addEventListener('install', e => { e.waitUntil(caches.open(CACHE).then(c => c.addAll(FILES))); self.skipWaiting(); });
self.addEventListener('activate', e => { e.waitUntil(caches.keys().then(k => Promise.all(k.filter(n => n !== CACHE).map(n => caches.delete(n))))); self.clients.claim(); });
// réseau d'abord (pour avoir toujours la dernière version), cache si hors ligne
self.addEventListener('fetch', e => {
  if (e.request.method !== 'GET' || !e.request.url.startsWith(self.location.origin)) return;
  e.respondWith(fetch(e.request, e.request.mode === 'navigate' ? {cache: 'no-cache'} : {}).then(r => { const c = r.clone(); caches.open(CACHE).then(x => x.put(e.request, c)); return r; }).catch(() => caches.match(e.request).then(r => r || caches.match('./index.html'))));
});

// notifications : affichage et ouverture de l'appli au bon endroit
self.addEventListener('push', e => {
  let d = {};
  try { d = e.data.json(); } catch (_) { d = { title: 'AGM Gym', body: e.data ? e.data.text() : '' }; }
  e.waitUntil(self.registration.showNotification(d.title || 'AGM Gym', {
    body: d.body || '', icon: 'icon-192.png', badge: 'icon-192.png', tag: d.tag, renotify: !!d.tag, data: { url: d.url || '#accueil' }
  }));
});
self.addEventListener('notificationclick', e => {
  e.notification.close();
  const url = new URL('./' + ((e.notification.data && e.notification.data.url) || ''), self.registration.scope).href;
  e.waitUntil(clients.matchAll({ type: 'window', includeUncontrolled: true }).then(ws => {
    for (const w of ws) { if ('focus' in w) { if ('navigate' in w) w.navigate(url); return w.focus(); } }
    return clients.openWindow(url);
  }));
});
