-- Bonfire: Add a new, independent faction column.
-- Note: This intentionally does NOT touch profiles.college or copy values over.

alter table public.profiles
  add column if not exists faction text;

