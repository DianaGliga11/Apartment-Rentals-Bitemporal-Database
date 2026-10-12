/*
 tx_registry = table with one row per logical change
 tx_id = row in tx_registry, automatically generated
 tx_time = collumn in tx_registry, taken from sim.now()
 tx_from/tx_to = collumns in version tables (when the database belived the event
 was true)
*/

--tx time stored in UTC
set timezone = 'UTC';

--necessary for EXCLUDE
create extension if not exists btree_gist;

--it can be re-run
drop schema if exists rentals cascade;

create schema rentals;
set search_path = rentals, public;

/*
 Simulated clock : tx_from from this one
 If it is not set, it is used the real clock
*/
create function sim_now() returns timestamptz
	language sql stable as $$
		select coalesce(nullif(current_setting('app.sim_now', true), '')::timestamptz,
						clock_timestamp());
	$$;

/*
 tx_registry: one entry per logical change
 UNIQUE (tx_id, tx_time) allows FK compound from the version tables
 which forces tx_from to be tx_registry.tx_time
*/
create table tx_registry(
	tx_id bigint generated always as identity primary key,
	tx_time timestamptz(6) not null,
	author text not null,
	reason text not null,
	unique(tx_id, tx_time)
);
comment on table tx_registry is 'non-temporal: tranzaction jurnal (the table defines itself the transaction time)';

/*
 ANCHORS, non-temporal: their attributes does not change
 the changes are made in the version tables
*/
create table owner(
	owner_id int generated always as identity primary key,
	name text not null
);
comment on table owner is 'non-temporal: the owner is the only one per apartment
in this model';

create table apartment(
	apartment_id int generated always as identity primary key,
	owner_id int not null references owner (owner_id),
	adress text not null,
	rooms int not null check (rooms > 0),
	area_m2 numeric(6,2) not null check (area_m2 > 0)
);
comment on table apartment is 'non-temporal: central object, the rent and administrator
have their own versions';

create table tenant(
	tenant_id int generated always as identity primary key,
	name text not null,
	birth_date date not null
);
comment on table tenant is 'non-temporal: main population';

create table property_manager(
	manager_id int generated always as identity primary key,
	name text not null
);
comment on table property_manager is 'non-temporal: has the administrator role';

--the relationship tenant-apartment: respect E6 - restarts after a gap
create table lease_version(
	version_id bigint generated always as identity primary key,
	tenant_id int not null references tenant(tenant_id),
	apartment_id int not null references apartment(apartment_id),
	deposit_eur numeric(10, 2) not null default 0 check (deposit_eur >= 0),
	valid_from date not null,
	valid_to date not null default '9999-12-31',
	tx_from timestamptz(6) not null,
	tx_to timestamptz(6) not null default '9999-12-31 23:59:59.999999+00',
	tx_id bigint not null,
	check (valid_from < valid_to),
	check(tx_from < tx_to),
	foreign key (tx_id, tx_from) references tx_registry (tx_id, tx_time),
	--I1: the same (tenant, apartment) does not have overlapping valid periods, between current rows in TT
	constraint ex_lease_i1 exclude using gist (
		tenant_id with = , apartment_id with = ,
		daterange(valid_from, valid_to) with &&
	) where (tx_to = '9999-12-31 23:59:59.999999+00') deferrable initially immediate,
	--Business rule: one apartment - at most one tenant at a time
	constraint ex_lease_one_tenant_per_apt exclude using gist(
		apartment_id with = ,
		daterange(valid_from, valid_to) with &&
	) where (tx_to = '9999-12-31 23:59:59.999999+00') deferrable initially immediate
);
comment on table lease_version is 'bitemporal: tenant-apartment relationship';

--Role - apartment administrator: respects E7 - at most one holder at a time
create table apartment_manager_version(
	version_id bigint generated always as identity primary key,
	apartment_id int not null references apartment(apartment_id),
	manager_id int not null references property_manager(manager_id),
	valid_from date not null,
	valid_to date not null default '9999-12-31',
	tx_from timestamptz(6) not null,
	tx_to timestamptz(6) not null default '9999-12-31 23:59:59.999999+00',
	tx_id bigint not null,
	check (valid_from < valid_to),
	check (tx_from < tx_to),
	foreign key (tx_id, tx_from) references tx_registry (tx_id, tx_time),
	--I3: a manager has a single role for an apartment
	constraint ex_manager_i3 exclude using gist(
		apartment_id with = ,
		daterange(valid_from, valid_to) with &&
	) where (tx_to = '9999-12-31 23:59:59.999999+00') deferrable initially immediate
);
comment on table apartment_manager_version is 'bitemporal: administrator of the apartment role';

--Numeric attribute that changes: monthly rate
create table apartment_rent_version(
	version_id bigint generated always as identity primary key,
	apartment_id int not null references apartment(apartment_id),
	rent_eur numeric (10, 2) not null check (rent_eur > 0),
	valid_from date not null,
	valid_to date not null default '9999-12-31',
	tx_from timestamptz(6) not null,
	tx_to timestamptz(6) not null default '9999-12-31 23:59:59.999999+00',
	tx_id bigint not null,
	check (valid_from < valid_to),
	check (tx_from < tx_to),
	foreign key (tx_id, tx_from) references tx_registry(tx_id, tx_time),
	--I1: for apartment_id (never overlap)
	constraint ex_rent_i1 exclude using gist(
		apartment_id with = ,
		daterange(valid_from, valid_to) with &&
	) where (tx_to = '9999-12-31 23:59:59.999999+00') deferrable initially immediate
);
comment on table apartment_rent_version is 'bitemporal: apartment rent';

/*
 Indexes designed for as-of queries for the largest version table : lease_version
 For EXPLAIN : DROP INDEX ix_lease_asof - run EXPLAIN ANALYZE
               CREATE INDEX ix_lease_asof on lease_version(tenant_id, tx_to, valid_from)
*/

create index ix_lease_asof on lease_version(tenant_id, tx_to, valid_from);
create index ix_lease_apt_asof on lease_version(apartment_id, tx_to, valid_from);
create index ix_manager_asof on apartment_manager_version(apartment_id, tx_to, valid_from);
create index ix_rent_asof on apartment_rent_version(apartment_id, tx_to, valid_from);

--partial indexes for the current state in TT
create index ix_lease_current on lease_version(tenant_id, valid_from)
	where tx_to = '9999-12-31 23:59:59.999999+00';
create index ix_manager_current on apartment_manager_version(apartment_id, valid_from)
	where tx_to = '9999-12-31 23:59:59.999999+00';
create index ix_rent_current on apartment_rent_version(apartment_id, valid_from)
	where tx_to = '9999-12-31 23:59:59.999999+00';
