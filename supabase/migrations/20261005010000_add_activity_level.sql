-- Add the required scope/officialness field without changing category.
-- Existing records are backfilled before NOT NULL is enforced.
alter table public.activities
  add column if not exists activity_level text;

update public.activities
set activity_level = case
  when lower(title) like '%looking for someone%'
    or lower(title) like '%study partner%'
    or lower(title) like '%play cards with%'
    then 'Personal'
  -- The demo activities are student-created meetups, games, and study events.
  -- They are intended for multiple participants, so Community is appropriate.
  else 'Community'
end
where activity_level is null
   or activity_level not in ('Campus-Wide', 'Organization', 'Community', 'Personal');

alter table public.activities
  alter column activity_level set not null;

alter table public.activities
  drop constraint if exists activities_activity_level_check;

alter table public.activities
  add constraint activities_activity_level_check
  check (activity_level in ('Campus-Wide', 'Organization', 'Community', 'Personal'));

-- This preserves the inspected remote view's SELECT logic and existing output
-- column order, appending activity_level as a new final column. The view uses
-- security_invoker; CREATE OR REPLACE preserves ownership and grants.
create or replace view public.activities_with_participation_data
with (security_invoker = true)
as
select id,
    creator_id,
    title,
    description,
    category,
    campus,
    latitude,
    longitude,
    starts_at,
    ends_at,
    indoor_outdoor,
    building,
    floor,
    room_or_area,
    cancelled_at,
    created_at,
    updated_at,
    ticket_status,
    max_participants,
    activity_participant_count(id) AS participant_count,
    (EXISTS ( SELECT 1
           FROM profiles_activities pa
          WHERE pa.activity_id = a.id AND pa.profile_id = auth.uid())) AS has_joined,
    creator_id = auth.uid() AS is_owner,
    is_activity_open(id) AS is_open,
    a.activity_level
   FROM activities a;
