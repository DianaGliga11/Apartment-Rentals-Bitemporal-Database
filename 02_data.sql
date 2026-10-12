--E1: Initial load
set timezone = 'UTC';
set search_path = rentals, public;

--Day 1 of the database
set app.sim_now = '2026-01-01 09:00:00+00';

-- --reset data used only whithout 03_timeline.sql script
-- truncate table
--     lease_version,
--     apartment_manager_version,
--     apartment_rent_version,
--     apartment,
--     tenant,
--     property_manager,
--     owner,
--     tx_registry
-- restart identity cascade;

do $$
declare 
	v_tx_id bigint;
	v_tx_time timestamptz;
	v_owner_id int;
	v_tenant_id int;
	v_manager_id int;
	v_apartment_id int;
	v_start date;
	v_end date;
	v_tenant_for_lease int;
begin
	--E1: one transaction for the complete initial load
	v_tx_time := sim_now();
	insert into tx_registry(tx_time, author, reason) values(
		v_tx_time,
		'system',
		'E1: initial database load'
	)
	returning tx_id into v_tx_id;

	--5 owners
	insert into owner(name)
	select 'Owner ' || gs
	from generate_series(1, 5) gs;

	-- 50 tenants
	insert into tenant(name, birth_date)
	select
	    'Tenant ' || gs,
	    date '1970-01-01' + (gs * 100)
	from generate_series(1, 50) gs;
	
	--5 managers
	insert into property_manager(name)
	select 'Manager ' || gs
	from generate_series(1, 5) gs;
	
	--6 apartments
	insert into apartment(
		owner_id,
		adress,
		rooms,
		area_m2
	)
	select ((gs-1)%5) + 1,
	'Street ' || gs || ', Apartment ' || gs, 
	2+((gs-1)%4), 
	45+(gs * 7.5)
	from generate_series(1, 6) gs;

	/*
		60 lease_version rows
		10 historical lease periods per apartment
		last period is open-ended
	*/
	for v_apartment_id in 1..6 loop
		for i in 1..10 loop
			v_start:=
				make_date(
					2015 + i -1,
					1,
					15
				);
			if i=10 then
				v_end:= date '9999-12-31';
			else
				v_end := 
					make_date(
						2015 + i,
						1,
						1
					);
			end if;

			/*
				Reuse the 50 tenants across apartments while keeping each
				tenant pair unique
			*/
			v_tenant_for_lease := ((v_apartment_id -1)*10+ i -1)% 50+1;
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
				v_tenant_for_lease,
				v_apartment_id,
				500 + (v_apartment_id* 100),
				v_start,
				v_end,
				v_tx_time,
				'9999-12-31 23:59:59.999999+00',
				v_tx_id
			);
		end loop;
	end loop;

	/*
		30 apartment_manager_version rows
		5 historical periods per apartment
	*/
	for v_apartment_id in 1..6 loop
		for i in 1..5 loop
			v_start :=
				make_date(
					2021+i-1,
					1,
					1
				);
			if i=5 then
				v_end := date '2027-01-01';
			else 
				v_end :=
					make_date(
						2021+i,
						1,
						1
					);
			end if;
			v_manager_id := ((i-1)%5)+1;
			
			insert into apartment_manager_version(
				apartment_id,
                manager_id,
                valid_from,
                valid_to,
                tx_from,
                tx_to,
                tx_id
			)
			values(
				v_apartment_id,
				v_manager_id,
				v_start,
				v_end,
				v_tx_time,
				'9999-12-31 23:59:59.999999+00',
				v_tx_id
			);
		end loop;
	end loop;

	/*
		30 apartment_rent_version rows
		5 rent periods per apartment
	*/
	for v_apartment_id in 1..6 loop
        for i in 1..5 loop
            v_start :=
                make_date(
                    2021 + i - 1,
                    1,
                    1
                );
            if i = 5 then
                v_end := date '2026-06-30';
            else
                v_end :=
                    make_date(
                        2021 + i,
                        1,
                        1
                    );
            end if;

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
                v_apartment_id,
                400 + (v_apartment_id * 50) + (i * 25),
                v_start,
                v_end,
                v_tx_time,
                '9999-12-31 23:59:59.999999+00',
                v_tx_id
            );

        end loop;
    end loop;
end $$;

select
	(select count(*) from owner) as owners,
	(select count(*) from tenant) as tenants,
	(select count(*) from property_manager) as managers,
	(select count(*) from apartment) as apartments,
	(select count(*) from lease_version) as lease_versions,
	(select count(*) from apartment_manager_version) as manager_versions,
	(select count(*) from apartment_rent_version) as rent_versions,
	(
		(select count(*) from lease_version) +
		(select count(*) from apartment_manager_version) + 
		(select count(*) from apartment_rent_version)
	) as total_version_rows;
