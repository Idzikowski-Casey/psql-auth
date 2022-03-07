# PSQL Authorization

### A conceptual model of how to handle permissions and privileges for web users in PostgreSQL

This repository consists of a postgreSQL db, a series of tests (with associated sql), and documentation on the sigificance of each test and the security princple being implemented and tested.

The concepts start out basic with general db roles and a single table with row level security. With each subsequent test file the complexity increases with the hopes of evolving to a robust user management system that can be applied across applications.

### Overview

1. Basic Auth - exploration of db roles and row level security.
2. Auth Schema - user storage in db (Web/Application Users)
3. Web Users and RSL - incorporate the auth schema and rls

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

#### Resources:

https://www.2ndquadrant.com/en/blog/application-users-vs-row-level-security/
