/*
	04_views.sql | Part C: Q0..Q8 (PostgreSQL 14+)
	Parameters (one-row table query_params):
	- valid_at: date of valid time (Q6)
	- known_at: moment of transaction time (Q5, Q6)
	- period_start/period_end: named period [start, end) (Q4, Q7)
	- subject_id: the tenant (Q1)
	- object_id: the apartment (Q2, Q6; NULL = all apartments)
	- today: implies current_date (Q1)
*/

set client_encoding = 'UTF8';
set timezone = 'UTC';
set search_path = rentals, public;

drop view if exists v_q8_gaps, v_q7_monthly_active, v_q6_bitemporal_point,
	v_q5_as_known_at, v_q4_period_overlap, v_q3_change_log, v_q2_role_history,
	v_q1_current_facts, v_integrity_violations cascade;

drop table if exists query_params cascade;

create table query_params(
	only_row boolean primary key default true check(only_row),
	valid_at date not null,
	known_at timestamptz not null,
	period_start date not null,
	period_end date not null,
	subject_id int references tenant(tenant_id),
	object_id int references apartment(apartment_id),
	today date not null default current_date,
	check(period_start < period_end)
);
comment on table query_params is 'non-temporal: views parameters Q1,..,Q8 (one row)';

insert into query_params (valid_at, known_at, period_start, period_end, subject_id, object_id)
values (date '2026-06-20', timestamptz '2026-06-10 12:00:00+00',
	date '2026-01-01', date '2026-07-01', 10, 1);

/*
	Q0: every row that does not respect I1, I2, I3 (and I4)
	should return zero rows on the final data
*/
create view v_integrity_violations as
--I1: same business key (tenant, apartment) never overlaps
select 'I1'::text as invariant, 'lease_version'::text as table_name,
	a.version_id as version_id_a, b.version_id as version_id_b,
	format('tenant %s / apartment %s', a.tenant_id, a.apartment_id) as business_key,
	format('valid %s overlaps %s', daterange(a.valid_from, a.valid_to), daterange(b.valid_from, b.valid_to))
	as detail
from lease_version a
join lease_version b on b.tenant_id = a.tenant_id and b.apartment_id = a.apartment_id
	and a.version_id < b.version_id
	and daterange(a.valid_from, a.valid_to) && daterange(b.valid_from, b.valid_to)
where a.tx_to = timestamptz '9999-12-31 23:59:59.999999+00'
	and b.tx_to = timestamptz '9999-12-31 23:59:59.999999+00'
union all
--I1 (business rule): an apartment has at most one tenant at a time
select 'I1', 'lease_version', a.version_id, b.version_id,
	format('apartment %s (tenants %s and %s)', a.apartment_id, a.tenant_id, b.tenant_id),
	format('valid %s overlaps %s', daterange(a.valid_from, a.valid_to), daterange(b.valid_from, b.valid_to))
from lease_version a
join lease_version b on b.apartment_id = a.apartment_id and a.tenant_id <> b.tenant_id
	and a.version_id < b.version_id
	and daterange(a.valid_from, a.valid_to) && daterange(b.valid_from, b.valid_to)
where a.tx_to = timestamptz '9999-12-31 23:59:59.999999+00'
	and b.tx_to = timestamptz '9999-12-31 23:59:59.999999+00'
union all
--I1: the rent of an apartment does not have overlapping periods
select 'I1', 'apartment_rent_version', a.version_id, b.version_id,
	format('apartment %s', a.apartment_id),
	format('valid %s overlaps %s', daterange(a.valid_from, a.valid_to), daterange(b.valid_from, b.valid_to))
from apartment_rent_version a
join apartment_rent_version b on b.apartment_id = a.apartment_id and a.version_id < b.version_id
	and daterange(a.valid_from, a.valid_to) && daterange(b.valid_from, b.valid_to)
where a.tx_to = timestamptz '9999-12-31 23:59:59.999999+00'
	and b.tx_to = timestamptz '9999-12-31 23:59:59.999999+00'
union all
--I3: a single manager at a time
select 'I3', 'apartment_manager_version', a.version_id, b.version_id,
	format('apartment %s (managers %s and %s)', a.apartment_id, a.manager_id, b.manager_id),
	format('valid %s overlaps %s', daterange(a.valid_from, a.valid_to), daterange(b.valid_from, b.valid_to))
