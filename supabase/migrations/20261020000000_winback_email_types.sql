-- Win back has never sent an email: every claim is rejected by this CHECK.
--
-- winback-email was rewritten on 2026-09-01 into a three touch sequence that
-- logs as winback_t1_payment / winback_t1_churned / winback_t1_trial /
-- winback_t2 / winback_t3. The CHECK on email_log still only allows the old
-- single touch names (winback_payment, winback_trial, winback_churned), so
-- every claim upsert returns 400 (seen in the edge logs on 2026-10-19 16:00)
-- and the person is skipped. The cron reports success every day and nothing
-- leaves. A dry run on 2026-10-20 found 447 recipients across T1.
--
-- NOT APPLIED. Applying this switches win back ON: the next 16:00 UTC run of
-- cron job 5 (pick1-winback-email, dailyCap 200) sends live emails to lapsed
-- subscribers. Apply only once Ethan has approved the first live send.
--
-- The old names stay allowed so historical rows (none exist today) remain valid.

alter table public.email_log drop constraint email_log_email_type_check;
alter table public.email_log add constraint email_log_email_type_check
  check (email_type = any (array[
    'welcome', 'daily_pick', 'newsletter', 'payment_failed', 'renewal_off_save',
    'winback_payment', 'winback_trial', 'winback_churned',
    'winback_t1_payment', 'winback_t1_churned', 'winback_t1_trial',
    'winback_t2', 'winback_t3'
  ]));
