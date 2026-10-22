/*
	Native PostgreSQL temporal constraints for valid time:
	- WITHOUT OVERLAPS on a range column
	- PERIOD foreign keys for full-period coverage
	Does not provide native SYSTEM TIME / FOR SYSTEM_TIME AS OF queries. TT predicates
	(tx_from <= known_at and known_at < tx_to) therefore remain explicit in Q5, Q6.
	The A2 tables are snapchots of rows current in transaction time when this script runs.
	They demonstrate native valid-time constraints without applying WITHOUT OVERLAPS
	to the append-only bitemporal history, where older TT versions may legitimately
	overlap VT.
*/


set timezone = 'UTC';
set search_path = rentals, public;

create extension if not exists btree_gist;

--we can re-run it
drop view if exists v_a2_q1_current_facts;
drop view if exists v_a2_q5_as_known;
drop view if exists v_a2_q6_bitemporal_points;
drop table if exists a2_current_lease cascade;
drop table if exists a2_current_rent cascade;
drop table if exists a2_current_manager cascade;

--Native VT range columns and temporal constraints
create table a2_current_rent as
select r.*,
	daterange(r.valid_from, r.valid_to, '[)') as valid_period
from apartment_rent_version as r
where r.tx_to = timestamptz '9999-12-31 23:59:59.999999+00';

alter table a2_current_rent
	add constraint a2_current_rent_pk primary key (version_id),
	add constraint a2_current_rent_no_overlap 
		unique (apartment_id, valid_period without overlaps);

create table a2_current_manager as
select m.*,
	daterange(m.valid_from, m.valid_to, '[)') as valid_period
from apartment_manager_version as m
where m.tx_to = timestamptz '9999-12-31 23:59:59.999999+00';

alter table a2_current_manager
	add constraint a2_current_manager_pk primary key (version_id),
	add constraint a2_current_manager_no_overlap
		unique (apartment_id, valid_period without overlaps);

create table a2_current_lease as
select l.*,
	daterange(l.valid_from, l.valid_to, '[)') as valid_period
from lease_version as l
where l.tx_to = timestamptz '9999-12-31 23:59:59.999999+00';

alter table a2_current_lease 
	add constraint a2_current_lease_pk primary key (version_id),
	add constraint a2_current_lease_one_tenant_ar_a_time
		unique (apartment_id, valid_period without overlaps),
	add constraint a2_current_lease_rent_coverage
		foreign key (apartment_id, period valid_period)
		references a2_current_rent (apartment_id, period valid_period);

comment on table a2_current_lease is 
'Current TT snapshot for A2: PostgreSQL native VT constraints; source history remains in lease_version';
comment on table a2_current_rent is
'Current TT snapchot for A2: valid periods are constrained with WITHOUT OVERLAPS';
comment on table a2_current_manager is
'Current TT snapchot for A2: manager assignment periods are constrained with WITHOUT OVERLAPS';

--Q1: Current facts for the selected tenant, valid today
--Uses native range containment for valid time: @>
create view v_a2_q1_current_facts as
select t.tenant_id,
		t.name as tenant_name, a.apartment_id,
		a.adress,
		l.valid_from as lease_from,
		l.valid_to as lease_to,
		l.deposit_eur,
		r.rent_eur as listed_rent_eur,
		m.name as manager_name
from query_params as p
join tenant as t
	on t.tenant_id = p.subject_id
join a2_current_lease as l
	on l.tenant_id = t.tenant_id and l.valid_period @> p.today
join apartment as a
	on a.apartment_id = l.apartment_id
left join a2_current_rent as r
	on r.apartment_id = a.apartment_id and r.valid_period @> p.today
left join a2_current_manager as mv
	on mv.apartment_id = l.apartment_id and mv.valid_period @> p.today
left join property_manager as m
	on m.manager_id = mv.manager_id;

