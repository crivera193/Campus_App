-- Bonfire: Make faction explicitly stored and defaulted to "Wanderer".
-- - Does NOT touch profiles.college.
-- - Sets default for new rows.
-- - Backfills existing NULL faction values to "Wanderer" (only when faction exists).
-- - Forces admins to remain "Wanderer" using the existing profiles.role = 'admin'.

do $$
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'profiles'
      and column_name = 'faction'
  ) then
    -- Backfill existing users who have not selected a faction yet.
    execute 'update public.profiles set faction = ''Wanderer'' where faction is null';

    -- Default for new rows.
    execute 'alter table public.profiles alter column faction set default ''Wanderer''';

    -- Force admins to be Wanderer (best-effort; only if role column exists).
    if exists (
      select 1
      from information_schema.columns
      where table_schema = 'public'
        and table_name = 'profiles'
        and column_name = 'role'
    ) then
      execute 'update public.profiles set faction = ''Wanderer'' where role = ''admin''';

      -- Ensure admins cannot be assigned to a faction.
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

    -- Explicitly store faction status (Wanderer instead of NULL).
    execute 'alter table public.profiles alter column faction set not null';
  end if;
end $$;
