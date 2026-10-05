-- Bonfire: Allow a signed-in user to update their own profiles.faction.
-- This matches the existing model where profiles rows are keyed by auth user id.
-- It keeps write scope minimal by granting update only on the `faction` column.

do $$
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'profiles'
      and column_name = 'faction'
  ) then
    -- Best-effort: ensure authenticated users can update only the faction column.
    execute 'grant update (faction) on table public.profiles to authenticated';

    -- If RLS is enabled on profiles (common in Supabase), ensure there is an update
    -- policy that permits a user to update only their own row.
    if not exists (
      select 1
      from pg_policies
      where schemaname = 'public'
        and tablename = 'profiles'
        and policyname = 'profiles_update_own_row'
    ) then
      execute $sql$
        create policy profiles_update_own_row
        on public.profiles
        for update
        to authenticated
        using (auth.uid() = id)
        with check (auth.uid() = id)
      $sql$;
    end if;
  end if;
end $$;

