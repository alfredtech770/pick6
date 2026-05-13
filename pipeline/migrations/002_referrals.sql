-- 002_referrals.sql
-- Adds position-jumping referral tracking to the waitlist.
--
-- Mechanic:
--   1. Every signup gets a unique referral_code + ordinal position.
--   2. A share link `pick1.live/?r=<code>` attributes new signups to a referrer.
--   3. Each successful referral bumps the referrer up the queue by
--      POSITION_JUMP_PER_REFERRAL slots (default 100) and increments their
--      referrals_count.
--   4. Reward tiers (handled in the UI, not the schema):
--        3 referrals  → 1 month free Pro at launch
--       10 referrals  → 1 year free Pro
--       25 referrals  → lifetime Pro
--
-- Why a stored proc instead of inline JS queries:
--   The signup flow has to do four things atomically — insert the new row,
--   assign a position from a global sequence, credit the referrer, and return
--   the new code+position to the API caller. Doing this as 4 separate
--   PostgREST calls opens race windows (two concurrent signups can grab the
--   same position via SELECT count(*)+1, or a referrer credit can be lost if
--   the insert succeeds but the UPDATE fails). One server-side function call
--   collapses all of it into one transaction.
--
-- Run once against your Supabase database:
--   psql "$DATABASE_URL" -f 002_referrals.sql
-- or paste into the SQL editor in the Supabase dashboard.

CREATE EXTENSION IF NOT EXISTS pgcrypto; -- gen_random_bytes()

