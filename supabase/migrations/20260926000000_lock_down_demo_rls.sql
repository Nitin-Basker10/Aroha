-- AROHA — lock down open demo RLS policies
--
-- WHY THIS EXISTS
-- ---------------
-- Every table in `public` shipped with a single permissive policy named
-- "demo open access":
--
--     roles = {anon, authenticated}, cmd = ALL, qual = true, with_check = true
--
-- That grants full read AND write to anyone holding the project's
-- publishable key — and on web that key ships inside the JS bundle, so it is
-- public. The live tables hold real data: personnel rows with blood group,
-- emergency contact and medical clearance, plus the family invite codes and
-- consent flags that gate satellite calls.
--
-- Every authorization check in `lib/` (station scoping, invite binding,
-- disclaimer/consent gating) runs client-side and is therefore advisory only.
-- A caller can skip the UI and hit PostgREST directly. This migration removes
-- that gap.
--
-- WHY IT IS SAFE TO APPLY BEFORE SUPABASE AUTH EXISTS
-- -------------------------------------------------
-- `auth.users` is currently empty, so there is no identity for a real policy
-- to filter on. Any policy keyed to `auth.uid()` would evaluate to false for
-- every caller, which is exactly the intent: deny by default.
--
-- RLS with no permissive policy denies everything. So dropping the demo
-- policies *is* the lockdown — no replacement policy is needed, and adding
-- one would only reopen the hole.
--
-- EFFECT ON THE APP
-- -----------------
-- `PolarDataService` is offline-first: it seeds local data and treats Supabase
-- as an additive sync layer. With cloud reads denied it logs the failure and
-- the app continues on local seed data. The demo keeps working; it simply
-- stops syncing. See `lib/services/supabase_service.dart`.
--
-- TO RE-OPEN CONTROLLED ACCESS
-- ----------------------------
-- Do this together with real authentication, never before:
--   1. Enable Supabase Auth and put a `profiles` table in place, carrying
--      `user_id -> role, linked_station_id`.
--   2. Add a SECURITY DEFINER helper, e.g.
--        create function public.current_profile()
--        returns public.profiles language sql stable security definer
--        set search_path = public as $$
--          select * from public.profiles where user_id = auth.uid()
--        $$;
--   3. Replace the dropped policies with per-table policies that filter on
--      that profile — station staff scoped to `linked_station_id`, HQ
--      unscoped, and `personnel.medical`-bearing columns split into a
--      separately-guarded table or column grant.
-- Until step 1-3 are genuinely done, deny-all is the correct posture.

begin;

-- Drop the open demo policy from every table it was applied to. Using a
-- DO block keeps this resilient if a table is added later without the policy.
do $$
declare
  t text;
begin
  foreach t in array array[
    'alerts', 'call_bookings', 'cargo_items', 'comms_messages',
    'family_invites', 'inventory_audit_logs', 'inventory_items',
    'personnel', 'resource_requests', 'resupply_cycles', 'stations'
  ]
  loop
    execute format('drop policy if exists %I on public.%I', 'demo open access', t);
    -- RLS stays enabled; with no permissive policy the table is now
    -- unreachable for both anon and authenticated roles.
    execute format('alter table public.%I enable row level security', t);
    execute format('alter table public.%I force row level security', t);
  end loop;
end
$$;

commit;

-- Verify: this should return zero rows.
--   select tablename, policyname from pg_policies where schemaname = 'public';
