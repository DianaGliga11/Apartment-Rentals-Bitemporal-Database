/*
	Events E2 - E9
	E1 is stored in 02_data.sql
	Each logical transaction sets app.sin_no, creates one tx_registry no and uses 
	the generated tx_id for all changes belonging to that event.
*/

set timezone = 'UTC';
set search_path = rentals, public;

/*
	E2 - first apartment - rent increase
	Recorded: 2026-01-05
	Takes effect: 2026-07-01
*/

set app.sim_now = '2026-01-05 10:00:00+00';

do $$
declare 
	v_tx_id bigint;
	v_tx_time timestamptz;
begin
	v_tx_time := sin_now();

	insert into tx_registry(tx_time, author, reason)
	values(
		v_tx_time,
		'system ',
		'E2 - proactive rent increase for apartment 1'
	)
	returning tx_id into v_tx_id;

	insert into apartment_rent_version(
		apartment_id,
		rent_eur,
		valid_from,
		valid_to,
		tx_from,
		tx_to,
		tx_id
	)
	values(
		1,
		975.00,
		date '2026-07-01',
		date '9999-12-31',
		v_tx_time,
		'9999-12-31 23:59:59.999999+00',
		v_tx_id
	);
end $$;

/*
	E2 - second apartment - rent increase
	Recorded: 2026-01-20
	Takes effect: 2026-08-01
*/
set app.sim_now = '2026-01-20 09:00:00+00';

do $$
declare
    v_tx_id bigint;
    v_tx_time timestamptz;
begin
    v_tx_time := sim_now();

    insert into tx_registry(tx_time, author, reason)
    values (
        v_tx_time,
        'system',
        'E2 - proactive rent increase for apartment 2'
    )
    returning tx_id into v_tx_id;

    insert into apartment_rent_version(
        apartment_id,
        rent_eur,
        valid_from,
        valid_to,
        tx_from,
        tx_to,
        tx_id
    )
    values (
        2,
        1125.00,
        date '2026-08-01',
        date '9999-12-31',
        v_tx_time,
        '9999-12-31 23:59:59.999999+00',
        v_tx_id
    );
end $$;

/*
	E2 - third apartment - rent increase
	Recorded: 2026-01-20
	Takes effect: 2026-08-01
*/
set app.sim_now = '2026-02-05 09:00:00+00';

do $$
declare 
	v_tx_id bigint;
	v_tx_time timestamptz;
begin
	v_tx_time := sim_now();
	insert into tx_registry(tx_time, author, reason)
	values(
		v_tx_time,
		'system ',
		'E2 - proactive rent increase for apartment 3'
	)
	returning tx_id into v_tx_id;

	insert into apartment_rent_version(
		apartment_id, rent_eur,
		valid_from,
		valid_to,
		tx_from,
		tx_to,
		tx_id
	)
	values(
		3,
		1275.00,
		date '2026-09-01',
		date '9999-12-31',
		v_tx_time,
		'9999-12-31 23:59:59.999999+00',
		v_tx_id
	);
end $$;

/*
	E3 - late entries
	The initial lease date contains small gaps between historical valid periods.
	E3 fills five of those historical gaps.
*/

/*
	E3 - late entry for apartment 1
	Valid period: 2016-01-01 -> 2016-01-15
	Recorded later: 2016-02-20
*/
set app.sim_now() = '2026-02-20 09:00:00+00';

do $$
declare 
	v_tx_id bigint;
	v_tx_time timestamptz;
begin
	v_tx_time := sim_now();
	insert into tx_registry(tx_time, author, reason)
	values(
		v_tx_time,
		'system ',
		'E3 - late entry for tenant 1 apartment 1 lease'
	)
	returning tx_id into v_tx_id;

	insert into lease_version(
		tenant_id,
		apartment_id,
		deposit_eur,
		valid_from,
		valid_to,
		tx_from,
		tx_to,
		tx_id
	)
	values(
		1,
		1,
		600.00,
		date '2026-01-01',
		date '2026-01-15',
		v_tx_time,
		'9999-12-31 23:59:59.999999+00',
		v_tx_id
	);
end $$;

/*
	E3 - late entry for apartment 2
*/

do $$
declare
    v_tx_id bigint;
    v_tx_time timestamptz;
begin
    v_tx_time := sim_now();

    insert into tx_registry(tx_time, author, reason)
    values (
        v_tx_time,
        'system',
        'E3 - late entry for tenant 11 apartment 2 lease'
    )
    returning tx_id into v_tx_id;

    insert into lease_version(
        tenant_id,
        apartment_id,
        deposit_eur,
        valid_from,
        valid_to,
        tx_from,
        tx_to,
        tx_id
    )
    values (
        11,
        2,
        700.00,
        date '2016-01-01',
        date '2016-01-15',
        v_tx_time,
        '9999-12-31 23:59:59.999999+00',
        v_tx_id
    );