-- Make sure the base table exists. (subscribe.js creates rows here from the
-- waitlist signup; this migration just adds the referral columns.)
CREATE TABLE IF NOT EXISTS public.waitlist_attribution (
  email      text PRIMARY KEY,
  phone      text,
  utm_source text,
  utm_medium text,
  utm_campaign text,
  utm_content text,
  utm_term   text,
  fbp        text,
  fbc        text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.waitlist_attribution
  ADD COLUMN IF NOT EXISTS first_name       text,
  ADD COLUMN IF NOT EXISTS referral_code    text UNIQUE,
  ADD COLUMN IF NOT EXISTS referred_by_code text,
  ADD COLUMN IF NOT EXISTS position         bigint,
  ADD COLUMN IF NOT EXISTS referrals_count  integer NOT NULL DEFAULT 0;

CREATE INDEX IF NOT EXISTS waitlist_referral_code_idx
  ON public.waitlist_attribution (referral_code);
CREATE INDEX IF NOT EXISTS waitlist_position_idx
  ON public.waitlist_attribution (position);
CREATE INDEX IF NOT EXISTS waitlist_referrals_count_desc_idx
  ON public.waitlist_attribution (referrals_count DESC);

-- Global sequence for assigning positions atomically. Each call to nextval()
-- is concurrency-safe and never reused — perfect for ordinal-position
-- semantics, avoiding the SELECT count(*)+1 race.
CREATE SEQUENCE IF NOT EXISTS public.waitlist_position_seq START 1;

-- ── upsert_waitlist_signup ───────────────────────────────────────────────
-- Idempotent signup with position-jump referral credit.
--
-- Returns one row: (email, referral_code, position, is_new). When is_new is
-- false the caller knows the email was already on the list and can fall back
-- to "you're already in" messaging instead of crediting a referrer twice.
--
-- Note on Postgres security: this function runs with SECURITY INVOKER (the
-- default), so the service-role key the API uses is what bypasses RLS. The
-- anon key cannot call this directly — that's intentional, the API endpoint
-- is the only signup path.
CREATE OR REPLACE FUNCTION public.upsert_waitlist_signup(
  p_email             text,
  p_first_name        text DEFAULT NULL,
  p_referred_by_code  text DEFAULT NULL,
  p_phone             text DEFAULT NULL,
  p_utm               jsonb DEFAULT NULL,
  p_fbp               text DEFAULT NULL,
  p_fbc               text DEFAULT NULL
)
-- Output columns are prefixed `out_*` to avoid two collisions:
--   1. `position` is a reserved keyword in RETURNS TABLE syntax.
--   2. An unprefixed `referral_code` clashes with the table column of the
--      same name when referenced inside the proc body (PL/pgSQL ambiguity
--      error: "It could refer to either a PL/pgSQL variable or a table
--      column"). The browser-facing /api/subscribe response normalizes
--      these to clean names (`position`, `referralCode`, `isNew`).
RETURNS TABLE (
  out_email           text,
  out_referral_code   text,
  out_queue_position  bigint,
  out_is_new          boolean
)
LANGUAGE plpgsql
AS $$
DECLARE
  v_email_norm        text := lower(trim(p_email));
  v_first_name_norm   text := nullif(trim(p_first_name), '');
  v_referred_by_norm  text := nullif(trim(p_referred_by_code), '');
  v_existing          record;
  v_referral_code     text;
  v_position          bigint;
  v_attempt           integer := 0;
  -- How many positions each successful referral lifts the referrer.
  -- Tuning knob: bigger number = more aggressive viral incentive.
  v_jump_per_referral integer := 100;
BEGIN
  -- 1. Email-already-exists short-circuit.
  SELECT wa.email AS wa_email, wa.referral_code AS wa_code, wa.position AS wa_pos
    INTO v_existing
    FROM public.waitlist_attribution wa
   WHERE wa.email = v_email_norm;

  IF FOUND THEN
    -- Return the existing row. Don't re-credit the referrer (prevents
    -- "delete + re-signup with the same link" gaming).
    RETURN QUERY SELECT v_existing.wa_email,
                        v_existing.wa_code,
                        v_existing.wa_pos,
                        false;
    RETURN;
  END IF;

  -- 2. Generate a unique referral code.
  --    Format:  "<firstname-slug>-<4 hex chars>"  e.g. "noa-9f3a"
  --    Falls back to "user-<8 hex>" after 10 collision retries (cosmic ray
  --    territory — we have a unique index, this is defense in depth).
  LOOP
    v_attempt := v_attempt + 1;
    v_referral_code :=
      coalesce(
        nullif(regexp_replace(lower(coalesce(v_first_name_norm, '')), '[^a-z0-9]+', '', 'g'), ''),
        'guest'
      )
      || '-'
      || encode(gen_random_bytes(2), 'hex');

    -- Qualify column with table alias so it can't be confused with a
    -- local variable named `referral_code` (PL/pgSQL would error
    -- otherwise).
    EXIT WHEN NOT EXISTS (
      SELECT 1 FROM public.waitlist_attribution wa
       WHERE wa.referral_code = v_referral_code
    );

    IF v_attempt > 10 THEN
      v_referral_code := 'user-' || encode(gen_random_bytes(4), 'hex');
      EXIT;
    END IF;
  END LOOP;

  -- 3. Assign next position from the global sequence.
  v_position := nextval('public.waitlist_position_seq');

  -- 4. Insert the row.
  INSERT INTO public.waitlist_attribution (
    email, first_name, referral_code, referred_by_code, position,
    phone, utm_source, utm_medium, utm_campaign, utm_content, utm_term,
    fbp, fbc
  ) VALUES (
    v_email_norm,
    v_first_name_norm,
    v_referral_code,
    v_referred_by_norm,
    v_position,
    nullif(trim(p_phone), ''),
    p_utm->>'utm_source',
    p_utm->>'utm_medium',
    p_utm->>'utm_campaign',
    p_utm->>'utm_content',
    p_utm->>'utm_term',
    nullif(trim(p_fbp), ''),
    nullif(trim(p_fbc), '')
  );

  -- 5. If they came via a referral link, credit the referrer.
  --    Position can never drop below 1 (the original first signup).
  IF v_referred_by_norm IS NOT NULL THEN
    UPDATE public.waitlist_attribution
       SET referrals_count = referrals_count + 1,
           position = greatest(1, coalesce(position, 1) - v_jump_per_referral)
     WHERE waitlist_attribution.referral_code = v_referred_by_norm;
  END IF;

  RETURN QUERY SELECT v_email_norm, v_referral_code, v_position, true;
END;
$$;

-- ── Backfill positions for pre-migration rows ────────────────────────────
-- If any rows exist without a position, assign one based on created_at order.
-- This keeps the leaderboard stable for early signups (pre-launch dev tests).
DO $$
DECLARE
  r           record;
  v_position  bigint;
BEGIN
  FOR r IN
    SELECT email FROM public.waitlist_attribution
     WHERE position IS NULL
     ORDER BY created_at ASC, email ASC
  LOOP
    v_position := nextval('public.waitlist_position_seq');
    UPDATE public.waitlist_attribution
       SET position = v_position
     WHERE email = r.email;
  END LOOP;
END $$;
