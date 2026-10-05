-- Bonfire: migrate legacy stored value "Free Agent" -> "Wanderer".
-- This is for databases that were migrated when the no-faction status was
-- previously "Free Agent".

do $$
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'profiles'
      and column_name = 'faction'
  ) then
    -- Convert legacy values, and also eliminate any remaining NULLs.
    execute $sql$
      update public.profiles
      set faction = 'Wanderer'
      where faction is null or faction = 'Free Agent'
    $sql$;

    -- Default for new rows (idempotent).
    execute 'alter table public.profiles alter column faction set default ''Wanderer''';

    -- Swap admin constraint to require Wanderer.
    if exists (
      select 1
      from pg_constraint
      where conname = 'profiles_admin_free_agent_only'
    ) then
      execute 'alter table public.profiles drop constraint profiles_admin_free_agent_only';
    end if;

    if not exists (
      select 1
      from pg_constraint
      where conname = 'profiles_admin_wanderer_only'
    ) then
      execute $sql$
        alter table public.profiles
        add constraint profiles_admin_wanderer_only
        check (role <> 'admin' or faction = 'Wanderer')
      $sql$;
    end if;
  end if;
end $$;

