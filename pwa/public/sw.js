self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    const keys = await caches.keys();
    await Promise.all(keys.map(k => caches.delete(k)));
  })());
});
self.addEventListener('fetch', (event) => {
  // Simple network-first fallback to cache if needed later
});
