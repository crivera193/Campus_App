-- Allow signed-in users to see usernames for participants in an activity
-- already visible in the Events list without granting broader profile access.
create or replace function public.activity_participant_usernames(
  p_activity_id uuid
)
returns table (username text)
language sql
stable
security definer
set search_path = ''
as $function$
  select p.username
  from public.activities as a
  join public.profiles_activities as pa
    on pa.activity_id = a.id
  join public.profiles as p
    on p.id = pa.profile_id
  where a.id = p_activity_id
    and a.ticket_status = 'Approved'::public.activity_form_status
    and a.cancelled_at is null
    and a.ends_at >= now() - interval '3 days'
    and p.username is not null
    and btrim(p.username) <> ''
  order by p.username;
$function$;

-- Expose only this username-only function to authenticated app users.
revoke all on function public.activity_participant_usernames(uuid) from public;
revoke all on function public.activity_participant_usernames(uuid) from anon;
grant execute on function public.activity_participant_usernames(uuid) to authenticated;
