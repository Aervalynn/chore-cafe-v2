step	section	sql
1	EXTENSIONS	"create extension if not exists pg_cron;
create extension if not exists pg_net;
create extension if not exists pg_stat_statements;
create extension if not exists pgcrypto;
create extension if not exists supabase_vault;
create extension if not exists ""uuid-ossp"";"
2	TABLES	"create table if not exists chore_instances (
  id uuid not null default gen_random_uuid(),
  chore_id uuid not null,
  due_date date,
  status text not null default 'pool'::text,
  accepted_by uuid,
  accepted_at timestamp with time zone,
  completed_by uuid,
  completed_at timestamp with time zone,
  is_bounty boolean not null default false,
  abandoned_by uuid,
  snoozed_until date,
  created_at timestamp with time zone not null default now()
);

create table if not exists chores (
  id uuid not null default gen_random_uuid(),
  name text not null,
  difficulty text not null,
  frequency text not null,
  active_days integer[],
  created_by uuid,
  is_active boolean not null default true,
  created_at timestamp with time zone not null default now()
);

create table if not exists coin_transactions (
  id uuid not null default gen_random_uuid(),
  user_id uuid not null,
  amount integer not null,
  reason text not null,
  chore_instance_id uuid,
  created_at timestamp with time zone not null default now(),
  from_user uuid,
  kind text not null default 'chore'::text,
  recognizes uuid
);

create table if not exists notification_log (
  id uuid not null default gen_random_uuid(),
  chore_instance_id uuid,
  kind text not null,
  sent_at timestamp with time zone not null default now(),
  day date not null default ((now() AT TIME ZONE 'America/New_York'::text))::date
);

create table if not exists notification_messages (
  id uuid not null default gen_random_uuid(),
  kind text not null,
  audience text not null default 'any'::text,
  min_days_overdue integer,
  message text not null,
  active boolean not null default true
);

create table if not exists nudges (
  id uuid not null default gen_random_uuid(),
  chore_instance_id uuid not null,
  from_user uuid not null,
  to_user uuid not null,
  nudge_day date not null default ((now() AT TIME ZONE 'America/New_York'::text))::date,
  created_at timestamp with time zone not null default now()
);

create table if not exists profiles (
  id uuid not null,
  display_name text not null,
  created_at timestamp with time zone not null default now()
);

