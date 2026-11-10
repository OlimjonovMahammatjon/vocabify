-- Migration: Account Deletion (Google Play Store compliance)
-- Allows authenticated users to permanently delete their own account and all associated data.

create or replace function public.delete_user_account()
returns void
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  -- Delete from auth.users. Foreign key constraints with ON DELETE CASCADE
  -- will automatically remove profiles, decks, cards, and reviews.
  delete from auth.users where id = v_user_id;
end;
$$;

revoke all on function public.delete_user_account() from public;
grant execute on function public.delete_user_account() to authenticated;
