const SUPABASE_URL = 'https://pocxolhghqxrlaqifxem.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBvY3hvbGhnaHF4cmxhcWlmeGVtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1NDA4ODQsImV4cCI6MjEwMjExNjg4NH0.NPl_MzneFevI-efp1wSRBIFVVRO5MA0PCmYGVAxABIg';

document.addEventListener('DOMContentLoaded', function() {
  var errorMsg = document.getElementById('error-msg');
  var loginBtn = document.getElementById('login-btn');
  var loginName = document.getElementById('login-name');
  var logoutBtn = document.getElementById('logout-btn');
  var who = document.getElementById('who');
  var messagesEl = document.getElementById('messages');
  var form = document.getElementById('chat-form');
  var textInput = document.getElementById('text');
  var loginSection = document.getElementById('login');
  var chatSection = document.getElementById('chat');

  // Проверка ключей
  if (!SUPABASE_URL || SUPABASE_URL.includes('ВСТАВЬ') || !SUPABASE_ANON_KEY || SUPABASE_ANON_KEY.includes('ВСТАВЬ')) {
    if (errorMsg) {
      errorMsg.textContent = '⚠ Вставь ключи Supabase в app.js';
      errorMsg.hidden = false;
    }
    return;
  }

  var client;
  try {
    client = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
  } catch (e) {
    if (errorMsg) {
      errorMsg.textContent = '⚠ Ошибка Supabase: ' + e.message;
      errorMsg.hidden = false;
    }
    return;
  }

  var userName = localStorage.getItem('messenger_name') || '';
  var seenMessages = {};

  // === Клик по кнопке ВОЙТИ ===
  if (loginBtn) {
    loginBtn.addEventListener('click', function() {
      var name = loginName.value.trim();
      if (name.length < 2) {
        if (errorMsg) {
          errorMsg.textContent = 'Введите имя минимум из 2 символов';
          errorMsg.hidden = false;
        }
        return;
      }
      if (errorMsg) errorMsg.hidden = true;
      userName = name;
      localStorage.setItem('messenger_name', userName);
      showChat();
    });
  }

  // Enter в поле имени
  if (loginName) {
    loginName.addEventListener('keydown', function(e) {
      if (e.key === 'Enter') {
        e.preventDefault();
        if (loginBtn) loginBtn.click();
      }
    });
  }

  // Кнопка ВЫХОД
  if (logoutBtn) {
    logoutBtn.addEventListener('click', function() {
      localStorage.removeItem('messenger_name');
      location.reload();
    });
  }

  function showChat() {
    if (loginSection) loginSection.hidden = true;
    if (chatSection) chatSection.hidden = false;
    if (who) who.textContent = userName;
    initRealtime();
    loadMessages();
  }

  async function loadMessages() {
    if (!messagesEl) return;
    messagesEl.innerHTML = '';
    seenMessages = {};

    var result = await client.from('messages').select('*').order('created_at', { ascending: true }).limit(200);
    if (result.error) {
      console.error(result.error);
      return;
    }
    if (result.data) {
      for (var i = 0; i < result.data.length; i++) {
        addMessage(result.data[i], false);
      }
    }
    scrollToBottom();
  }

  function addMessage(message, scroll) {
    if (!message || !messagesEl) return;
    if (seenMessages[message.id]) return;
    seenMessages[message.id] = true;

    var div = document.createElement('div');
    div.className = 'message';
    if (message.user_name === userName) div.classList.add('mine');

    var meta = document.createElement('div');
    meta.className = 'meta';
    var time = new Date(message.created_at).toLocaleTimeString('ru-RU', { hour: '2-digit', minute: '2-digit' });
    meta.textContent = message.user_name + ' · ' + time;

    var text = document.createElement('div');
    text.className = 'text-content';
    text.textContent = message.text;

    div.appendChild(meta);
    div.appendChild(text);
    messagesEl.appendChild(div);

    if (scroll !== false) scrollToBottom();
  }

  // Отправка сообщения
  if (form) {
    form.addEventListener('submit', async function(event) {
      event.preventDefault();
      if (!textInput) return;
      var text = textInput.value.trim();
      if (!text) return;

      var result = await client.from('messages').insert({ user_name: userName, text: text }).select().single();
      if (result.error) {
        console.error(result.error);
        return;
      }
      if (result.data) {
        textInput.value = '';
        addMessage(result.data, true);
      }
    });
  }

  function initRealtime() {
    client.channel('messages-inserts')
      .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'messages' }, function(payload) {
        if (payload && payload.new) addMessage(payload.new, true);
      })
      .subscribe();
  }

  function scrollToBottom() {
    if (messagesEl) messagesEl.scrollTop = messagesEl.scrollHeight;
  }

  // Авто-вход если имя сохранено
  if (userName && userName.length >= 2) {
    if (loginName) loginName.value = userName;
    showChat();
  } else {
    if (loginSection) loginSection.hidden = false;
    if (chatSection) chatSection.hidden = true;
  }
});