from apartment_manager_version a
join apartment_manager_version b on b.apartment_id = a.apartment_id and a.version_id < b.version_id
	and daterange(a.valid_from, a.valid_to) && daterange(b.valid_from, b.valid_to)
where a.tx_to = timestamptz '9999-12-31 23:59:59.999999+00'
	and b.tx_to = timestamptz '9999-12-31 23:59:59.999999+00'
union all
--I2: the valid period of a lease must be covered by the union of the periods with a listed rent
select 'I2', 'lease_version', l.version_id, null::bigint,
	format('tenant %s / apartment %s', l.tenant_id, l.apartment_id),
	format('lease %s is not covered by listed-rent periods %s', daterange(l.valid_from, l.valid_to),
		coalesce(c.coverage::text, 'none'))
from lease_version l
left join (select apartment_id, range_agg(daterange(valid_from, valid_to)) as coverage
			from apartment_rent_version
			where tx_to = timestamptz '9999-12-31 23:59:59.999999+00'
			group by apartment_id) c on c.apartment_id = l.apartment_id
where l.tx_to = timestamptz '9999-12-31 23:59:59.999999+00'
	and not coalesce(c.coverage @> daterange(l.valid_from, l.valid_to), false)
union all
--I4: immutable history. A closed row must be closed by a registered transaction, never in the future
select 'I4', h.table_name, h.version_id, null::bigint,
	format('version_id %s', h.version_id),
	case when h.tx_from > sim_now() then format('tx_from %s is in the future', h.tx_from)
		when h.tx_to > sim_now() then format('tx_to %s is in the future', h.tx_to)
		else format('tx_to %s is not the time of any registered transaction', h.tx_to) end
from (select 'lease_version'::text as table_name, version_id, tx_from, tx_to from lease_version
	union all select 'apartment_manager_version', version_id, tx_from, tx_to from apartment_manager_version
	union all select 'apartment_rent_version', version_id, tx_from, tx_to from apartment_rent_version) h
where h.tx_from > sim_now()
	or (h.tx_to <> timestamptz '9999-12-31 23:59:59.999999+00'
		and (h.tx_to > sim_now()
			or not exists (select 1 from tx_registry r where r.tx_time = h.tx_to)));

--Q1: current facts of a tenant: valid today and current in TT
create view v_q1_current_facts as
select t.tenant_id, t.name as tenant_name,
	a.apartment_id, a.adress,
	l.valid_from as lease_from, l.valid_to as lease_to, l.deposit_eur,
	r.rent_eur as listed_rent_eur,
	m.name as manager_name
from query_params p
join tenant t on t.tenant_id = p.subject_id
join lease_version l on l.tenant_id = t.tenant_id
	and l.valid_from <= p.today and p.today < l.valid_to
	and l.tx_to = timestamptz '9999-12-31 23:59:59.999999+00'
join apartment a on a.apartment_id = l.apartment_id
left join apartment_rent_version r on r.apartment_id = l.apartment_id
	and r.valid_from <= p.today and p.today < r.valid_to
	and r.tx_to = timestamptz '9999-12-31 23:59:59.999999+00'
left join apartment_manager_version mv on mv.apartment_id = l.apartment_id
	and mv.valid_from <= p.today and p.today < mv.valid_to
	and mv.tx_to = timestamptz '9999-12-31 23:59:59.999999+00'
left join property_manager m on m.manager_id = mv.manager_id;

--Q2: full history of the managers of an apartment, as known today, adjacent periods merged
create view v_q2_role_history as
with cur as(
	select v.apartment_id, v.manager_id, v.valid_from, v.valid_to
	from apartment_manager_version v
	cross join query_params p
	where v.tx_to = timestamptz '9999-12-31 23:59:59.999999+00'
		and (p.object_id is null or v.apartment_id = p.object_id)
), flagged as(
	select c.*,
		case when lag(manager_id) over w = manager_id and lag(valid_to) over w = valid_from
			then 0 else 1 end as starts_new_tenure
	from cur c
	window w as (partition by apartment_id order by valid_from)
), islands as(
	select f.*, sum(starts_new_tenure) over (partition by apartment_id order by valid_from)
		as tenure_no
	from flagged f
)
select i.apartment_id, i.manager_id, m.name as manager_name,
	min(i.valid_from) as tenure_from,
	max(i.valid_to) as tenure_to,
	case when max(i.valid_to) = date '9999-12-31' then null
		else max(i.valid_to) - min(i.valid_from) end as tenure_days,
	(max(i.valid_to) = date '9999-12-31') as ongoing,
	count(*) as versions_merged
