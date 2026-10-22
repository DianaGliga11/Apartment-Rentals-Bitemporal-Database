# Apartment Rentals – Bitemporal Database

A PostgreSQL database project for managing apartment rentals using **bitemporal data modeling**. The project demonstrates how to maintain, query, and validate historical data when facts can be corrected, recorded late, or changed over time.

The database tracks two temporal dimensions:

- **Valid Time (VT)** – when a fact is true in the real world.
- **Transaction Time (TT)** – when the database records a fact.

By maintaining both dimensions, the database preserves historical information and supports the reconstruction of what was true at a particular time and what the database knew at that moment.

The project includes schema creation, initial data loading, a timeline of temporal events, database views, integrity tests, advanced scenarios, and an entity-relationship diagram.

---

## Technologies

- **PostgreSQL 18.6** – relational database management system.
- **pgAdmin 4** – graphical administration and SQL development tool.
- **SQL** – schema definition, data population, temporal event processing, views, and tests.
- **PostgreSQL `btree_gist` extension** – supports temporal exclusion constraints.
- **Git and GitHub** – source control and project versioning.

---

## Project Structure

```text
Apartment-Rentals-Bitemporal-Database/
│
├── 01_schema.sql
├── 02_data.sql
├── 03_timeline.sql
├── 04_views.sql
├── 05_tests.sql
├── 06_advanced_a1.sql
├── 06_advanced_a2.sql
├── ER Diagram.pdf
└── README.md
```

### `01_schema.sql` – Database Schema

Creates the database structure, including:

- The `rentals` schema.
- The transaction registry.
- Owners, tenants, apartments, and property managers.
- Lease version records.
- Apartment manager version records.
- Apartment rent version records.
- Bitemporal constraints and indexes.
- The `sim_now()` function for simulated transaction time.
- Temporal exclusion constraints used to enforce data integrity.

The script prepares the database for storing and maintaining bitemporal information.

### `02_data.sql` – Initial Data

Loads the initial database state, identified as **Event E1 – Initial Load**.

The initial dataset includes:

- 5 owners.
- 50 tenants.
- 5 property managers.
- 6 apartments.
- 60 lease version records.
- 30 apartment manager version records.
- 30 apartment rent version records.

This represents 120 initial bitemporal version records across the three version tables.

### `03_timeline.sql` – Temporal Event Timeline

Implements the subsequent timeline of events, E2–E9, using simulated transaction times.

The timeline demonstrates how the database handles changes to historical information over time. Depending on the event, the database can record new facts, correct previously recorded information, or change the validity of existing facts while preserving historical versions.

The timeline is intended to demonstrate the difference between when a fact is valid and when that fact becomes known to the database.

### `04_views.sql` – Database Views

Defines views for accessing and analyzing the stored rental information.

These views provide reusable query interfaces for examining database state and temporal information without requiring the same underlying queries to be rewritten each time.

The script also includes the `v_integrity_violations` view, which can be used to inspect detected integrity violations.

### `05_tests.sql` – Validation and Tests

Contains SQL tests and validation queries for checking the database implementation.

The tests help verify the stored data, temporal behavior, and integrity rules after the relevant scripts have been executed.

Run the tests after preparing the schema and loading the required data and timeline events.

### `06_advanced_a1.sql` – Advanced Scenario A1

Contains additional SQL operations for an advanced scenario.

This script extends the core implementation with further temporal database operations and provides an additional scenario for examining the behavior of the database.

### `06_advanced_a2.sql` – Advanced Scenario A2

Contains a second advanced SQL scenario.

Together, the advanced scripts provide additional operations for exploring the database beyond the initial state and standard event timeline.

For the exact operations and preconditions of each advanced scenario, consult the corresponding SQL script.

### `ER Diagram.pdf` – Entity-Relationship Diagram

Provides a graphical representation of the database structure and relationships between its entities.

The diagram can be used to understand the relational model before examining the SQL implementation.

---

# Requirements

To use this project, install the following software.

## PostgreSQL 18.6

PostgreSQL is the database server that stores the database, tables, constraints, functions, and views.

During installation, make sure the PostgreSQL server and database tools are installed.

The default local port used by this project is:

```text
5432
```

## pgAdmin 4

pgAdmin 4 is the graphical interface used to connect to PostgreSQL, create databases, and execute SQL scripts.

The scripts can be executed using pgAdmin's **Query Tool**.

---

# Setting Up PostgreSQL

After installing PostgreSQL 18.6, make sure that the PostgreSQL server is running.

Open pgAdmin 4 and connect to your PostgreSQL server.

A typical local connection uses:

```text
Host: localhost
Port: 5432
Username: postgres
Password: <your PostgreSQL password>
```

The server may appear in pgAdmin under a name such as:

```text
Servers
└── PostgreSQL 18
```

The server display name can differ depending on the local installation.

---

# Creating the Database

The SQL scripts create the `rentals` schema automatically. You do not need to create this schema manually.

However, you must create a separate PostgreSQL database for the project.

For example:

```text
ApartmentRentals
```

In pgAdmin 4:

1. Open **Servers**.
2. Expand your PostgreSQL server.
3. Right-click **Databases**.
4. Select **Create → Database**.
5. Enter `ApartmentRentals` as the database name.
6. Click **Save**.

Select the new database and open:

