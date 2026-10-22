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
	v_tx_time := sim_now();

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
		date '2016-01-01',
		date '2016-01-15',
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
		'E4 - correction of apartment 1 rent'
	)
	returning tx_id into v_tx_id;

	update apartment_rent_version
	set tx_to = v_tx_time
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
		'E5 - tenant 10 leaves apartment 1'
	)
	returning tx_id into v_tx_id;

	update lease_version
	set tx_to = v_tx_time
	where tenant_id = 10
		and apartment_id = 1
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
	values(
		10,
		1,
		600.00,
		date '2024-01-15',
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

/*
	E7 - role holder changes
   	Includes the required "story".
*/

/*
    E7 - Mid-period manager change for apartment 1
    Initial current manager: Manager 5, valid 2025-01-01 -> 2027-01-01
    New manager: Manager 2, valid from 2026-06-15
    Recorded before the change takes effect.
*/

set app.sim_now = '2026-06-05 09:00:00+00';

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
        'E7 - proactive mid-period manager change for apartment 1'
    )
    returning tx_id into v_tx_id;

    update apartment_manager_version
    set tx_to = v_tx_time
    where apartment_id = 1
      and valid_from = date '2025-01-01'
      and valid_to = date '2027-01-01'
      and tx_to = '9999-12-31 23:59:59.999999+00';

    insert into apartment_manager_version(
        apartment_id,
        manager_id,
        valid_from,
        valid_to,
        tx_from,
        tx_to,
        tx_id
    )
    values
        (
            1,
            5,
            date '2025-01-01',
            date '2026-06-15',
            v_tx_time,
            '9999-12-31 23:59:59.999999+00',
            v_tx_id
        ),
        (
            1,
            2,
            date '2026-06-15',
            date '2027-01-01',
            v_tx_time,
            '9999-12-31 23:59:59.999999+00',
            v_tx_id
        );
end $$;


/*
    E7 - Later correction of the manager for apartment 1
    Manager 2 was initially recorded for 2026-06-15 -> 2027-01-01
    The corrected manager is Manager 3.
    Question: Who was the manager of apartment 1 on 2026-06-20?
    As known on:
        2026-01-01 -> Manager 5
        2026-06-05 -> Manager 2
        2026-06-15 -> Manager 3
*/

set app.sim_now = '2026-06-15 09:00:00+00';

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
        'E7.2 - correction of apartment 1 manager'
    )
    returning tx_id into v_tx_id;

    update apartment_manager_version
    set tx_to = v_tx_time
    where apartment_id = 1
      and manager_id = 2
      and valid_from = date '2026-06-15'
      and valid_to = date '2027-01-01'
      and tx_to = '9999-12-31 23:59:59.999999+00';

    insert into apartment_manager_version(
        apartment_id,
        manager_id,
        valid_from,
        valid_to,
        tx_from,
        tx_to,
        tx_id
    )
    values (
        1,
        3,
        date '2026-06-15',
        date '2027-01-01',
        v_tx_time,
        '9999-12-31 23:59:59.999999+00',
        v_tx_id
    );
end $$;


/*
    E7 - Manager change for apartment 2
    This demonstrates that the role table is used for multiple
    central objects.
*/

set app.sim_now = '2026-06-25 09:00:00+00';

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
        'E7.3 - manager change for apartment 2'
    )
    returning tx_id into v_tx_id;

    update apartment_manager_version
    set tx_to = v_tx_time
    where apartment_id = 2
      and manager_id = 5
      and valid_from = date '2025-01-01'
      and valid_to = date '2027-01-01'
      and tx_to = '9999-12-31 23:59:59.999999+00';

    insert into apartment_manager_version(
        apartment_id,
        manager_id,
        valid_from,
        valid_to,
        tx_from,
        tx_to,
        tx_id
    )
    values
        (
            2,
            5,
            date '2025-01-01',
            date '2026-06-20',
            v_tx_time,
            '9999-12-31 23:59:59.999999+00',
            v_tx_id
        ),
        (
            2,
            1,
            date '2026-06-20',
            date '2027-01-01',
            v_tx_time,
            '9999-12-31 23:59:59.999999+00',
            v_tx_id
        );
end $$;

/*
   E8 - erroneous insert and retraction
   The record is later closed in transaction time without
   a replacement.
*/