end $$;

/*
	E3 - late entry for apartment 3
*/
set app.sim_now = '2026-03-01 09:00:00+00';

do $$
declare
    v_tx_id bigint;
    v_tx_time timestamptz;
begin
    v_tx_time := sim_now();

    insert into tx_registry(tx_time, author, reason)
    values (
        v_tx_time,
        'system',
        'E3 - late entry for tenant 21 apartment 3 lease'
    )
    returning tx_id into v_tx_id;

    insert into lease_version(
        tenant_id,
        apartment_id,
        deposit_eur,
        valid_from,
        valid_to,
        tx_from,
        tx_to,
        tx_id
    )
    values (
        21,
        3,
        800.00,
        date '2016-01-01',
        date '2016-01-15',
        v_tx_time,
        '9999-12-31 23:59:59.999999+00',
        v_tx_id
    );
end $$;

/*
    E3 - Late entry for apartment 4
*/
set app.sim_now = '2026-03-10 09:00:00+00';

do $$
declare
    v_tx_id bigint;
    v_tx_time timestamptz;
begin
    v_tx_time := sim_now();

    insert into tx_registry(tx_time, author, reason)
    values (
        v_tx_time,
        'system',
        'E3 - late entry for tenant 31 apartment 4 lease'
    )
    returning tx_id into v_tx_id;

    insert into lease_version(
        tenant_id,
        apartment_id,
        deposit_eur,
        valid_from,
        valid_to,
        tx_from,
        tx_to,
        tx_id
    )
    values (
        31,
        4,
        900.00,
        date '2016-01-01',
        date '2016-01-15',
        v_tx_time,
        '9999-12-31 23:59:59.999999+00',
        v_tx_id
    );
end $$;

/*
    E3 - Late entry for apartment 5
*/
set app.sim_now = '2026-03-20 09:00:00+00';

do $$
declare
    v_tx_id bigint;
    v_tx_time timestamptz;
begin
    v_tx_time := sim_now();

    insert into tx_registry(tx_time, author, reason)
    values (
        v_tx_time,
        'system',
        'E3 - late entry for tenant 41 apartment 5 lease'
    )
    returning tx_id into v_tx_id;

    insert into lease_version(
        tenant_id,
        apartment_id,
        deposit_eur,
        valid_from,
        valid_to,
        tx_from,
        tx_to,
        tx_id
    )
    values (
        41,
        5,
        1000.00,
        date '2016-01-01',
        date '2016-01-15',
        v_tx_time,
        '9999-12-31 23:59:59.999999+00',
        v_tx_id
    );
end $$;

/*
	E4 - corrections
	Old version is closed in transaction time and replaced
*/

/*
	E4 - correction of apartment 1 rent
*/
set app.sim_now() = '2026-03-25 09:00:00+00';

do $$
declare
	v_tx_id bigint;
	v_tx_time timestamptz;
begin
	v_tx_time := sim_now();
	insert into tx_registry(tc_time, author, reason)
	values(
		v_tx_time,
		'system ',
		'E4 - correction of apartment 1 rent'
	)
	returning tx_id into v_tx_id;

	update apartment_rent_version
	set tx_to = v_tx_time;
	where apartment_id = 1 
		and valid_from = date '2026-07-01'
		and tx_to = '9999-12-31 23:59:59.999999+00';
	insert into apartment_rent_version(
		apartment_id, 
		rent_eur,
		valid_from,
		valid_to,
		tx_from,
		tx_to,
		tx_id
	)
	values(
		1,
		950.00,
		date '2026-07-01',
		date '9999-12-31',
		v_tx_time,
		'9999-12-31 23:59:59.999999+00',
		v_tx_id
	);
end $$;

/*
    E4 - Correction of apartment 2 rent
*/
set app.sim_now = '2026-04-01 09:00:00+00';

do $$
declare
    v_tx_id bigint;
    v_tx_time timestamptz;
begin
    v_tx_time := sim_now();

    insert into tx_registry(tx_time, author, reason)
    values (
        v_tx_time,
        'system',
        'E4 - correction of apartment 2 rent'
    )
    returning tx_id into v_tx_id;

    update apartment_rent_version
    set tx_to = v_tx_time
    where apartment_id = 2
      and valid_from = date '2026-08-01'
      and tx_to = '9999-12-31 23:59:59.999999+00';

    insert into apartment_rent_version(
        apartment_id,
        rent_eur,
        valid_from,
        valid_to,
        tx_from,
        tx_to,
        tx_id
    )
    values (
        2,
        1100.00,
        date '2026-08-01',
        date '9999-12-31',
        v_tx_time,
        '9999-12-31 23:59:59.999999+00',
        v_tx_id
    );
