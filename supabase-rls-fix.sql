-- ============================================================================
-- NEON CHAT: закрытие доступа к базе (RLS)
-- ----------------------------------------------------------------------------
-- Как применить:
--   1. Открой https://supabase.com/dashboard -> твой проект
--   2. SQL Editor -> New query
--   3. Вставь весь этот скрипт и нажми Run
--
-- Что делает:
--   * Включает Row Level Security на всех таблицах
--   * Удаляет старые политики (сейчас anon видит ВСЕ сообщения)
--   * Создаёт правильные: каждый пользователь видит только свои переписки
--   * Гарантирует триггер создания профиля при регистрации
--
-- После выполнения приложение продолжит работать как раньше,
-- но чужие переписки станут недоступны ни через сайт, ни через API-ключ.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 0. Триггер: при регистрации автоматически создаём строку в public.users
--    SECURITY DEFINER = выполняется с правами владельца, RLS не мешает.
--    (Заменяет существующий триггер, если он был.)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.users (id, nickname, email)
  VALUES (
    new.id,
    COALESCE(new.raw_user_meta_data ->> 'nickname', split_part(new.email, '@', 1)),
    new.email
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN new;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ----------------------------------------------------------------------------
-- 1. Включаем RLS на всех таблицах
-- ----------------------------------------------------------------------------
ALTER TABLE public.users            ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.contacts         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.private_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_presence    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.p2p_signals      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages         ENABLE ROW LEVEL SECURITY;

-- ----------------------------------------------------------------------------
-- 2. Сносим ВСЕ старые политики на этих таблицах (как бы они ни назывались)
-- ----------------------------------------------------------------------------
DO $$
DECLARE r record;
BEGIN
  FOR r IN
    SELECT schemaname, tablename, policyname
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename IN ('users','contacts','private_messages','user_presence','p2p_signals','messages')
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON %I.%I', r.policyname, r.schemaname, r.tablename);
  END LOOP;
END $$;

-- ----------------------------------------------------------------------------
-- 3. users — профили
--    Читать могут все вошедшие (нужно для поиска по никнейму),
--    создавать/менять — только свою строку. Анонимам — ничего.
-- ----------------------------------------------------------------------------
CREATE POLICY "users_select_authed" ON public.users
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "users_insert_self" ON public.users
  FOR INSERT TO authenticated WITH CHECK (auth.uid() = id);

CREATE POLICY "users_update_self" ON public.users
  FOR UPDATE TO authenticated USING (auth.uid() = id) WITH CHECK (auth.uid() = id);

-- ----------------------------------------------------------------------------
-- 4. contacts — только свои контакты
-- ----------------------------------------------------------------------------
CREATE POLICY "contacts_select_own" ON public.contacts
  FOR SELECT TO authenticated USING (user_id = auth.uid());

CREATE POLICY "contacts_insert_own" ON public.contacts
  FOR INSERT TO authenticated WITH CHECK (user_id = auth.uid());

CREATE POLICY "contacts_delete_own" ON public.contacts
  FOR DELETE TO authenticated USING (user_id = auth.uid());

-- ----------------------------------------------------------------------------
-- 5. private_messages — переписку видят только её участники.
--    Писать может только отправитель, удалять «у всех» — тоже только автор.
-- ----------------------------------------------------------------------------
CREATE POLICY "pm_select_participant" ON public.private_messages
  FOR SELECT TO authenticated
  USING (sender_id = auth.uid() OR receiver_id = auth.uid());

CREATE POLICY "pm_insert_sender" ON public.private_messages
  FOR INSERT TO authenticated
  WITH CHECK (sender_id = auth.uid());

CREATE POLICY "pm_delete_sender" ON public.private_messages
  FOR DELETE TO authenticated
  USING (sender_id = auth.uid());

-- ----------------------------------------------------------------------------
-- 6. user_presence — онлайн-статусы
--    Своё last_seen обновляет хозяин, читать могут все вошедшие
--    (нужно, чтобы видеть «онлайн» у контактов).
-- ----------------------------------------------------------------------------
CREATE UNIQUE INDEX IF NOT EXISTS user_presence_user_id_key
  ON public.user_presence (user_id);

CREATE POLICY "presence_select_authed" ON public.user_presence
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "presence_insert_own" ON public.user_presence
  FOR INSERT TO authenticated WITH CHECK (user_id = auth.uid());

CREATE POLICY "presence_update_own" ON public.user_presence
  FOR UPDATE TO authenticated USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

-- ----------------------------------------------------------------------------
-- 7. Неиспользуемые таблицы (p2p_signals, messages)
--    RLS включён, политик нет => через API они полностью мертвы.
--    Если данные не нужны — можно удалить физически (раскомментируй):
-- ----------------------------------------------------------------------------
-- DROP TABLE IF EXISTS public.p2p_signals;
-- DROP TABLE IF EXISTS public.messages;

-- ----------------------------------------------------------------------------
-- 8. Проверка: должны увидеть список новых политик
-- ----------------------------------------------------------------------------
SELECT tablename, policyname, cmd, roles
FROM pg_policies
WHERE schemaname = 'public'
ORDER BY tablename, policyname;
