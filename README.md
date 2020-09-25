# ⏲️ Timescale Cloud in Docker 🐋

A Docker image to ease local development of a [Timescale Cloud](https://www.timescale.com/cloud)-hosted database.

The Timescale Cloud service exhibits behaviors which differ from the [official Docker images](https://hub.docker.com/r/timescale/timescaledb) in ways that can make it difficult to reproduce for local development. The Timescale Cloud service does far more than can fit into a single Docker image, so this project is a best-effort mock to minimize "but it worked on my machine!" errors.

Here at [Everactive](https://everactive.com/), we use this image both for developing the database itself (we use [`sqitch`](https://sqitch.org/) for migrations-as-code), and for creating local mocks of that database when developing _against_ it (e.g. for our [Public API](https://api-spec.data.everactive.com/)). We could instead use forks of live databases, but we like our Docker-based workflows and the ability to easily blow away and recreate a local instance. This lets us iterate much more quickly, particularly when writing migrations.

Timescale Cloud has two categories of non-standard behavior we're concerned with:
- it does not provide access to a true `SUPERUSER` role, but rather a role `tsdbadmin` that behaves in a similar-but-different fashion
- it provides many extensions which can be installed by non-superusers (in vanilla Postgres <= v13, only superusers have this privilege)

This container also hardcodes several pieces of configuration (database name, passwords) to maximize ease-of-use. **This makes this project extremely insecure and unsuitable for use in any production or public environment**


## Usage

Until we're on DockerHub, this container must be built locally.

```bash
docker build . -t timescale-cloud-docker
```

Then run this image in the background.

```bash
docker run --rm -d -p 5432:5432 --name tsdb timescale-cloud-docker
```

Now you can login without thinking about ports or passwords using `docker exec` and the in-container `psql` client:

```bash
docker exec -it tsdb psql postgres://tsdbadmin@/defaultdb
```

External clients will need a bit more information:

```bash
psql postgres://tsdbadmin:tsdbadmin@localhost/defaultdb
```

When you're done, turn it off. We used `--rm` above, so this will also remove the image.

```bash
docker stop tsdb
```


## Feature Details

### Pseudo-superuser

The `tsdbadmin` role Timescale Cloud gives us is not a superuser, but owns most objects the default superuser otherwise would. It also receives permissions to new objects not through default privileges, but via a background job which detects new objects and runs `GRANT...TO tsdbadmin` statements.

We mimic the default permissions by changing ownership in a startup SQL script. We mimic the new-object-grants with altered default permissions.

### Whitelisted Extensions

Timescale Cloud uses [`pgextwlist`](https://github.com/dimitri/pgextwlist) to whitelist extensions so ordinary users can activate them. We do the same, though we do not cover all the extensions installed-and-whitelisted by Timescale Cloud.

### PG Version

We currently only offer a PG12 image. If you need PG11 instead, simply change the tag for the base image at the top of the `Dockerfile`. Unfortunately this does not work for PG13, but we would like to offer a PG13 solution in the future.