create table if not exists settings (
  id integer not null default 1,
  coins_easy integer not null default 10,
  coins_medium integer not null default 20,
  coins_hard integer not null default 40,
  bounty_multiplier numeric not null default 1.5,
  auto_release_days integer not null default 3,
  notify_hour integer not null default 20,
  gift_amount integer not null default 15
);"
3	CONSTRAINTS (primary keys, foreign keys, unique, check)	"alter table chore_instances add constraint chore_instances_abandoned_by_fkey FOREIGN KEY (abandoned_by) REFERENCES profiles(id);
alter table chore_instances add constraint chore_instances_accepted_by_fkey FOREIGN KEY (accepted_by) REFERENCES profiles(id);
alter table chore_instances add constraint chore_instances_chore_id_fkey FOREIGN KEY (chore_id) REFERENCES chores(id) ON DELETE CASCADE;
alter table chore_instances add constraint chore_instances_completed_by_fkey FOREIGN KEY (completed_by) REFERENCES profiles(id);
alter table chore_instances add constraint chore_instances_pkey PRIMARY KEY (id);
alter table chore_instances add constraint chore_instances_status_check CHECK ((status = ANY (ARRAY['pool'::text, 'accepted'::text, 'completed'::text])));
alter table chores add constraint chores_created_by_fkey FOREIGN KEY (created_by) REFERENCES profiles(id);
alter table chores add constraint chores_difficulty_check CHECK ((difficulty = ANY (ARRAY['easy'::text, 'medium'::text, 'hard'::text])));
alter table chores add constraint chores_frequency_check CHECK ((frequency = ANY (ARRAY['one_time'::text, 'on_demand'::text, 'daily'::text, 'weekly'::text, 'biweekly'::text, 'monthly'::text, 'quarterly'::text])));
alter table chores add constraint chores_pkey PRIMARY KEY (id);
alter table coin_transactions add constraint coin_transactions_chore_instance_id_fkey FOREIGN KEY (chore_instance_id) REFERENCES chore_instances(id) ON DELETE SET NULL;
alter table coin_transactions add constraint coin_transactions_from_user_fkey FOREIGN KEY (from_user) REFERENCES profiles(id);
alter table coin_transactions add constraint coin_transactions_kind_check CHECK ((kind = ANY (ARRAY['chore'::text, 'adhoc'::text, 'gift'::text])));
alter table coin_transactions add constraint coin_transactions_pkey PRIMARY KEY (id);
alter table coin_transactions add constraint coin_transactions_recognizes_fkey FOREIGN KEY (recognizes) REFERENCES coin_transactions(id);
alter table coin_transactions add constraint coin_transactions_user_id_fkey FOREIGN KEY (user_id) REFERENCES profiles(id);
alter table notification_log add constraint notification_log_chore_instance_id_fkey FOREIGN KEY (chore_instance_id) REFERENCES chore_instances(id) ON DELETE CASCADE;
alter table notification_log add constraint notification_log_pkey PRIMARY KEY (id);
alter table notification_messages add constraint notification_messages_audience_check CHECK ((audience = ANY (ARRAY['holder'::text, 'other'::text, 'recipient'::text, 'both'::text, 'any'::text])));
alter table notification_messages add constraint notification_messages_kind_check CHECK ((kind = ANY (ARRAY['overdue'::text, 'completed'::text, 'gift'::text, 'nudge'::text, 'logged'::text])));
alter table notification_messages add constraint notification_messages_pkey PRIMARY KEY (id);
alter table nudges add constraint nudges_chore_instance_id_fkey FOREIGN KEY (chore_instance_id) REFERENCES chore_instances(id) ON DELETE CASCADE;
alter table nudges add constraint nudges_from_user_fkey FOREIGN KEY (from_user) REFERENCES profiles(id);
alter table nudges add constraint nudges_pkey PRIMARY KEY (id);
alter table nudges add constraint nudges_to_user_fkey FOREIGN KEY (to_user) REFERENCES profiles(id);
alter table profiles add constraint profiles_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;
alter table profiles add constraint profiles_pkey PRIMARY KEY (id);
alter table settings add constraint settings_pkey PRIMARY KEY (id);
alter table settings add constraint settings_single_row CHECK ((id = 1));"
4	STANDALONE INDEXES	"CREATE UNIQUE INDEX one_gift_per_item ON public.coin_transactions USING btree (recognizes, from_user) WHERE (recognizes IS NOT NULL);
CREATE UNIQUE INDEX one_live_instance_per_chore ON public.chore_instances USING btree (chore_id) WHERE (status <> 'completed'::text);
CREATE UNIQUE INDEX one_notif_per_chore_per_kind_per_day ON public.notification_log USING btree (chore_instance_id, kind, day);
CREATE UNIQUE INDEX one_nudge_per_chore_per_day ON public.nudges USING btree (chore_instance_id, from_user, nudge_day);"
5	ROW LEVEL SECURITY (enable)	"alter table chore_instances enable row level security;
alter table chores enable row level security;
alter table coin_transactions enable row level security;
alter table notification_log enable row level security;
alter table notification_messages enable row level security;
alter table nudges enable row level security;
alter table profiles enable row level security;
alter table settings enable row level security;"
6	POLICIES	"create policy ""create instances"" on chore_instances as permissive for INSERT to authenticated with check (true);
create policy ""read instances"" on chore_instances as permissive for SELECT to authenticated using (true);
create policy ""update instances"" on chore_instances as permissive for UPDATE to authenticated using (true);
create policy ""create chores"" on chores as permissive for INSERT to authenticated with check (true);
create policy ""read chores"" on chores as permissive for SELECT to authenticated using (true);
create policy ""update chores"" on chores as permissive for UPDATE to authenticated using (true);
create policy ""read coins"" on coin_transactions as permissive for SELECT to authenticated using (true);
create policy ""read own logs"" on notification_log as permissive for SELECT to authenticated using (true);
create policy ""read messages"" on notification_messages as permissive for SELECT to authenticated using (true);
create policy ""read nudges"" on nudges as permissive for SELECT to authenticated using (true);
create policy ""send nudges"" on nudges as permissive for INSERT to authenticated with check ((from_user = auth.uid()));
create policy ""read profiles"" on profiles as permissive for SELECT to authenticated using (true);
create policy ""update own profile"" on profiles as permissive for UPDATE to authenticated using ((id = auth.uid()));
create policy ""read settings"" on settings as permissive for SELECT to authenticated using (true);
create policy ""update settings"" on settings as permissive for UPDATE to authenticated using (true);"
7	FUNCTIONS	"CREATE OR REPLACE FUNCTION public.complete_chore(instance_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  inst chore_instances%rowtype;
  ch chores%rowtype;
  cfg settings%rowtype;
  base_value int;
  final_value int;
