set client_encoding = 'utf8';
set timezone = 'utc';
set search_path to rentals, public;
reset app.sim_now;

do $$ 
begin 
    raise notice ' q0 v_integrity_violations: 0 rows';
end $$;

select * from v_integrity_violations order by invariant, table_name, version_id_a;
select count(*) as violations_on_final_data from v_integrity_violations;

--broke rows just in this trasaction
--extract the EXCLUDE constraints and insert wrong rows
--show that the view catchesthem, then the rollback brings everything at normal
begin;

do $$ 
begin 
    raise notice ' dropping exclude constraints to simulate invalid data...';
end $$;

alter table lease_version drop constraint ex_lease_i1;
alter table lease_version drop constraint ex_lease_one_tenant_per_apt;
alter table apartment_manager_version drop constraint ex_manager_i3;
alter table apartment_rent_version drop constraint ex_rent_i1;

--I1: duble a current contract => overlaps periods of the same key
do $$ 
begin 
    raise notice ' i1: double a current contract (overlapping periods)...';
end $$;
insert into lease_version(
	tenant_id,
	apartment_id,
	deposit_eur,
	valid_from,
	valid_to,
	tx_from,
	tx_id)
select tenant_id, apartment_id, deposit_eur, valid_from, valid_to, tx_from, tx_id
from lease_version where tx_to = timestamptz '9999-12-31 23:59:59.999999+00'
order by version_id limit 1;

--I2: contract in 1990
do $$ 
begin 
    raise notice ' i2: contract in 1990...';
end $$;
insert into lease_version (
	tenant_id, 
	apartment_id, 
	deposit_eur, 
	valid_from, 
	valid_to, 
	tx_from, 
	tx_id)
select tenant_id, apartment_id, deposit_eur, date '1990-01-01', date '1990-02-01', tx_from, tx_id
from lease_version where tx_to = timestamptz '9999-12-31 23:59:59.999999+00' 
order by version_id limit 1;

--I3 :double a manager row; tho managers at the same time
do $$ 
begin 
    raise notice ' i3: double a manager row (two managers at the same time)...';
end $$;
insert into apartment_manager_version (
	apartment_id, 
	manager_id, 
	valid_from, 
	valid_to, 
	tx_from, 
	tx_id)
select apartment_id, manager_id, valid_from, valid_to, tx_from, tx_id
from apartment_manager_version where tx_to = timestamptz '9999-12-31 23:59:59.999999+00' order by version_id limit 1;

--I1: double a current lease
do $$ 
begin 
    raise notice ' i1: double a current lease (apartment_rent_version)...';
end $$;
insert into apartment_rent_version (
	apartment_id, 
	rent_eur, 
	valid_from,
	valid_to,
	tx_from, 
	tx_id)
select apartment_id, rent_eur, valid_from, valid_to, tx_from, tx_id
from apartment_rent_version where tx_to = timestamptz '9999-12-31 23:59:59.999999+00' order by version_id limit 1;

--I4: move tx_to of a closed row in the future
do $$ 
begin 
    raise notice ' i4: move tx_to of a closed row in the future...';
end $$;
update lease_version set tx_to = tx_to + interval '100 years'
where version_id = (select version_id from lease_version
					where tx_to <> timestamptz '9999-12-31 23:59:29.999999+00'
					order by version_id limit 1);

do $$ 
begin 
    raise notice ' checking integrity violations in v_integrity_violations:';
end $$;
select invariant, table_name, business_key, detail
from v_integrity_violations order by invariant, table_name, version_id_a;

select invariant, count(*) as rows_found from v_integrity_violations
group by invariant order by invariant;

do $$ 
begin 
    raise notice ' executing rollback...';
end $$;
rollback;

do $$ 
begin 
    raise notice ' checking violations after rollback:';
end $$;
select count(*) as violations_after_rollback from v_integrity_violations;

-- queries and demonstrations

do $$ 
begin 
    raise notice ' q1 current facts of tenant 10';
end $$;
update query_params set subject_id = 10, today = current_date;
select * from v_q1_current_facts;

do $$ 
begin 
    raise notice ' q2 history of the manager of apartment 1, as known as today';
end $$;
update query_params set object_id = 1;
select * from v_q2_role_history order by apartment_id, tenure_from;

--Colescing demonstration: delete last period in two rows of the same manager
--The view should union them in one
do $$ 
begin 
    raise notice ' coalescing demonstration: split a tenure into two adjacent versions';
end $$;

begin;
set local app.sim_now = '2099-01-01 12:00:00+00';

insert into tx_registry (tx_time, author, reason)
values (sim_now(), 'test', 'test split a tenure into two adjacent versions of the same manager');

create temp table _last on commit drop as
  select * from apartment_manager_version
  where apartment_id = 1 and tx_to = timestamptz '9999-12-31 23:59:59.999999+00'
  order by valid_from desc limit 1;

update apartment_manager_version set tx_to = sim_now() where version_id = (select version_id from _last);

