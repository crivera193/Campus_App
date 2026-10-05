-- Bonfire: allow authenticated users to use the activity participant count
-- function through the activities participation view.

grant execute on function public.activity_participant_count(uuid) to authenticated;
