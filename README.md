# Apartment Rentals – Bitemporal Database

A PostgreSQL database project for managing apartment rentals using **bitemporal data modeling**.

The database stores both:

* **Valid Time (VT)** – when a fact is true in the real world.
* **Transaction Time (TT)** – when the database recorded that fact.

This allows the database to preserve the complete history of changes, including late entries, corrections, cancellations, restarts, and other temporal events.

---

## Technologies

* **PostgreSQL 18.6** – relational database management system
* **pgAdmin 4** – graphical administration and SQL development tool
* **SQL** – database schema, data population, and timeline scripts
* **PostgreSQL `btree_gist` extension** – used for temporal exclusion constraints

---

## Project Structure

```text
Apartment-Rentals-Bitemporal-Database/
│
├── 01_schema.sql
├── 02_data.sql
└── README.md
```

### `01_schema.sql`

Creates the database structure, including:

* `rentals` schema
* transaction registry
* owners
* tenants
* apartments
* property managers
* lease versions
* apartment manager versions
* apartment rent versions
* temporal constraints
* indexes
* the `sim_now()` function used for simulated transaction time

### `02_data.sql`

Loads the initial database state (**Event E1 – Initial Load**).

The initial dataset contains:

* 5 owners
* 50 tenants
* 5 property managers
* 6 apartments
* 60 lease version records
* 30 apartment manager version records
* 30 apartment rent version records
* 120 bitemporal version records in total

---

# Requirements

To use this project, install:

### PostgreSQL 18.6

PostgreSQL is the database server where the database and its tables are stored.

During installation, make sure that the PostgreSQL server and command-line/database tools are installed.

The default PostgreSQL port used by this project is:

```text
5432
```

### pgAdmin 4

pgAdmin 4 is used as the graphical interface for connecting to PostgreSQL, creating databases, and running the SQL scripts.

You can use pgAdmin's **Query Tool** to execute the scripts included in this repository.

---

# Setting Up PostgreSQL

After installing PostgreSQL 18.6, make sure that the PostgreSQL server is running.

Open **pgAdmin 4** and connect to the PostgreSQL server.

A typical local connection uses:

```text
Host: localhost
Port: 5432
Username: postgres
Password: <to be announce>
```

The PostgreSQL server should appear under:

```text
Servers
└── PostgreSQL 18
```

---

# Creating the Database

The project scripts create the `rentals` schema themselves, so a separate `rentals` schema does not need to be created manually.

It is recommended to create a dedicated PostgreSQL database for the project.

For example:

```text
ApartmentRentals
```

In pgAdmin 4:

1. Open **Servers**.
2. Expand your PostgreSQL server.
3. Right-click **Databases**.
4. Select **Create → Database**.
5. Set the database name to:

```text
ApartmentRentals
```

6. Click **Save**.

After creating the database, select it and open:

```text
Tools → Query Tool
```

---

# Running the SQL Scripts

The scripts must be executed in the following order:

```text
01_schema.sql
      ↓
02_data.sql
      ↓
```

The order is important because each script depends on the previous one.

---

## Step 1 – Create the Database Schema

Open:

```text
01_schema.sql
```

You should find tables such as:

```text
tx_registry
owner
tenant
apartment
property_manager
lease_version
apartment_manager_version
apartment_rent_version
```

---

# Step 2 – Load the Initial Data

Open:

```text
02_data.sql
```

and execute the complete script.

This script represents **E1 – Initial Load**.

The script uses PostgreSQL's simulated clock:

```sql
SET app.sim_now = '2026-01-01 09:00:00+00';
```

The `sim_now()` function defined in `01_schema.sql` uses this value to assign the transaction time to the initial data.

After running the script, the database should contain the initial dataset.

You can verify the data with:

The expected counts are:

| Table                       | Expected rows |
| --------------------------- | ------------: |
| `owner`                     |             5 |
| `tenant`                    |            50 |
| `property_manager`          |             5 |
| `apartment`                 |             6 |
| `lease_version`             |            60 |
| `apartment_manager_version` |            30 |
| `apartment_rent_version`    |            30 |

Total bitemporal version rows:

```text
120
```

---


# Important: Running the Scripts Again

`01_schema.sql` recreates the `rentals` schema using:

```sql
DROP SCHEMA IF EXISTS rentals CASCADE;
```

Therefore, running `01_schema.sql` again **deletes the existing project data and recreates the schema from scratch**.

`02_data.sql` is designed to load the initial state of the database.

If the data-loading script contains a reset section, running it again will recreate the initial E1 state.

However, **do not run `02_data.sql` after `03_timeline.sql` if you want to preserve the E2–E9 timeline**, because the initial-data script resets the database to the E1 state.

# Notes

* PostgreSQL must be running before using pgAdmin 4.
* The scripts should be executed against the intended project database.
* The scripts should be executed in the specified order.
* `01_schema.sql` creates the database schema but does not create the PostgreSQL database itself.
* The PostgreSQL database can be created manually through pgAdmin 4 before running the scripts.
* The `rentals` schema is created automatically by `01_schema.sql`.
* The `btree_gist` extension is required for the temporal exclusion constraints and is created automatically by the schema script.
