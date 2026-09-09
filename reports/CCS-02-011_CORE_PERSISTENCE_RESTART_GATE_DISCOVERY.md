# CCS-02-011 Core Persistence Restart Gate Discovery

Status: DISCOVERY COMPLETE / SUCCESSOR REQUIRED / IMPLEMENTATION NOT AUTHORIZED
Date: 2026-09-09
Parent: CCS-02 under IMP-022
Dependency: CCS-02-010; semantic predecessors CCS-02-003/004/005/006

The smallest closure leaf is one gate test and one implementation report. It must use only a fresh
temporary SQLite database, execute the existing migration path, seed a legal two-Workspace fixture,
commit, construct a new SQLiteConnectionFactory and reopen the database. The gate proves durable
Workspace/Project/Asset/Content/ContentVersion/head/status/row-version state, database FK/unique
constraints, stale CAS rollback with no partial/orphan write, exact Content state edges, version
deletion rejection, and concealed cross-Workspace access.

It cannot amend application, domain, repository, persistence, migration or configuration code. It
does not own pure helper validation, API/UI behavior, provider/network, credentials, runtime
database, dependency, deployment or publication behavior.