end $$;


/*
    E4 - Correction of apartment 3 rent
*/
set app.sim_now = '2026-04-08 09:00:00+00';

do $$
declare
    v_tx_id bigint;
    v_tx_time timestamptz;
begin
    v_tx_time := sim_now();

    insert into tx_registry(tx_time, author, reason)
    values (
        v_tx_time,
        'system',
        'E4 - correction of apartment 3 rent'
    )
    returning tx_id into v_tx_id;

    update apartment_rent_version
    set tx_to = v_tx_time
    where apartment_id = 3
      and valid_from = date '2026-09-01'
      and tx_to = '9999-12-31 23:59:59.999999+00';

    insert into apartment_rent_version(
        apartment_id,
        rent_eur,
        valid_from,
        valid_to,
        tx_from,
        tx_to,
        tx_id
    )
    values (
        3,
        1250.00,
        date '2026-09-01',
        date '9999-12-31',
        v_tx_time,
        '9999-12-31 23:59:59.999999+00',
        v_tx_id
    );
end $$;

/*
	E5 - real-world end
	The lease ends in valid time
*/

/* 
	E5 - tenant 10 leaves apartment 1
*/
set app_.sim_now() = '2026-04-15 09:00:00+00';
do$$
declare
	v_tx_id bigint;
	v_tx_time timestamptz;
begin
	v_x_time := sim_now();
	insert into tx_registry(tx_time, author, reason)
	values(
		v_tx_time,
		'system ',
		'E5 - tenant 10 leaves apartment 1'
	)
	returning tx_id into v_tx_id;

	update lease_version
	set tx_to = v_tx_time
	where tenant_id = 10
		and apartment_id = 1
		and valid_from = date '2026-01-15'
		and tx_to = '9999-12-31 23:59:59.999999+00';

	insert into lease_version(
		tenant_id, 
		apartment_id,
		deposit_eur,
		valid_from,
		valid_to,
		tx_from,
		tx_to,
		tx_id
	)
	values(
		10,
		1,
		600.00,
		date '2026-01-15',
		date '2026-04-10',
		v_tx_time,
		'9999-12-31 23:59:59.999999+00',
		v_tx_id
	);
end $$;

/*
    E5 - Tenant 20 leaves apartment 2
*/
set app.sim_now = '2026-04-20 09:00:00+00';

do $$
declare
    v_tx_id bigint;
    v_tx_time timestamptz;
begin
    v_tx_time := sim_now();

    insert into tx_registry(tx_time, author, reason)
    values (
        v_tx_time,
        'system',
        'E5 - tenant 20 leaves apartment 2'
    )
    returning tx_id into v_tx_id;

    update lease_version
    set tx_to = v_tx_time
    where tenant_id = 20
      and apartment_id = 2
      and valid_from = date '2024-01-15'
      and tx_to = '9999-12-31 23:59:59.999999+00';

    insert into lease_version(
        tenant_id,
        apartment_id,
        deposit_eur,
        valid_from,
        valid_to,
        tx_from,
        tx_to,
        tx_id
    )
    values (
        20,
        2,
        700.00,
        date '2024-01-15',
        date '2026-04-15',
        v_tx_time,
        '9999-12-31 23:59:59.999999+00',
        v_tx_id
    );
end $$;


/*
    E5 - Tenant 30 leaves apartment 3
*/
set app.sim_now = '2026-04-25 09:00:00+00';

do $$
declare
    v_tx_id bigint;
    v_tx_time timestamptz;
begin
    v_tx_time := sim_now();

    insert into tx_registry(tx_time, author, reason)
    values (
        v_tx_time,
        'system',
        'E5 - tenant 30 leaves apartment 3'
    )
    returning tx_id into v_tx_id;

    update lease_version
    set tx_to = v_tx_time
    where tenant_id = 30
      and apartment_id = 3
      and valid_from = date '2024-01-15'
      and tx_to = '9999-12-31 23:59:59.999999+00';

    insert into lease_version(
        tenant_id,
        apartment_id,
        deposit_eur,
        valid_from,
        valid_to,
        tx_from,
        tx_to,
        tx_id
    )
    values (
        30,
        3,
        800.00,
        date '2024-01-15',
        date '2026-04-20',
        v_tx_time,
        '9999-12-31 23:59:59.999999+00',
        v_tx_id
    );
end $$;


/*
    E5 - Tenant 40 leaves apartment 4
*/
set app.sim_now = '2026-05-01 09:00:00+00';