begin
  select * into inst from chore_instances where id = instance_id;
  if not found then
    raise exception 'That chore no longer exists.';
  end if;
  if inst.status <> 'accepted' then
    raise exception 'That chore has not been accepted.';
  end if;
  if inst.accepted_by <> auth.uid() then
    raise exception 'That chore belongs to someone else.';
  end if;

  select * into ch from chores where id = inst.chore_id;
  select * into cfg from settings where id = 1;

  base_value := case ch.difficulty
    when 'easy' then cfg.coins_easy
    when 'medium' then cfg.coins_medium
    else cfg.coins_hard
  end;

  if inst.is_bounty
     and (inst.abandoned_by is null or inst.abandoned_by <> auth.uid()) then
    final_value := round(base_value * cfg.bounty_multiplier);
  else
    final_value := base_value;
  end if;

  update chore_instances
     set status = 'completed', completed_by = auth.uid(), completed_at = now()
   where id = instance_id;

  insert into coin_transactions (user_id, amount, reason, chore_instance_id, kind)
  values (auth.uid(), final_value, ch.name, instance_id, 'chore');

  -- On-demand chores go straight back on the board
  if ch.frequency = 'on_demand' and ch.is_active then
    insert into chore_instances (chore_id, due_date) values (ch.id, null);
  end if;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.create_chore(p_name text, p_difficulty text, p_frequency text, p_active_days integer[], p_due_date date)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  new_id uuid;
begin
  if auth.uid() is null then
    raise exception 'You need to be signed in.';
  end if;
  if p_name is null or length(trim(p_name)) = 0 then
    raise exception 'Give the chore a name.';
  end if;
  if p_frequency <> 'on_demand' and p_due_date is null then
    raise exception 'Pick a due date.';
  end if;

  insert into chores (name, difficulty, frequency, active_days, created_by)
  values (trim(p_name), p_difficulty, p_frequency, p_active_days, auth.uid())
  returning id into new_id;

  insert into chore_instances (chore_id, due_date)
  values (new_id, case when p_frequency = 'on_demand' then null else p_due_date end);

  return new_id;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.generate_due_chores()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  cfg settings%rowtype;
  ch record;
  last_inst record;
  anchor date;
  next_due date;
  guard int;
