# custom-moodle-docker: Docker Containers for Moodle Developers
[![Build Status](https://travis-ci.org/moodlehq/moodle-docker.svg?branch=master)](https://travis-ci.org/moodlehq/moodle-docker/branches)

This repository contains Docker configuration aimed at Moodle developers and testers to easily deploy a testing environment for Moodle.

## Features:
* All supported database servers (PostgreSQL, MySQL, Micosoft SQL Server, Oracle XE)
* Preferred PostgresSQL (dockerfiles/postgres.docker) 
* Behat/Selenium configuration for Firefox and Chrome
* Catch-all smtp server and web interface to messages using [MailHog](https://github.com/mailhog/MailHog/)
* All PHP Extensions enabled configured for external services (e.g. solr, ldap)
* Ngix webserver with configs
* Php-fpm (dockerfiles/phpfpm.docker)
* Jenkins (dockerfiles/jenkins.docker)
* Docker hostmanager (https://github.com/iamluc/docker-hostmanager)
* Xdebuge with phpfpm (php/xdebug.ini)
* Zero-configuration approach
* Backed by [automated tests](https://travis-ci.org/moodlehq/moodle-docker/branches)
* Mounted volumes with local user's uid and gid (base.yml - CONTAINER_USER_ID, CONTAINER_GROUP_ID)

## Prerequisites
* [Docker](https://docs.docker.com) and [Docker Compose](https://docs.docker.com/compose/) installed
    * docker 19 or later
    * docker-compose 1.18 or later
* 3.25GB of RAM (if you choose [Microsoft SQL Server](https://docs.microsoft.com/en-us/sql/linux/sql-server-linux-setup#prerequisites) as db server)

## Quick start

Please create a moodle folder (``mkdir -p mount/moodle``) deploy moodle into it

Then ``moodle-docker-compose`` can take care of setting up directories and calling docker-compose:

```bash
# Start up containers
./bin/moodle-docker-compose up -d

# Wait for DB to come up (important for oracle/mssql)
./bin/moodle-docker-wait-for-db

# Work with the containers (see below)
# [..]

# Shut down and destroy containers
./bin/moodle-docker-compose down

# Shut down and destroy containers, and deletes all folders (except 'moodle') under 'mount'
# Use this if you need a clean start
./bin/moodle-docker-clean

# Docker images are cached and are not delete with moodle-docker-clean, so to rebuild them
# (time consuming)
./bin/moodle-docker-compose build
```

## Use containers for running behat tests

```bash
# Initialize behat environment
./bin/moodle-docker-compose exec phpfpm php admin/tool/behat/cli/init.php
# [..]

# Run behat tests
./bin/moodle-docker-compose exec phpfpm php admin/tool/behat/cli/run.php --tags=@auth_manual
Running single behat site:
Moodle 3.4dev (Build: 20171006), 33a3ec7c9378e64c6f15c688a3c68a39114aa29d
Php: 7.1.9, pgsql: 9.6.5, OS: Linux 4.9.49-moby x86_64
Server OS "Linux", Browser: "firefox"
Started at 25-05-2017, 19:04
...............

2 scenarios (2 passed)
15 steps (15 passed)
1m35.32s (41.60Mb)
```

Notes:
* The behat faildump directory is exposed at http://localhost:8000/_/faildumps/.

## Use containers for running phpunit tests

```bash
# Initialize phpunit environment
./bin/moodle-docker-compose exec phpfpm php admin/tool/phpunit/cli/init.php
# [..]

# Run phpunit tests
./bin/moodle-docker-compose exec phpfpm vendor/bin/phpunit auth_manual_testcase auth/manual/tests/manual_test.php
Moodle 3.4dev (Build: 20171006), 33a3ec7c9378e64c6f15c688a3c68a39114aa29d
Php: 7.1.9, pgsql: 9.6.5, OS: Linux 4.9.49-moby x86_64
PHPUnit 5.5.7 by Sebastian Bergmann and contributors.

..                                                                  2 / 2 (100%)

Time: 4.45 seconds, Memory: 38.00MB

OK (2 tests, 7 assertions)
```

## Use containers for manual testing

```bash
# Initialize Moodle database for manual testing
./bin/moodle-docker-compose exec phpfpm php admin/cli/install_database.php --agree-license --adminpass=admin --adminemail=admin@localdomain.localdomain --fullname=admin --shortname=admin
```

Notes:
* Admin username is ``admin`` and password is ``admin``.
* Moodle is configured to listen on `http://webserver.localdomain/`.
* Mailhog is listening on `http://localhost:8000/_/mail` to view emails which Moodle has sent out.

## Using VNC to view behat tests

If `MOODLE_DOCKER_SELENIUM_VNC_PORT` is defined, selenium will expose a VNC session on the port specified so behat tests can be viewed in progress.

For example, if you set `MOODLE_DOCKER_SELENIUM_VNC_PORT` to 5900..
1. Download a VNC client: https://www.realvnc.com/en/connect/download/viewer/
2. With the containers running, enter 0.0.0.0:5900 as the port in VNC Viewer. You will be prompted for a password. The password is 'secret'.
3. You should be able to see an empty Desktop. When you run any Behat tests a browser will popup and you will see the tests execute.

## Stop and restart containers

`./bin/moodle-docker-compose down` which was used above after using the containers stops and destroys the containers. If you want to use your containers continuously for manual testing or development without starting them up from scratch everytime you use them, you can also just stop without destroying them. With this approach, you can restart your containers sometime later, they will keep their data and won't be destroyed completely until you run `./bin/moodle-docker-compose down`.

```bash
# Stop containers
./bin/moodle-docker-compose stop

# Restart containers
./bin/moodle-docker-compose start
```

## Environment variables

You can change the configuration of the docker images by setting various environment variables before calling `bin/moodle-docker-compose up`.

| Environment Variable                      | Mandatory | Allowed values                        | Default value | Notes                                                                        |
|-------------------------------------------|-----------|---------------------------------------|---------------|------------------------------------------------------------------------------|
| `MOODLE_DOCKER_DB`                        | yes       | pgsql, mariadb, mysql, mssql, oracle  | none          | The database server to run against                                           |
| `MOODLE_DOCKER_WWWROOT`                   | yes       | path on your file system              | none          | The path to the Moodle codebase you intend to test                           |
| `MOODLE_DOCKER_PHP_VERSION`               | no        | 7.3, 7.2, 7.1, 7.0, 5.6                         | 7.1           | The php version to use                                                       |
| `MOODLE_DOCKER_BROWSER`                   | no        | firefox, chrome                       | firefox       | The browser to run Behat against                                             |
| `MOODLE_DOCKER_PHPUNIT_EXTERNAL_SERVICES` | no        | any value                             | not set       | If set, dependencies for memcached, redis, solr, and openldap are added      |
| `MOODLE_DOCKER_WEB_HOST`                  | no        | any valid hostname                    | localhost     | The hostname for web                                |
| `MOODLE_DOCKER_WEB_PORT`                  | no        | any integer value                     | 8000          | The port number for web. If set to 0, no port is used                        |
| `MOODLE_DOCKER_SELENIUM_VNC_PORT`         | no        | any integer value                     | not set       | If set, the selenium node will expose a vnc session on the port specified    |

## Advanced usage

As can be seen in [bin/moodle-docker-compose](https://github.com/ratedcrypto/moodle-docker/blob/master/bin/moodle-docker-compose),
this repo is just a series of docker-compose configurations and light wrapper which make use of companion docker images. Each part
is designed to be reusable and you are encouraged to use the docker[-compose] commands as needed.

## Resolving Linux xdebug issue

If you are on Linux please check if your firewall is blocking all inbound connections, if it is then connections from docker containers to phpstorm on the host then xdebug in docker may not work with php storm:

```bash
sudo iptables -n -L INPUT
```

And look for:

```bash
REJECT     all  --  anywhere             anywhere             reject-with icmp-host-prohibited
```

Which blocks all inbound connections and xdebug in docker may not work with PhpStorm. For now a workaround is to remove the rule by the line number, given some line number N, enter:

```bash
sudo iptables -D INPUT N
```

And it would remove the block all inbound rule until the next reboot of the docker host. Alternatively you can add a rule to allow all connections from the any default docker network instead:

```bash
sudo iptables -I INPUT 1 -s 172.0.0.0/8 -j ACCEPT
```

This will be added as the first rule in the INPUT chain.
This does not seem to be a problem on a fresh install of Ubuntu 18.04, as it came with no inbound firewall rule.

## Companion docker images

The following Moodle customised docker images are close companions of this project:

* [moodle-php-apache](https://github.com/moodlehq/moodle-php-apache): Apache/PHP Environment preconfigured for all Moodle environments
* [moodle-db-mssql](https://github.com/moodlehq/moodle-db-mssql): Microsoft SQL Server for Linux configured for Moodle
* [moodle-db-oracle](https://github.com/moodlehq/moodle-db-oracle): Oracle XE configured for Moodle

## Contributions

Are extremely welcome!