/*
    E8 - Erroneous rent record
    This record is inserted but should never have been recorded.
*/

set app.sim_now = '2026-07-10 09:00:00+00';

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
        'E8 - erroneous rent record for apartment 6'
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
        6,
        5000.00,
        date '2026-07-15',
        date '2026-08-01',
        v_tx_time,
        '9999-12-31 23:59:59.999999+00',
        v_tx_id
    );
end $$;


/*
    E8 - Retraction of the erroneous record
    No replacement is inserted.
*/

set app.sim_now = '2026-07-20 09:00:00+00';

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
        'E8 - retraction of erroneous apartment 6 rent record'
    )
    returning tx_id into v_tx_id;

    update apartment_rent_version
    set tx_to = v_tx_time
    where apartment_id = 6
      and rent_eur = 5000.00
      and valid_from = date '2026-07-15'
      and valid_to = date '2026-08-01'
      and tx_to = '9999-12-31 23:59:59.999999+00';
end $$;


/* 
   E9 - one change touching multiple tables
*/

/*
    E9 - Change affecting lease and rent tables
    Same tx_id is used in lease_version and apartment_rent_version
    Apartment 6:
        tenant 50 lease is updated
        new rent starts on 2026-08-01
*/
set app.sim_now = '2026-08-01 09:00:00+00';

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
        'E9 - apartment 6 lease and rent change'
    )
    returning tx_id into v_tx_id;

    update lease_version
    set tx_to = v_tx_time
    where tenant_id = 10
      and apartment_id = 6
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
        6,
        1250.00,
        date '2024-01-15',
        date '9999-12-31',
        v_tx_time,
        '9999-12-31 23:59:59.999999+00',
        v_tx_id
    );

    -- E9: retrospectively record the rent for the uncovered period
    insert into apartment_rent_version (
        apartment_id,
        rent_eur,
        valid_from,
        valid_to,
        tx_from,
        tx_to,
        tx_id
    )
    values (
        6,
        825,
        date '2026-06-30',
        date '2026-08-01',
        v_tx_time,
        timestamptz '9999-12-31 23:59:59.999999+00',
        v_tx_id
    );

	    -- E9: new rent starting on 2026-08-01
    insert into apartment_rent_version (
        apartment_id,
        rent_eur,
        valid_from,
        valid_to,
        tx_from,
        tx_to,
        tx_id
    )
    values (
        6,
        725,
        date '2026-08-01',
        date '9999-12-31',
        v_tx_time,
        timestamptz '9999-12-31 23:59:59.999999+00',
        v_tx_id
    );
end $$;


/*
    E9 - Change affecting lease and manager tables
    Same tx_id is used in lease_version and apartment_manager_version
*/
set app.sim_now = '2026-09-01 09:00:00+00';

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
        'E9 - apartment 2 lease and manager change'
    )
    returning tx_id into v_tx_id;

    update lease_version
    set tx_to = v_tx_time
    where tenant_id = 20
      and apartment_id = 2
      and valid_from = date '2026-05-12'
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
        800.00,
        date '2026-05-12',
        date '9999-12-31',
        v_tx_time,
        '9999-12-31 23:59:59.999999+00',
        v_tx_id
    );

    update apartment_manager_version
    set tx_to = v_tx_time
    where apartment_id = 2
      and manager_id = 1
      and valid_from = date '2026-06-20'
      and valid_to = date '2027-01-01'
      and tx_to = '9999-12-31 23:59:59.999999+00';

    insert into apartment_manager_version(
        apartment_id,
        manager_id,
        valid_from,
        valid_to,
        tx_from,
        tx_to,
        tx_id
    )
    values (
        2,
        4,
        date '2026-06-20',
        date '2027-01-01',
        v_tx_time,
        '9999-12-31 23:59:59.999999+00',
        v_tx_id
    );
end $$;

--Verification
select count(*) as transactions from tx_registry;
select count(*) as lease_versions from lease_version;
select count(*) as manager_versions from apartment_manager_version;
select count(*) as rent_versions from apartment_rent_version;
select
    (
        select count(*) from lease_version
    )
    +
    (
        select count(*) from apartment_manager_version
    )
    +
    (
        select count(*) from apartment_rent_version
    ) as total_version_rows;
select tx_id, tx_time, author, reason
from tx_registry
order by tx_time, tx_id;