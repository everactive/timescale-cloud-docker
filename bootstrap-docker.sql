/* create roles to mimic behavior seen on Timescale Cloud
 *
 * it doesn't matter who creates a role, so we create all roles with the initial superuser postgres
 */

BEGIN;

-- this tsdbadmin mimics the role of the same name provided on Timescale Cloud
-- tsdbadmin has very wide privileges to schemas and objects
-- we might never mimic it perfectly, but we can make it "good enough"
CREATE USER tsdbadmin WITH CREATEROLE CREATEDB PASSWORD 'tsdbadmin';

ALTER DATABASE defaultdb OWNER TO tsdbadmin;

GRANT ALL PRIVILEGES ON DATABASE defaultdb TO tsdbadmin;

DO $$ DECLARE
    _schemas TEXT[] := ARRAY[
        '_timescaledb_cache',
        '_timescaledb_catalog',
        '_timescaledb_config',
        '_timescaledb_internal'
    ];
    _schema TEXT;

BEGIN

    FOREACH _schema IN ARRAY _schemas LOOP
        EXECUTE format('GRANT ALL ON                  SCHEMA %I TO tsdbadmin WITH GRANT OPTION', _schema);
        EXECUTE format('GRANT ALL ON ALL TABLES IN    SCHEMA %I TO tsdbadmin WITH GRANT OPTION', _schema);
        EXECUTE format('GRANT ALL ON ALL SEQUENCES IN SCHEMA %I TO tsdbadmin WITH GRANT OPTION', _schema);
    END LOOP;


    ALTER DEFAULT PRIVILEGES
        GRANT ALL ON TABLES TO tsdbadmin;

    ALTER DEFAULT PRIVILEGES
        GRANT ALL ON SEQUENCES TO tsdbadmin;

END $$;

COMMIT;