from islands i
join property_manager m on m.manager_id = i.manager_id
group by i.apartment_id, i.manager_id, m.name, i.tenure_no;

/*
	Q3: late entries (E3), proactive entries (E2) and corrections (E4), classified, with delay in days.
	For each new row n we look in the same table, on the same key, for the old row o that the
	same transaction closed (o.tx_to = n.tx_from) and that overlaps n in valid time.
	Limitation: two transactions with the same tx_time on the same key would be ambiguous.
*/
create view v_q3_change_log as
with chg as(
	select 'lease_version'::text as tbl, v.version_id, v.tx_id, v.tx_from, v.tx_to, v.valid_from, v.valid_to,
		format('tenant %s / apartment %s', v.tenant_id, v.apartment_id) as bkey,
		format('deposit %s eur', v.deposit_eur) as val
	from lease_version v
	union all
	select 'apartment_manager_version', v.version_id, v.tx_id, v.tx_from, v.tx_to, v.valid_from, v.valid_to,
		format('apartment %s', v.apartment_id), 'manager ' || m.name
	from apartment_manager_version v join property_manager m on m.manager_id = v.manager_id
	union all
	select 'apartment_rent_version', v.version_id, v.tx_id, v.tx_from, v.tx_to, v.valid_from, v.valid_to,
		format('apartment %s', v.apartment_id), format('rent %s eur', v.rent_eur)
	from apartment_rent_version v
), j as(
	select n.*, r.reason, (n.tx_from at time zone 'UTC')::date as tx_date,
		o.version_id as old_id, o.val as old_val, o.valid_from as old_from, o.valid_to as old_to
	from chg n
	join tx_registry r on r.tx_id = n.tx_id
	left join lateral (
		select c.* from chg c
		where c.tbl = n.tbl and c.bkey = n.bkey and c.tx_to = n.tx_from
			and daterange(c.valid_from, c.valid_to) && daterange(n.valid_from, n.valid_to)
		order by least(c.valid_to, n.valid_to) - greatest(c.valid_from, n.valid_from) desc, c.version_id
		limit 1) o on true
	where n.tx_id <> (select tx_id from tx_registry order by tx_time, tx_id limit 1)
	--without E1
), k as(
	select j.*, (tx_date - valid_from) as delay_days,
		case
			when old_id is not null and reason ~* 'correct' then
				'E4 correction'
			when old_id is not null and old_val = val and old_from <= valid_from
				and valid_to <= old_to then
				null --carry-over/end/split
			when old_id is not null and valid_from = old_from and valid_to = old_to then
				'E4 correction'
			when old_id is not null and old_val = val and valid_from = old_from then
				'E4 correction'
			when (tx_date - valid_from) >= 7 then
				'E3 late entry'
			when valid_from > tx_date then
				'E2 proactive entry'
		end as event_class
	from j
)
select k.event_class, k.tbl as table_name, k.bkey as business_key,
	k.tx_id, k.tx_from as recorded_at, k.reason, k.valid_from, k.delay_days,
	case when k.delay_days > 0 then 'late' when k.delay_days < 0 then 'ahead' else
		'same day' end as timing,
	k.old_val as old_value,
	case when k.old_id is not null then daterange(k.old_from, k.old_to)::text end as old_period,
	k.val as new_value,
	daterange(k.valid_from, k.valid_to)::text as new_period,
	case when k.tx_to = timestamptz '9999-12-31 23:59:59.999999+00' then 'current'
		when exists (select 1 from chg s where s.tbl = k.tbl and s.bkey = k.bkey
			and s.tx_from = k.tx_to and daterange(s.valid_from, s.valid_to) &&
			daterange(k.valid_from, k.valid_to))
			then 'superseded'
		else 'retracted' end as row_status
from k
where k.event_class is not null;

