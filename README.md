# PSQL Authorization

### A conceptual model of how to handle permissions and privileges for web users in PostgreSQL

This repository consists of a postgreSQL db, a series of tests (with associated sql), and documentation on the sigificance of each test and the security princple being implemented and tested.

The concepts start out basic with general db roles and a single table with row level security. With each subsequent test file the complexity increases with the hopes of evolving to a robust user management system that can be applied across applications.

### How to use this repository

This application is dockerized such that on initialization the database will create itself AND the tests will run in a python3 environment. Once the tests complete that container will exit. In the docker-logs you should see `14 tests passed`, signifiying all the tests have passed!!

Explanations behind each test can be found in the `/docs` directory. Python tests are in the `/auth` directory and all SQL files are located in `/auth/fixtures`. This repository is meant for thoughtful exploration of the different ways and designs for database centered authentication. Although some application code will always be necesary, there is a balance to be struck. PostgreSQL has robust capabilities for handling data security and web-user tracking and it can add extra protection from sql-injections and other flaws in application code.

### Tests Overview

1. Basic Auth - exploration of db roles and row level security.
2. Auth Schema and basic RLS - user storage in db (Web/Application Users)
3. Web Users and RLS - incorporate the auth schema and rls
4. Postgres Logins for Web Users - ensuring RLS for DB roles

#### Misscel thoughts:

One base DB user that can be given for all application users, and handle individual permissions via row level security.

Ideal things we want in an access control system.

- A custom schema for handling users (application users)
- One db connection
- Secure from vulnerable application code
- Reusable db rolenames
- Easily manage dynamic permissions (a custom permission schema)

DB needs to know specific info about the user, how is that accomplished?

- Security definer functions to sign and validate using secret keys?

Currently these tests use UUIDs and rely on their "randomness" to secure database sessions. There is debate to the whether or not the UUID algorithms create "properly random" codes that can't be re-engineered. However, there are other methods for handling session authentication such as JSON Web Tokens, which are widely used in security.

#### Resources:

https://www.2ndquadrant.com/en/blog/application-users-vs-row-level-security/
