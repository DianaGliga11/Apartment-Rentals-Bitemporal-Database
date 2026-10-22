set client_encoding = 'utf8';
set timezone = 'utc';
set search_path to rentals, public;

/*
	Advanced track A1:
	- automatic transaction-time management
	- write API
	- guards against direct history modifications
	- negative tests
*/
begin;

--constraints and helper function
create or replace function a1_current_tx_time()
returns timestamptz
language plpgsql
as $$
declare 
	v_time timestamptz;
begin
	v_time := sim_now();

	if v_time is null then
		v_time := clock_timestamp();
	end if;

	return v_time;
end;
$$;

--helper: register a transaction
create or replace function a1_register_transaction(
	p_author text,
	p_reason text
)
returns bigint
language plpgsql
as
$$
declare 
	v_tx_id bigint;
	v_tx_time timestamptz;
begin
	v_tx_time := a1_current_tx_time();

	insert into tx_registry(tx_time, author, reason)
	values(v_tx_time, p_author, p_reason)
	returning tx_id into v_tx_id;

	return v_tx_id;
end;
$$;

--generic insert helper
/*
	p_fact is a json containing the business columns and valid_time
	version_id, tx_from, tx_to and tx_id are managed here
*/
create or replace function a1_insert_fact(
	p_table regclass,
	p_fact jsonb,
	p_tx_id bigint
)
returns bigint
language plpgsql
as
$$
declare
	v_table text;
	v_columns text;
	v_values text;
	v_sql text;
	v_version_id bigint;
	v_tx_time timestamptz;
begin
	if p_table not in (
		'lease_version'::regclass,
		'apartment_manager_version'::regclass,
		'manager_rent_version'::regclass
	)then
		raise exception 'Unsupported temporal table: %', p_table;
	end if;

	if p_fact is null or jsonb_typeof(p_fact) <> 'object' then
		raise exception 'p_fact must be a JSON object';
	end if;

	if p_fact ?| array['version_id', 'tx_from', 'tx_to', 'tx_id'] then
		raise exception 'Do not provide version_id, tx_from, tx_to or tx_id in p_fact';
	end if;

	select format('%I.%I', n.nspname, c.relname)
	into v_table
	from pg_class c
	join pg_namespace n on n.oid = c.relnamespace
	where c.oid = p_table;

	select 
		string_agg(format('%I', key), ', ' order by key),
		string_agg(format('(jsonb_populate_record(NULL::%s, $1)).%I', v_table, key),
			', ' order by key 
		)
	into v_columns, v_values
	from jsonb_object_keys(p_fact) as keys(key);

	if v_columns is null then
		raise exception 'p_fact must contain business fields';
	end if;

	v_tx_time := a1_current_tx_time();

	v_sql := format(
		'insert into %s (%s, tx_from, tx_to, tx_id)
		select %s, $2, %L::timestamptz, $3
		returning version_id',
		v_table,
		v_columns,
		v_values,
		'9999-12-31 23:59:59.999999+00'
	);

	execute v_sql
	using p_fact, v_tx_time, p_tx_id
	into v_version_id;

	return v_version_id;
end;
$$;

--write API: assert a new fact'
create or replace function sp_assert_fact(
	p_table regclass,
	p_fact jsonb,
	p_author text,
	p_reason text
)
returns bigint
language plpgsql
as $$
declare
	v_tx_id bigint;
	v_version_id bigint;
begin
	v_tx_id := a1_register_transaction(p_author, p_reason);

	perform set_config('rentals.a1_api_write', 'on', true);

	v_version_id := a1_insert_fact(p_table, p_fact, v_tx_id);

	return v_version_id;
end;
$$;

--write API: close a fact in transaction time
create or replace function sp_retract_fact(
	p_table regclass,
	p_version_id bigint,
	p_author text,
	p_reason text
)
returns void
language plpgsql
as $$
declare
	v_tx_id bigint;
	v_tx_time timestamptz;
	v_table text;
	v_rows integer;