/*
	Q4: valid contracts in [period_start, period_end) as known today
	'at least one time' (overlap) vs 'throughout' (containment).
	Dimension VT.
*/
create view v_q4_period_overlap as
select t.tenant_id, t.name as tenant_name, l.apartment_id,
	l.valid_from, l.valid_to, p.period_start, p.period_end,
	(l.valid_from < p.period_end and p.period_start < l.valid_to) as at_some_point, --overlap
	(l.valid_from <= p.period_start and p.period_end <= l.valid_to) as throughout --containment
from query_params p
join lease_version l on l.tx_to = timestamptz '9999-12-31 23:59:59.999999+00'
	and l.valid_from < p.period_end and p.period_start < l.valid_to
join tenant t on t.tenant_id = l.tenant_id;

/*
	Q5: whole relationship table as the database knew it at known_at.
	Dimension TT
*/
create view v_q5_as_known_at as
select l.version_id, l.tenant_id, t.name as tenant_name, l.apartment_id, l.deposit_eur,
	l.valid_from, l.valid_to, l.tx_from, l.tx_to, l.tx_id, p.known_at
from query_params p
join lease_version l on l.tx_from <= p.known_at and p.known_at < l.tx_to
join tenant t on t.tenant_id = l.tenant_id;

/*
	Q6: bitemporal point query - facts valid at valid_at, as known at known_at.
	manager - rent - lease
*/
create view v_q6_bitemporal_point as
select 'manager'::text as fact_type, v.apartment_id, m.name as answer,
	v.valid_from, v.valid_to, v.tx_from, v.tx_to, p.valid_at, p.known_at
from query_params p
join apartment_manager_version v on v.valid_from <= p.valid_at and p.valid_at < v.valid_to
	and v.tx_from <= p.known_at and p.known_at < v.tx_to
	and (p.object_id is null or v.apartment_id = p.object_id)
join property_manager m on m.manager_id = v.manager_id
union all
select 'rent', v.apartment_id, v.rent_eur::text || ' eur',
	v.valid_from, v.valid_to, v.tx_from, v.tx_to, p.valid_at, p.known_at
from query_params p
join apartment_rent_version v on v.valid_from <= p.valid_at and p.valid_at < v.valid_to
	and v.tx_from <= p.known_at and p.known_at < v.tx_to
	and (p.object_id is null or v.apartment_id = p.object_id)
union all
select 'lease', v.apartment_id, t.name, v.valid_from, v.valid_to,
	v.tx_from, v.tx_to, p.valid_at, p.known_at
from query_params p
join lease_version v on v.valid_from <= p.valid_at and p.valid_at < v.valid_to
	and v.tx_from <= p.known_at and p.known_at < v.tx_to
	and (p.object_id is null or v.apartment_id = p.object_id)
join tenant t on t.tenant_id = v.tenant_id;

/*
	Q7: number of active leases per month and apartment, as known today.
	Calendar = recursive CTE; months with zero still appear.
*/
create view v_q7_monthly_active as
with recursive cal(month_start) as(
	select date_trunc('month', p.period_start)::date from query_params p
	union all
	select (c.month_start + interval '1 month')::date
	from cal c cross join query_params p
	where (c.month_start + interval '1 month')::date < p.period_end
)
select a.apartment_id, c.month_start, count(l.version_id) as active_leases
from cal c
cross join apartment a
left join lease_version l on l.apartment_id = a.apartment_id
	and l.tx_to = timestamptz '9999-12-31 23:59:59.999999+00'
	and l.valid_from < (c.month_start + interval '1 month')::date
	and c.month_start < l.valid_to
group by a.apartment_id, c.month_start;

/*
	Q8: gaps between consecutive valid periods of the same pair (tenant, apartment).
	LAG over valid_to.
*/
create view v_q8_gaps as
select x.tenant_id, t.name as tenant_name, x.apartment_id, x.prev_to as left_on,
	x.valid_from as returned_on,
	x.valid_from - x.prev_to as gap_days
from (select l.tenant_id, l.apartment_id, l.valid_from, l.valid_to,
	lag(l.valid_to) over (partition by l.tenant_id, l.apartment_id order by l.valid_from)
	as prev_to
	from lease_version l
	where l.tx_to = timestamptz '9999-12-31 23:59:59.999999+00') x
join tenant t on t.tenant_id = x.tenant_id
where x.prev_to is not null and x.valid_from > x.prev_to;