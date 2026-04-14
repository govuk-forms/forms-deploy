# GOV.UK Forms Development

This is a guide to getting the GOV.UK Forms development environment up and running.

This repo lives at:
https://github.com/govuk-forms/forms-deploy

The components which make up the service are:

- https://github.com/govuk-forms/forms-runner
- https://github.com/govuk-forms/forms-admin
- https://github.com/govuk-forms/forms-product-page

## How it works
Each of the components above has a Dockerfile in its repo which is used to build
a docker image. The file `compose.yaml` defines the configuration for using
those images to run GOVUK Forms locally including a Postgres and Redis
container.

The local repo for each component is mounted into its corresponding container,
for example the local directory `../forms-admin` is mounted into the forms-admin
container under the `/app` directory so that any changes made to that
component's code locally is immediately apparent in the locally running
services.

### Setting up the databases

There is a single postgres container defined within the docker-compose setup
which is used by all apps.

The command for each app in the Docker Compose file includes running
`bin/setup` in the app repo. For forms-admin and forms-runner this will create
the database and prepare test forms and local dev users on the first run. On
subsequent runs it will apply any outstanding database migrations.

If you need to connect to the postgres instance directly you can use `psql -h
localhost -p 5432 -U postgres` and enter `postgres` for the password when
prompted. To view available databases use `\l` and to connect to one use
`\c databasename`. For more information view psql help page.

## Commands for running the whole thing in docker.

You need to check out all three projects in the parent directory of this repo.
Your directory structure should look like this:

```
top-level/
├── forms-admin
├── forms-product-page
└── forms-runner
└── forms-deploy
    └── local
        ├── README.md
        └── compose.yaml
```

Then run:
```bash
docker compose up
```

Note that you might need to disconnect from the GDS VPN when running this script as otherwise npm might fail to install packages.

Wait a while as the images are downloaded and built. Eventually you should see
the screen fill with logging information as the postgres, redis and the forms
services start.

You should be able to open the admin interface on http://localhost:3000 , and
the runner on http://localhost:3001

To stop the services from running, press `Ctrl-c` and then enter:
```bash
docker compose stop
```

If you make changes to the docker file:

```bash
docker compose up --build
```