begin
	if p_table not in (
		'lease_version'::regclass,
		'apartment_manager_version'::regclass,
		'apartment_rent_version'::regclass
	)then
		raise exception 'Unsupported temporal table: %', p_table;
	end if;

	v_tx_id := a1_register_transaction(p_author, p_reason);

	select format('%I.%I', n.nspname, c.relname)
	into v_table
	from pg_class c
	join pg_namespace n on n.oid = c.relnamespace
	where c.oid = p_table;

	v_tx_time := a1_current_tx_time();
	perform set_config('rentals.a1_api_write', 'on', true);

	execute format(
		'update %s
		set tx_to = $1
		where version_id = $2
			and tx_to = %L::timestamptz',
		v_table,
		'9999-12-31 23:59:59.999999+00'
	)
	using v_tx_time, p_version_id;

	get diagnostics v_rows = row_count;
	if v_rows <> 1 then
		raise exception 'Fact % was not found or is already closed',
		p_version_id;
	end if;
end;
$$;

--write API: end a fact's valid_time period
--this closses the current transaction time version and inserts
--a replacement with shorter valid-time period
create or replace function sp_end_fact(
	p_table regclass,
	p_version_id bigint,
	p_new_valid_to date,
	p_author text,
	p_reason text
)
returns bigint
language plpgsql
as $$
declare
	v_tx_id bigint;
	v_tx_time timestamptz;
	v_table text;
	v_fact jsonb;
	v_old_valid_from date;
	v_old_valid_to date;
	v_new_id bigint;
	v_rows integer;
begin
	if p_table not in (
        'lease_version'::regclass,
        'apartment_manager_version'::regclass,
        'apartment_rent_version'::regclass
    ) then
        raise exception 'Unsupported temporal table: %', p_table;
    end if;

	select format('%I.%I', n.nspname, c.relname)
	into v_table
	from pg_class c
	join pg_namespace n on n.oid = c.relnamespace
	where c.oid = p_table;

	execute format(
		'select to_jsonb(t), t.valid_from, t.valid_to
		from %s t
		where t.version_id = $1
			and t.tx_to = %L::timestamptz
		for update',
		v_table,
		'9999-12-31 23:59:59.999999+00'
	)
	into v_fact, v_old_valid_from, v_old_valid_to
	using p_version_id;

	if v_fact is null then
		raise exception 'Current version % was not found in %',
		p_version_id, p_table;
	end if;

	if p_new_valid_to <= v_old_valid_from
		or p_new_valid_to >= v_old_valid_to then
			raise exception 'New valid_to must be after valid_from and before old valid_to';
	end if;

	v_tx_id := a1_register_transaction(p_author, p_reason);
	v_tx_time := a1_current_tx_time();

	perform set_config('rentals.a1_api_write', 'on', true);

	execute format(
		'update %s
		set tx_to = $1
		where version_id = $2
			and tx_to = %L::timestamptz',
		v_table,
		'9999-12-31 23:59:59.999999+00'
	)
	using v_tx_time, p_version_id;

	get diagnostics v_rows = row_count;

	if v_rows <> 1 then
		raise exception 'Could not close version %', p_version_id;
	end if;

	v_fact := v_fact
		- 'version_id'
		- 'tx_from'
		- 'tx_to'
		- 'tx_id';
	v_fact := jsonb_set(
		v_fact,
		'{valid_to}',
		to_jsonb(p_new_valid_to::text)
	);

	v_new_id := a1_insert_fact(p_table, v_fact, v_tx_id);

	return v_new_id;
end;
$$;

--write API: correct a fact
--closes the previous version and inserts a corrected one
--p_corrected_fact must contain all business columns and the valid_from/valid_to
--values for the corrected version
create or replace function sp_correct_fact(
	p_table regclass,
	p_version_id bigint,
	p_corrected_fact jsonb,
	p_author text,
	p_reason text
)
returns bigint
language plpgsql
as $$
declare 
	v_tx_id bigint;
	v_tx_time timestamptz;
	v_table text;
	v_new_id bigint;
	v_rows integer;