begin
  select * into cfg from settings where id = 1;

  -- Accepted but ignored for too long: back to the pool as a bounty
  update chore_instances
     set status = 'pool',
         is_bounty = true,
         abandoned_by = accepted_by,
         accepted_by = null,
         accepted_at = null
   where status = 'accepted'
     and due_date is not null
     and due_date < current_date - cfg.auto_release_days;

  -- Unclaimed and long overdue: worth more now
  update chore_instances
     set is_bounty = true
   where status = 'pool'
     and is_bounty = false
     and due_date is not null
     and due_date < current_date - cfg.auto_release_days;

  -- Recurring chores with nothing live: schedule the next one
  for ch in
    select c.* from chores c
     where c.is_active
       and c.frequency in ('daily','weekly','biweekly','monthly','quarterly')
       and not exists (
         select 1 from chore_instances ci
          where ci.chore_id = c.id and ci.status <> 'completed'
       )
  loop
    select * into last_inst
      from chore_instances
     where chore_id = ch.id and status = 'completed'
     order by completed_at desc nulls last
     limit 1;

    if not found then
      continue;
    end if;

    anchor := greatest(
      last_inst.due_date,
      coalesce(last_inst.completed_at::date, last_inst.due_date)
    );

    if ch.frequency = 'daily' then
      if ch.active_days is null or array_length(ch.active_days, 1) is null then
        continue;
      end if;
      next_due := anchor + 1;
      guard := 0;
      while guard < 7
        and not (extract(dow from next_due)::int = any(ch.active_days)) loop
        next_due := next_due + 1;
        guard := guard + 1;
      end loop;
    else
      next_due := last_inst.due_date;
      guard := 0;
      while next_due <= anchor and guard < 500 loop
        next_due := case ch.frequency
          when 'weekly'    then next_due + 7
          when 'biweekly'  then next_due + 14
          when 'monthly'   then (next_due + interval '1 month')::date
          else                  (next_due + interval '3 months')::date
        end;
        guard := guard + 1;
      end loop;
    end if;

    insert into chore_instances (chore_id, due_date) values (ch.id, next_due);
  end loop;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.get_decrypted_secret(secret_name text)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_value text;
