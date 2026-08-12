self.addEventListener('push', function(event) {
  var data = {};
  try { data = event.data.json(); } catch (e) { data = { title: 'Neon Chat', body: 'Новое сообщение' }; }
  event.waitUntil(
    self.registration.showNotification(data.title || 'Neon Chat', {
      body: data.body || 'Новое сообщение',
      icon: 'https://superpirov.github.io/Neon-Chat/icon.png',
      badge: 'https://superpirov.github.io/Neon-Chat/icon.png',
      vibrate: [200, 100, 200],
      tag: 'neon-chat-msg'
    })
  );
});

self.addEventListener('notificationclick', function(event) {
  event.notification.close();
  event.waitUntil(clients.openWindow('https://superpirov.github.io/Neon-Chat/'));
});
