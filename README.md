# QueryHound

Trace a running MySQL query from `SHOW FULL PROCESSLIST` back to the repo,
file, and line that issued it — explains what the query does and flags SQL
quality issues.

## Installation (Claude Code)

1. Register this repo as a plugin marketplace:
   ```
   /plugin marketplace add Sonty15/queryhound
   ```
2. Install the plugin from it:
   ```
   /plugin install queryhound@queryhound
   ```

## Setup

Copy `repos.example.yaml` to `repos.yaml` (in the directory you'll invoke the
skill from) and list the local repos you want QueryHound to search:

```yaml
repos:
  - name: my-app
    path: /home/you/code/my-app
```

`repos.yaml` is gitignored — it holds machine-specific local paths, so it's
never committed.

## Usage

Paste the output of `SHOW FULL PROCESSLIST` and invoke `/queryhound`.
QueryHound will:

1. Make sure each configured repo is on `main`/`master` and up to date,
   skipping (and reporting) any repo that isn't
2. Match each running query to the file/line that issued it
3. Explain what each query does and flag any quality issues

## License

MIT
