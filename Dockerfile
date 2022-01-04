# base image with env vars
FROM timescale/timescaledb:latest-pg12 AS base

ENV POSTGRES_DB defaultdb
ENV POSTGRES_PASSWORD password

ENV PG_CRON_VERSION 1.3.1


# build pgextwlist
FROM base AS pgextwlist

RUN apk update && apk add --no-cache --virtual .deps \
    git \
    make \
    gcc \
    musl-dev \
    clang \
    llvm \
    && git clone https://github.com/dimitri/pgextwlist.git \
    && cd pgextwlist \
    && make \
    && make install \
    && apk del .deps


# build pg_cron
FROM base AS pg_cron

RUN apk update && apk add --no-cache --virtual .deps \
    build-base \
    ca-certificates \
    clang-dev llvm12 \
    openssl \
    tar \
    && wget -O /pg_cron.tgz https://github.com/citusdata/pg_cron/archive/v$PG_CRON_VERSION.tar.gz \
    && tar xvzf /pg_cron.tgz \
    && cd pg_cron-$PG_CRON_VERSION \
    && sed -i.bak -e 's/-Werror//g' Makefile \
    && sed -i.bak -e 's/-Wno-implicit-fallthrough//g' Makefile \
    && make \
    && make install \
    && apk del .deps


# final image
FROM base

# pgextwlist
RUN mkdir -p /usr/local/lib/postgresql/plugins \
    && sed -r -i "s/[#]*\s*(local_preload_libraries)\s*=\s*'(.*)'/\1 = 'pgextwlist,\2'/;s/,'/'/" /usr/local/share/postgresql/postgresql.conf.sample \
    && echo "extwlist.extensions = 'tablefunc,hstore,pgcrypto'" >> /usr/local/share/postgresql/postgresql.conf.sample \
    && echo "extwlist.custom_path = '/var/lib/pgsql-extwlist-custom'" >> /usr/local/share/postgresql/postgresql.conf.sample

COPY --from=pgextwlist /pgextwlist/pgextwlist.so /usr/local/lib/postgresql/plugins/pgextwlist.so

# pg_cron
COPY --from=pg_cron /usr/local/lib/postgresql/pg_cron.so /usr/local/lib/postgresql/
COPY --from=pg_cron /usr/local/share/postgresql/extension/pg_cron* usr/local/share/postgresql/extension/

RUN mkdir -p /var/lib/pgsql-extwlist-custom/pg_cron \
    && sed -r -i "s/[#]*\s*(shared_preload_libraries)\s*=\s*'(.*)'/\1 = 'pg_cron,\2'/;s/,'/'/" /usr/local/share/postgresql/postgresql.conf.sample \
    # TODO: set this at runtime \
    && echo "cron.database_name = 'defaultdb'" >> /usr/local/share/postgresql/postgresql.conf.sample \
    && echo "GRANT USAGE ON SCHEMA cron TO @database_owner@" >> /var/lib/pgsql-extwlist-custom/pg_cron/after-create.sql \
    && sed -r -i "s/[#]*\s*(extwlist.extensions)\s*=\s*'(.*)'/\1 = 'pg_cron,\2'/;s/,'/'/" /usr/local/share/postgresql/postgresql.conf.sample

# postgres_fdw
RUN mkdir -p /var/lib/pgsql-extwlist-custom/postgres_fdw \
    && echo "GRANT USAGE ON FOREIGN DATA WRAPPER postgres_fdw TO @database_owner@" >> /var/lib/pgsql-extwlist-custom/postgres_fdw/after-create.sql \
    && sed -r -i "s/[#]*\s*(extwlist.extensions)\s*=\s*'(.*)'/\1 = 'postgres_fdw,\2'/;s/,'/'/" /usr/local/share/postgresql/postgresql.conf.sample

# custom bootstrap script to run at startup
COPY bootstrap-docker.sql /docker-entrypoint-initdb.d/bootstrap-docker.sql
