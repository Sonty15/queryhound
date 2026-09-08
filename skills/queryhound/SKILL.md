---
name: queryhound
description: Use when the user pastes MySQL SHOW FULL PROCESSLIST output and asks where a running query is coming from, or invokes /queryhound. Traces each query to the repo/file/line that issued it using a repos.yaml of local checkouts, explains what the query does, and flags SQL quality issues.
---

# QueryHound

Given output from `SHOW FULL PROCESSLIST` and a `repos.yaml` config, find which
configured repo (and file/line) issued each running query, explain what it
does, and flag whether it's a well-written query.

## 1. Load config

Look for `repos.yaml` in the current working directory (or a path the user
gives you explicitly). It looks like:

```yaml
repos:
  - name: example-repo
    path: /absolute/path/to/example-repo
```

If the file is missing or has an empty `repos` list, stop and tell the user
to create one (there's nothing to search). Read each entry's `path` — if the
path doesn't exist or isn't a git repo (no `.git`), treat that repo as a
**config error**, skip it, and note it in the final report.

## 2. Prepare every repo (every run, no exceptions)

For each repo that passed the config check, run, in its directory:

```bash
git branch --show-current
```

- If the result is not `main` and not `master` → **skip this repo**. Reason:
  `"on branch <branch>, expected main/master"`.

```bash
git status --porcelain
```

- If this prints anything → **skip this repo**. Reason:
  `"uncommitted changes present"`.

Only if both checks pass:

```bash
git pull
```

Repos that fail either check are never searched — never `git checkout`,
`stash`, or otherwise modify a repo to make it searchable. Skipped repos
still appear in the final report, name + reason, so the user knows the
search wasn't exhaustive.

## 3. Parse the pasted processlist

The user pastes the output of `SHOW FULL PROCESSLIST` (table form, as the
`mysql` client prints it, or an equivalent list of rows). Extract every row
that has a non-empty, non-`NULL` `Info` column — that's the SQL text. Ignore
rows where `Info` is `NULL` or blank (idle connections). Keep each row's `Id`
alongside its `Info` so the report can reference which connection a query
came from.

## 4. Match each query to a repo

For each query pulled from the processlist:

1. **Normalize it in your head**: strip out literal values — numbers,
   quoted strings, `IN (...)` lists — and note the shape: which tables,
   which columns in `WHERE`/`JOIN`/`ORDER BY`, roughly how many clauses.
   Example: `WHERE customer_id = 42 AND status = 'pending'` normalizes to
   the same shape as `WHERE customer_id = ? AND status = ?` or
   `WHERE customer_id = :id AND status = :status`.
2. **Derive grep terms** from the normalized query — table name(s) are
   almost always present in matching code, so start there:
   ```bash
   grep -rn "orders" <repo-path> --include="*.py" --include="*.sql" --include="*.rb" --include="*.js" --include="*.ts" --include="*.php"
   ```
   (adjust extensions to what the repo actually uses)
3. **Open every candidate hit** and check whether its structure lines up
   with the normalized query — same table, same columns referenced, same
   general clause shape, allowing for placeholders (`?`, `:name`, `%s`,
   `$1`, string interpolation) standing in for the literals you stripped.
   A candidate that touches a different table, or is missing a `WHERE`
   condition the running query has, is not a match — keep looking.
4. Only search repos that passed step 2 (prepared). If a query's shape
   doesn't line up with anything in any prepared repo, mark it
   **"not found in any configured repo"** — don't force a weak match.
5. Record the strongest match as `<repo-name>:<relative/file/path>:<line>`.

## 5. Report

For each query (in the order it appeared in the pasted processlist), output:

```
### Query [<Id>]
<the raw SQL>

**Origin:** <repo-name>:<file>:<line>   (or: not found in any configured repo)

**What it does:** <plain-language explanation — if matched, ground this in
the surrounding code (which function/endpoint issues it and why); if not
matched, a short explanation from the SQL alone is enough>

**Quality:** <one of "looks fine" or the specific issues you actually see,
e.g. "`SELECT *` — pulls every column, prefer listing only what's used";
"no `LIMIT` on a table that can grow unbounded"; "`WHERE`/`JOIN` on a column
that likely isn't indexed — check with `EXPLAIN`"; "unnecessary nested
subquery — could likely be a single `JOIN`". List every issue you actually
see; don't invent problems that aren't there. Quality is assessed from the
SQL itself and applies whether or not a repo match was found.>
```

After all queries, add (omit this section if nothing was skipped):

```
### Repos skipped during prep
- <repo-name>: <reason>
```