begin
	if p_table not in (
        'lease_version'::regclass,
        'apartment_manager_version'::regclass,
        'apartment_rent_version'::regclass
    ) then
        raise exception 'Unsupported temporal table: %', p_table;
    end if;

	if p_corrected_fact ?| array['version_id', 'tx_from', 'tx_to', 'tx_id'] then
		raise exception 'Do not provide version_id, tx_from, tx_to or tx_id';
	end if;

	v_tx_id := a1_register_transaction(p_author, p_reason);
	select format('%I.%I', n.nspname, c.relname)
	into v_table
	from pg_class c
	join pg_namespace n on n.oid = c.relnamespace
	where c.oid = p_table;

	v_tx_time := a1_current_tx_time();

	perform set_config('rentals.a1_api_write', 'on', true);

	execute format(
		'update %s
		set tx_to = $1
		where version_id = $2
			and tx_to = %L::timestamptz',
		v_table,
		'9999-12-31 23:59:59.999999+00'
	)
	using v_tx_time, p_version_id;

	get diagnostics v_rows = row_count;

	if v_rows <> 1 then 
		raise exception 'Fact % was not found or is already closed', p_version_id;
	end if;

	v_new_id := a1_insert_fact(p_table, p_corrected_fact, v_tx_id);

	return v_new_id;
end;
$$;

--Guard trigger
--Reject direct INSERT, DELETE and updates other than closing the TT
--period of a currently open row.
--API calls use the transaction-local flag set above.
create or replace function a1_guard_history()
returns trigger
language plpgsql
as $$
declare
	v_api_write text;
begin
	v_api_write := current_setting('rentals.a1_api_write', true);

	if v_api_write is distinct from 'on' then
		raise exception 'Direct modifications of temporal history are forbiden. Use the A1 write API';
	end if;

	if tg_op = 'DELETE' then
		raise exception 'Physical deletion of temporal history is forbidden';
	end if;

	if tg_op = 'INSERT' then
		if NEW.tx_from is null
			or NEW.tx_to is distinct from '9999-12-31 23:59:59.999999+00'::timestamptz
			or NEW.tx_id is null then
				raise exception 'New versions require automatic transaction-time values';
		end if;
		return NEW;
	end if;

	if tg_op = 'UPDATE' then
		if OLD.tx_to is distinct from
			'9999-12-31 23:59:59.999999+00'::timestamptz then
				raise exception 'Closed historical versions cannot be modified';
		end if;

		if (to_jsonb(NEW) - 'tx_to') is distinct from
			(to_jsonb(OLD) - 'tx_to') then
				raise exception 'Only tx_to may change when closing a version';
		end if;

		if NEW.tx_to >= OLD.tx_to then
			raise exception 'tx_to must move backwards from the open-ended sentinel';
		end if;

		return NEW;
	end if;

	return null;
end;
$$;

--install the guard on all three version tables
drop trigger if exists trg_a1_guard_lease
	on lease_version;

create trigger trg_a1_guard_lease
before insert or update or delete on lease_version 
for each row execute function a1_guard_history();

drop trigger if exists trg_a1_guard_manager
	on apartment_manager_version;

create trigger trg_a1_guard_manager
before insert or update or delete on apartment_manager_version 
for each row execute function a1_guard_history();

drop trigger if exists trg_a1_guard_rent
	on apartment_rent_version;

create trigger trg_a1_guard_rent
before insert or update or delete on apartment_rent_version 
for each row execute function a1_guard_history();

commit;

--negative tests
--Each test catches the expected exception so the script continues running
do $$
begin
	begin
		delete from lease_version
		where version_id = (
			select version_id
			from lease_version
			limit 1
		);

		raise notice 'Fail: direct DELETE was not blocked';
	exception
		when others then
			if sqlerrm like
				'Direct modifications of temporal history are forbidden%' then
					raise notice 
						'Pass: direct DELETE was rejected';
			else
				raise notice 'DELETE test raised: %', sqlerrm;
			end if;
	end;
end;
$$;

do $$
begin
	begin
		update lease_version
		set tx_to = clock_timestamp()
		where version_id = (
			select version_id
			from lease_version
			limit 1
		);

		raise notice 'Fail: direct UPDATE was not blocked';
	exception
		when others then
			if sqlerrm like
				'Direct modifications of temporal history are forbidden%' then
					raise notice 
						'Pass: direct UPDATE was rejected';
			else
				raise notice 'UPDATE test raised: %', sqlerrm;
			end if;
	end;
end;
$$;

SELECT COUNT(*) AS violations
FROM rentals.v_integrity_violations;