insert into apartment_manager_version (
	apartment_id, 
	manager_id, 
	valid_from, 
	valid_to, 
	tx_from, 
	tx_id)
select apartment_id, manager_id, valid_from, valid_from + 30, rentals.sim_now(), (select max(tx_id) from tx_registry) from _last
union all
select apartment_id, manager_id, valid_from + 30, valid_to, rentals.sim_now(), (select max(tx_id) from tx_registry) from _last;

do $$ 
begin 
    raise notice ' raw current rows (the last tenure is split in two adjacent rows)';
end $$;
select version_id, manager_id, valid_from, valid_to
from apartment_manager_version
where apartment_id = 1 and tx_to = timestamptz '9999-12-31 23:59:59.999999+00' order by valid_from;

do $$ 
begin 
    raise notice ' q2 over the same data: adjacent same-holder rows are coalesced';
end $$;
select * from v_q2_role_history order by apartment_id, tenure_from;

rollback;

do $$ 
begin 
    raise notice ' q3 late entries (e3), proactive (e2) and corrections (e4), clasified';
end $$;
select event_class, table_name, business_key, tx_id, recorded_at, valid_from, delay_days, timing,
	old_value, old_period, new_value, new_period, row_status
from v_q3_change_log order by recorded_at, tx_id, table_name, business_key;

select event_class, count(*) as events from v_q3_change_log group by event_class 
order by event_class;

do $$ 
begin 
    raise notice ' q4 valid contracts [2026-01-01, 2026-07-01)';
end $$;
update query_params set period_start = date '2026-01-01', period_end = date '2026-07-01';
select tenant_id, tenant_name, apartment_id, valid_from, valid_to, at_some_point,
	throughout
from v_q4_period_overlap order by apartment_id, valid_from;

select count(*) filter (where at_some_point) as at_some_point,
	count(*) filter (where throughout) as throughout
from v_q4_period_overlap;

do $$ 
begin 
    raise notice ' q5 contract table as the database belived at 2026-03-01';
end $$;
update query_params set known_at = timestamptz '2026-03-01 12:00:00+00';
select count(*) as lease_rows_known_on_2026_03_01 from v_q5_as_known_at;
select version_id, tenant_id, apartment_id, deposit_eur, valid_from, valid_to,
	tx_from, tx_to
from v_q5_as_known_at order by apartment_id, valid_from, tenant_id;

--same table today, to see the difference
do $$ 
begin 
    raise notice ' same table today, to see the difference';
end $$;
update query_params set known_at = now();
select count(*) as lease_rows_known_today from v_q5_as_known_at;

do $$ 
begin 
    raise notice ' q5 bitemporal - an apartment, a valid_at, three moments -> three corect responses';
end $$;

--E7 case
--2026-01-01 -> manager 5 | 2026-06-10 -> manager 2 (wrong) | 2026-06-16 -> manager 3 (corrected)
update query_params set object_id = 1, valid_at = date '2026-06-20', 
	known_at = timestamptz '2026-01-01 12:00:00+00';
select 'known 2026-01-01' as as_known_on, fact_type, apartment_id, answer, valid_from,
	valid_to, tx_from, tx_to
from v_q6_bitemporal_point where fact_type = 'manager';

update query_params set known_at = timestamptz '2026-06-16 12:00:00+00';
select 'known 2026-06-16' as as_known_on, fact_type, apartment_id, answer, valid_from,
	valid_to, tx_from, tx_to
from v_q6_bitemporal_point where fact_type = 'manager';

--Lease case at 2026-08-01: nothing -> 975 (E2) -> 950 (E4, corrected)
update query_params set valid_at = date '2026-08-01', known_at = timestamptz '2025-12-01 12:00:00+00';
select 'known 2025-12-01' as as_known_on, count (*) as rows_found, max(answer)
	as answer
from v_q6_bitemporal_point where fact_type = 'rent';

update query_params set known_at = timestamptz '2026-01-10 12:00:00+00';
select 'known 2026-01-10' as as_known_on, fact_type, apartment_id, answer, valid_from, valid_to
from v_q6_bitemporal_point where fact_type = 'rent';

update query_params set known_at = timestamptz '2026-03-01 12:00:00+00';
select 'known 2026-03-01' as as_known_on, fact_type, apartment_id, answer, valid_from, valid_to
from v_q6_bitemporal_point where fact_type = 'rent';

do $$ 
begin 
    raise notice ' q7 active contracts per month and apartment';
end $$;
update query_params set period_start = date '2026-01-01', period_end = date '2027-01-01';
select apartment_id, month_start, active_leases 
from v_q7_monthly_active order by apartment_id, month_start;

select count (*) as apartment_months, count(*) filter (where active_leases = 0)
	as months_with_zero
from v_q7_monthly_active;

do $$ 
begin 
    raise notice ' q8 gaps between valid periods of the same pair (tenant, apartment)';
end $$;
select * from v_q8_gaps order by tenant_id, apartment_id, left_on;

do $$ 
begin 
    raise notice ' final check: q0 on final data';
end $$;
select count(*) as violations_on_final_data from v_integrity_violations;