begin
  select decrypted_secret into v_value
  from vault.decrypted_secrets
  where name = secret_name
  limit 1;
  return v_value;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.gift_coins(p_transaction_id uuid, p_note text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  target coin_transactions%rowtype;
  cfg settings%rowtype;
begin
  if auth.uid() is null then
    raise exception 'You need to be signed in.';
  end if;
  if p_note is null or length(trim(p_note)) = 0 then
    raise exception 'Add a note â€” that is the actual gift.';
  end if;

  select * into target from coin_transactions where id = p_transaction_id;
  if not found then
    raise exception 'That entry no longer exists.';
  end if;
  if target.user_id = auth.uid() then
    raise exception 'You cannot gift yourself coins.';
  end if;
  if target.kind = 'gift' then
    raise exception 'You cannot gift a gift.';
  end if;

  select * into cfg from settings where id = 1;

  insert into coin_transactions (user_id, from_user, amount, reason, kind, recognizes)
  values (target.user_id, auth.uid(), cfg.gift_amount, trim(p_note), 'gift', target.id);
end;
$function$
;

CREATE OR REPLACE FUNCTION public.log_adhoc_task(p_name text, p_difficulty text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  cfg settings%rowtype;
  value int;
begin
  if auth.uid() is null then
    raise exception 'You need to be signed in.';
  end if;
  if p_name is null or length(trim(p_name)) = 0 then
    raise exception 'Say what you did.';
  end if;
  if p_difficulty not in ('easy','medium','hard') then
    raise exception 'Pick a difficulty.';
  end if;

  select * into cfg from settings where id = 1;
  value := case p_difficulty
    when 'easy' then cfg.coins_easy
    when 'medium' then cfg.coins_medium
    else cfg.coins_hard
  end;

  insert into coin_transactions (user_id, amount, reason, kind)
  values (auth.uid(), value, trim(p_name), 'adhoc');
end;
$function$
;

CREATE OR REPLACE FUNCTION public.notify_via_onesignal(p_external_id text, p_title text, p_body text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_api_key text;
  v_app_id text := 'eb329c26-b880-4b2d-aba2-eb0f0f81f5e6';  -- <-- REPLACE THIS
begin
  if p_external_id is null then
    return;
  end if;

  v_api_key := get_decrypted_secret('ONESIGNAL_API_KEY');
  if v_api_key is null then
    raise notice 'ONESIGNAL_API_KEY not found in Vault yet - skipping push notification.';
    return;
  end if;

  perform net.http_post(
    url := 'https://api.onesignal.com/notifications',
    headers := jsonb_build_object(
      'Authorization', 'Key ' || v_api_key,
      'Content-Type', 'application/json'
    ),
    body := jsonb_build_object(
      'app_id', v_app_id,
      'include_aliases', jsonb_build_object('external_id', jsonb_build_array(p_external_id)),
      'target_channel', 'push',
      'headings', jsonb_build_object('en', p_title),
      'contents', jsonb_build_object('en', p_body)
    )
  );
end;
$function$
;

CREATE OR REPLACE FUNCTION public.nudge_chore(p_instance_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_status text;
  v_accepted_by uuid;
  v_due_date date;
  v_chore_name text;
  v_from_name text;
  v_msg text;
  v_today date := (now() at time zone 'America/New_York')::date;
begin
  select ci.status, ci.accepted_by, ci.due_date, c.name
    into v_status, v_accepted_by, v_due_date, v_chore_name
  from chore_instances ci
  join chores c on c.id = ci.chore_id
  where ci.id = p_instance_id;

  if v_status is null then
    raise exception 'That chore no longer exists.';
  end if;

  if v_status is distinct from 'accepted' then
    raise exception 'That chore is not currently claimed by anyone.';
  end if;

  if v_accepted_by = auth.uid() then
    raise exception 'You can''t nudge yourself.';
  end if;

  if v_due_date is null or v_due_date >= v_today then
    raise exception 'That chore is not overdue yet.';
  end if;

  insert into nudges (chore_instance_id, from_user, to_user, nudge_day)
  values (p_instance_id, auth.uid(), v_accepted_by, v_today)
  on conflict do nothing;

  if not found then
    raise exception 'Already nudged about that today.';
  end if;

  select display_name into v_from_name from profiles where id = auth.uid();

  select message into v_msg from notification_messages
  where kind = 'nudge' and audience = 'holder' and active
  order by random() limit 1;
  if v_msg is null then v_msg := '{name} is nudging you about {chore}.'; end if;

  perform notify_via_onesignal(
    v_accepted_by::text,
    'Chore Cafe',
    replace(replace(v_msg, '{name}', coalesce(v_from_name, 'Someone')), '{chore}', coalesce(v_chore_name, 'a chore'))
  );
end;
$function$
;

CREATE OR REPLACE FUNCTION public.send_notifications()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  rec record;
  v_days_overdue int;
  v_other_id uuid;
  v_holder_name text;
  v_other_name text;
  v_msg_holder text;
  v_msg_other text;
  v_body text;
  v_today date := (now() at time zone 'America/New_York')::date;
begin
  for rec in
    select ci.id as instance_id, ci.due_date, ci.accepted_by, c.name as chore_name
    from chore_instances ci
    join chores c on c.id = ci.chore_id
    where ci.status = 'accepted'
      and ci.due_date is not null
      and ci.due_date < v_today
      and (ci.snoozed_until is null or ci.snoozed_until < v_today)
  loop
    v_days_overdue := v_today - rec.due_date;

    select id into v_other_id from profiles where id <> rec.accepted_by limit 1;
    select display_name into v_holder_name from profiles where id = rec.accepted_by;
    select display_name into v_other_name from profiles where id = v_other_id;

    select message into v_msg_holder
    from notification_messages
    where kind = 'overdue' and audience = 'holder' and active
      and (min_days_overdue is null or min_days_overdue <= v_days_overdue)
    order by min_days_overdue desc nulls last
    limit 1;

    select message into v_msg_other
    from notification_messages
    where kind = 'overdue' and audience = 'other' and active
      and (min_days_overdue is null or min_days_overdue <= v_days_overdue)
    order by min_days_overdue desc nulls last
    limit 1;

    if v_msg_holder is not null then
      insert into notification_log (chore_instance_id, kind)
      values (rec.instance_id, 'overdue_holder')
      on conflict do nothing;

      if found then
        v_body := replace(replace(replace(v_msg_holder,
                    '{chore}', rec.chore_name),
                    '{name}', coalesce(v_other_name, 'them')),
                    '{days}', v_days_overdue::text);
        perform notify_via_onesignal(rec.accepted_by::text, 'Chore Cafe', v_body);
      end if;
    end if;

    if v_msg_other is not null and v_other_id is not null then
      insert into notification_log (chore_instance_id, kind)
      values (rec.instance_id, 'overdue_other')
      on conflict do nothing;

      if found then
        v_body := replace(replace(replace(v_msg_other,
                    '{chore}', rec.chore_name),
                    '{name}', coalesce(v_holder_name, 'them')),
                    '{days}', v_days_overdue::text);
        perform notify_via_onesignal(v_other_id::text, 'Chore Cafe', v_body);
      end if;
    end if;
  end loop;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.trg_notify_chore_completed()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_chore_name text;
  v_doer_name text;
  v_msg text;
  v_body text;
  r record;
begin
  if NEW.status = 'completed' and OLD.status is distinct from 'completed' then
    select name into v_chore_name from chores where id = NEW.chore_id;
    select display_name into v_doer_name from profiles where id = NEW.completed_by;

    select message into v_msg from notification_messages
    where kind = 'completed' and active order by random() limit 1;
    if v_msg is null then v_msg := '{chore} is done! Nice work, {name}.'; end if;

    v_body := replace(replace(v_msg, '{chore}', coalesce(v_chore_name, 'A chore')),
                       '{name}', coalesce(v_doer_name, 'Someone'));

    insert into notification_log (chore_instance_id, kind)
    values (NEW.id, 'completed')
    on conflict do nothing;

    if found then
      for r in select id from profiles loop
        perform notify_via_onesignal(r.id::text, 'Chore Cafe', v_body);
      end loop;
    end if;
  end if;
  return NEW;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.trg_notify_gift()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_sender_name text;
  v_msg text;
  v_body text;
begin
  if NEW.kind = 'gift' then
    select display_name into v_sender_name from profiles where id = NEW.from_user;

    select message into v_msg from notification_messages
    where kind = 'gift' and active order by random() limit 1;
    if v_msg is null then v_msg := '{name} sent you a coin gift ðŸŽ'; end if;

    v_body := replace(v_msg, '{name}', coalesce(v_sender_name, 'Someone'));

    perform notify_via_onesignal(NEW.user_id::text, 'Chore Cafe', v_body);
  end if;
  return NEW;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.trg_notify_logged()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_logger_name text;
  v_other_id uuid;
  v_msg text;
  v_body text;
begin
  if NEW.kind = 'adhoc' then
    select display_name into v_logger_name from profiles where id = NEW.user_id;
    select id into v_other_id from profiles where id <> NEW.user_id limit 1;

    select message into v_msg from notification_messages
    where kind = 'logged' and active order by random() limit 1;
    if v_msg is null then v_msg := '{name} logged {chore} off-board.'; end if;

    v_body := replace(replace(v_msg, '{name}', coalesce(v_logger_name, 'Someone')),
                       '{chore}', coalesce(NEW.reason, 'something'));

    if v_other_id is not null then
      perform notify_via_onesignal(v_other_id::text, 'Chore Cafe', v_body);
    end if;
  end if;
  return NEW;
end;
$function$
;"
8	TRIGGERS	"CREATE TRIGGER on_chore_completed AFTER UPDATE ON public.chore_instances FOR EACH ROW EXECUTE FUNCTION trg_notify_chore_completed();
CREATE TRIGGER on_gift_sent AFTER INSERT ON public.coin_transactions FOR EACH ROW EXECUTE FUNCTION trg_notify_gift();
CREATE TRIGGER on_task_logged AFTER INSERT ON public.coin_transactions FOR EACH ROW EXECUTE FUNCTION trg_notify_logged();"
9	SCHEDULED JOBS (pg_cron)	"select cron.schedule('chore-cafe-send-notifications', '0 0 * * *', 'select send_notifications();');
select cron.schedule('generate-due-chores', '5 5 * * *', ' select generate_due_chores(); ');"