--Q5: The relationship table as the database knew it at know_at
--PostgreSQL jas no native system-time AS OF syntax, so TT stays explicit
--VT is delibertely not filtered in Q5
create view v_a2_q5_as_known as
select l.version_id,
		l.tenant_id,
		t.name as tenant_name,
		l.apartment_id,
		l.deposit_eur,
		l.valid_from,
		l.valid_to,
		l.tx_from,
		l.tx_to,
		l.tx_id,
		p.known_at
from query_params as p
join lease_version as l
	on l.tx_from <= p.known_at and p.known_at < l.tx_to
join tenant as t
	on t.tenant_id = l.tenant_id;

--Q6: Bitemporal point query
--VT uses PostgreSQL range containment, TT remains explicit 
create view v_a2_q6_bitemporal_point as
select 'manager'::text as fact_type,
		v.apartment_id,
		m.name as answer,
		v.valid_from, 
		v.valid_to,
		v.tx_from,
		v.tx_to,
		p.valid_at,
		p.known_at
from query_params  as p
join apartment_manager_version as v
	on daterange(v.valid_from, v.valid_to, '[)') @> p.valid_at
	and v.tx_from <= p.known_at
	and p.known_at < v.tx_to
	and (p.object_id is null or v.apartment_id = p.object_id)
join property_manager as m
	on m.manager_id = v.manager_id
union all
select 'rent'::text as fact_type,
		v.apartment_id,
        v.rent_eur::text || ' eur' AS answer,
        v.valid_from,
        v.valid_to,
        v.tx_from,
        v.tx_to,
        p.valid_at,
        p.known_at
from query_params as p
join apartment_rent_version as v
	on daterange(v.valid_from, v.valid_to, '[)') @> p.valid_at
	and v.tx_from <= p.known_at
	and p.known_at < v.tx_to
	and (p.object_id is null or v.apartment_id = p.object_id)
union all
select 'lease'::text as fact_type,
		v.apartment_id,
        t.name AS answer,
        v.valid_from,
        v.valid_to,
        v.tx_from,
        v.tx_to,
        p.valid_at,
        p.known_at
from query_params as p
join lease_version as v
	on daterange(v.valid_from, v.valid_to, '[)') @> p.valid_at
	and v.tx_from <= p.known_at
	and p.known_at < v.tx_to
	and (p.object_id is null or v.apartment_id = p.object_id)
join tenant as t
	on t.tenant_id = v.tenant_id;

--Equivalence checks against the core views
--Each result should be true -> EXEPT ALL checks duplicates as well as values.
select 'Q1' as query_name,
	not exists(
		(select * from v_q1_current_facts
		except all
		select * from v_a2_q1_current_facts)
		union all
		(select * from v_a2_q1_current_facts
		except all
		select * from v_q1_current_facts)
	) as same_rows_as_core;

select 'Q5' as query_name,
	not exists(
		(select * from v_q5_as_known_at
		except all
		select * from v_a2_q5_as_known)
		union all
		(select * from v_a2_q5_as_known
		except all
		select * from v_q5_as_known_at)
	) as same_rows_as_core;

select 'Q6' as query_name,
	not exists(
		(select * from v_q6_bitemporal_point
		except all
		select * from v_a2_q6_bitemporal_point)
		union all
		(select * from v_a2_q6_bitemporal_point
		except all
		select * from v_q6_bitemporal_point)
	) as same_rows_as_core;

--Verifications
select * from v_q1_current_facts order by tenant_id, apartment_id;
select * from v_a2_q1_current_facts order by tenant_id, apartment_id;

select * from v_q5_as_known_at order by tenant_id, apartment_id, valid_from, tx_from;
select * from v_a2_q5_as_known order by tenant_id, apartment_id, valid_from, tx_from;

select * from v_q6_bitemporal_point order by fact_type, apartment_id;
select * from v_a2_q6_bitemporal_point order by fact_type, apartment_id;