**Tools → Query Tool**

Make sure every project script is executed against this database.

---

# Running the SQL Scripts

## Recommended execution order

Execute the scripts in the following order for the standard project workflow:

```text
01_schema.sql
      |
      v
02_data.sql
      |
      v
03_timeline.sql
      |
      v
04_views.sql
      |
      v
05_tests.sql
```

The advanced scenarios are separate scripts:

```text
06_advanced_a1.sql
06_advanced_a2.sql
```

Execute the advanced scripts after preparing the database state required by each scenario. Check their contents for specific prerequisites and whether they modify the database.

**Important:** Some scripts may change the database state. Do not assume that the advanced scenarios can be executed consecutively or repeatedly without resetting the database.

## Step 1 – Create the Schema

Open `01_schema.sql` in pgAdmin's Query Tool and execute the complete script.

The script creates the schema and its database objects, including:

```text
rentals
├── tx_registry
├── owner
├── tenant
├── apartment
├── property_manager
├── lease_version
├── apartment_manager_version
└── apartment_rent_version
```

The list above summarizes the main objects; consult the script for the complete schema definition.

## Step 2 – Load the Initial Data

Open `02_data.sql` and execute the complete script.

This represents **E1 – Initial Load**.

The script uses the simulated transaction clock:

```sql
SET app.sim_now = '2026-01-01 09:00:00+00';
```

The `sim_now()` function defined in `01_schema.sql` reads this setting to determine the simulated transaction time.

The initial dataset should contain the following records:

| Table | Expected rows |
|---|---:|
| `owner` | 5 |
| `tenant` | 50 |
| `property_manager` | 5 |
| `apartment` | 6 |
| `lease_version` | 60 |
| `apartment_manager_version` | 30 |
| `apartment_rent_version` | 30 |
| **Total version records** | **120** |

These counts describe the expected initial E1 state, before applying the subsequent timeline events.

## Step 3 – Apply the Timeline

Open `03_timeline.sql` and execute it after the initial data has been loaded.

This script processes the subsequent events, E2–E9, and demonstrates the temporal behavior of the database.

Because the timeline can modify the database state, execute it only after the required initial data has been prepared.

## Step 4 – Create the Views

Open `04_views.sql` and execute it after the schema and required data have been prepared.

This creates the views used to inspect the database and analyze its integrity.

For example, `v_integrity_violations` provides a query interface for examining detected integrity violations.

## Step 5 – Run the Tests

Open `05_tests.sql` and execute the test script.

Review the query results and any reported violations. The expected outcome depends on the assertions and integrity conditions defined by the project.

If a test reports a violation, inspect the corresponding query and the current database state before assuming that the result is an execution error.

## Step 6 – Execute the Advanced Scenarios

The project also includes:

- `06_advanced_a1.sql`
- `06_advanced_a2.sql`

These scripts should be executed according to their documented preconditions. If they change data or transaction history, use an appropriate database state or a separate test database when necessary.

For reproducible results, record which scripts have already been executed before running an advanced scenario.

---

# Understanding Bitemporal Data

Bitemporal modeling tracks two independent dimensions of time.

| Dimension | Meaning | Example |
|---|---|---|
| Valid Time (VT) | When a fact is true in the real world | A rental agreement is valid starting on 1 March |
| Transaction Time (TT) | When the database records the fact | The agreement is recorded on 5 March |

For example, suppose a lease starts on 1 March but is entered into the database on 5 March.

- The valid time begins on 1 March.
- The transaction time begins on 5 March.

This distinction makes it possible to represent late-recorded information and corrections without treating the time a fact was entered as the time it became true.

The project uses a simulated clock so that temporal events can be executed at controlled transaction times. This supports reproducible experiments and makes it easier to inspect how the database evolves.

---

# Important: Resetting and Rerunning Scripts

## Resetting the schema

The schema script uses:

```sql
DROP SCHEMA IF EXISTS rentals CASCADE;
```

Running `01_schema.sql` again removes the existing `rentals` schema and its dependent objects before recreating them.

**This deletes the existing project data and temporal history in that schema.** Do not rerun it against a database containing information you need to preserve.

## Reloading the initial data

`02_data.sql` prepares the initial E1 state. If it is designed to reset the data, rerunning it will replace the current state with the initial state.

Do not run `02_data.sql` after `03_timeline.sql` if you want to preserve the E2–E9 timeline.

## Rerunning views and tests

The behavior of these scripts depends on their SQL definitions. Check whether they use `CREATE OR REPLACE`, drop existing objects, modify data, or assume a particular database state before executing them again.

## Rerunning advanced scenarios

The advanced scripts may depend on specific data or transaction history. Inspect their operations before rerunning them. When testing different scenarios, a separate development database can help prevent one experiment from affecting another.

---

# Troubleshooting

### Connection refused

Check that the PostgreSQL service is running and that the host and port are correct.

### Password authentication failed

Use the password configured for your local PostgreSQL user. The password is installation-specific and is not included in this repository.

### Relation does not exist

Make sure you are connected to the correct database and have executed the required scripts in order. The project tables belong to the `rentals` schema.

### Temporal constraint violation

Review the affected records and the temporal constraints defined in `01_schema.sql`. An exclusion constraint may reject overlapping periods or other combinations that violate the project's temporal integrity rules.