do $$
declare
    v_tx_id bigint;
    v_tx_time timestamptz;
begin
    v_tx_time := sim_now();

    insert into tx_registry(tx_time, author, reason)
    values (
        v_tx_time,
        'system',
        'E5 - tenant 40 leaves apartment 4'
    )
    returning tx_id into v_tx_id;

    update lease_version
    set tx_to = v_tx_time
    where tenant_id = 40
      and apartment_id = 4
      and valid_from = date '2024-01-15'
      and tx_to = '9999-12-31 23:59:59.999999+00';

    insert into lease_version(
        tenant_id,
        apartment_id,
        deposit_eur,
        valid_from,
        valid_to,
        tx_from,
        tx_to,
        tx_id
    )
    values (
        40,
        4,
        900.00,
        date '2024-01-15',
        date '2026-04-25',
        v_tx_time,
        '9999-12-31 23:59:59.999999+00',
        v_tx_id
    );
end $$;


/*
    E5 - Tenant 50 leaves apartment 5
*/
set app.sim_now = '2026-05-05 09:00:00+00';

do $$
declare
    v_tx_id bigint;
    v_tx_time timestamptz;
begin
    v_tx_time := sim_now();

    insert into tx_registry(tx_time, author, reason)
    values (
        v_tx_time,
        'system',
        'E5 - tenant 50 leaves apartment 5'
    )
    returning tx_id into v_tx_id;

    update lease_version
    set tx_to = v_tx_time
    where tenant_id = 50
      and apartment_id = 5
      and valid_from = date '2024-01-15'
      and tx_to = '9999-12-31 23:59:59.999999+00';

    insert into lease_version(
        tenant_id,
        apartment_id,
        deposit_eur,
        valid_from,
        valid_to,
        tx_from,
        tx_to,
        tx_id
    )
    values (
        50,
        5,
        1000.00,
        date '2024-01-15',
        date '2026-04-30',
        v_tx_time,
        '9999-12-31 23:59:59.999999+00',
        v_tx_id
    );
end $$;

/*
	E6 - restart after a gap
	Same tenant-apartment pair returns after a gap
*/

/*
	E6 - Tenant 10 returns to apartment 1
*/
set app.sim_now() = '2026-05-15 09:00:00+00';

do $$
declare 
	v_tx_id bigint;
	v_tx_time timestamptz;
begin
	v_tx_time := sim_now();

	insert into tx_registry(tx_time, author, reason)
	values(
		v_tx_time, 
		'system ',
		'E6 - tenant 10 returns to apartment 1'
	)
	returning tx_id into v_tx_id;

	insert into lease_version(
		tenant_id, 
		apartment_id,
		deposit_eur,
		valid_from,
		valid_to,
		tx_from,
		tx_to,
		tx_id
	)
	values(
		10,
		1,
		650.00,
		date '2026-05-10',
		date '9999-12-31',
		v_tx_time,
		'9999-12-31 23:59:59.999999+00',
		v_tx_id
	);
end $$;

/*
    E6 - Tenant 20 returns to apartment 2
*/
set app.sim_now = '2026-05-20 09:00:00+00';

do $$
declare
    v_tx_id bigint;
    v_tx_time timestamptz;
begin
    v_tx_time := sim_now();

    insert into tx_registry(tx_time, author, reason)
    values (
        v_tx_time,
        'system',
        'E6 - tenant 20 returns to apartment 2'
    )
    returning tx_id into v_tx_id;

    insert into lease_version(
        tenant_id,
        apartment_id,
        deposit_eur,
        valid_from,
        valid_to,
        tx_from,
        tx_to,
        tx_id
    )
    values (
        20,
        2,
        750.00,
        date '2026-05-12',
        date '9999-12-31',
        v_tx_time,
        '9999-12-31 23:59:59.999999+00',
        v_tx_id
    );
end $$;


/*
    E6 - Tenant 30 returns to apartment 3
*/
set app.sim_now = '2026-05-25 09:00:00+00';

do $$
declare
    v_tx_id bigint;
    v_tx_time timestamptz;
begin
    v_tx_time := sim_now();

    insert into tx_registry(tx_time, author, reason)
    values (
        v_tx_time,
        'system',
        'E6 - tenant 30 returns to apartment 3'
    )
    returning tx_id into v_tx_id;

    insert into lease_version(
        tenant_id,
        apartment_id,
        deposit_eur,
        valid_from,
        valid_to,
        tx_from,
        tx_to,
        tx_id
    )
    values (
        30,
        3,
        850.00,
        date '2026-05-15',
        date '9999-12-31',
        v_tx_time,
        '9999-12-31 23:59:59.999999+00',
        v_tx_id
    );
end $$;