# Evidence standard

Every implementation issue should leave enough public-safe evidence that a later agent can understand what was tested, reproduce it, and distinguish provider facts from measurements.

## Evidence location

Use:

```text
evidence/<issue-id-or-number>/
```

Typical contents:

- `README.md` — concise result and interpretation;
- `commands.txt` — commands actually run where useful;
- `environment.txt` — relevant tool/platform versions;
- `raw/` — bounded raw outputs suitable for Git;
- `summary.csv` or `summary.json` — machine-readable measurements where applicable.

Do not commit large binary test files, private archives, credentials or entire application databases merely as evidence.

## Required metadata for measurements

Record when relevant:

- UTC timestamp and timezone/context;
- tool and version;
- exact command/arguments;
- test data size;
- free space/quota before and after;
- transfer direction and byte count for network tests;
- repetitions;
- observed median/range/outliers;
- whether other known jobs were running;
- provider plan/tenant facts that materially affect interpretation.

## Redaction

Before committing outputs, remove or replace:

- passwords;
- API tokens;
- session cookies;
- SSH private keys;
- private repository credentials/URLs containing tokens;
- user email addresses unless deliberately public;
- provider account IDs if unnecessary;
- application secrets;
- personal filenames/content unrelated to the test.

Hostname and username should be redacted from evidence unless their presence materially helps diagnosis. Prefer placeholders such as `<APPBOX_HOST>` and `<APPBOX_USER>`.

## Performance evidence language

Use disciplined terms:

- **measured on this tenant** — observed directly;
- **provider-advertised** — documented marketing/specification;
- **host-reported** — visible from shared-host commands but not known to be tenant entitlement;
- **inferred** — interpretation supported by measurements but not directly observable.

Never convert host-reported CPU/RAM totals into a claim about allocated resources.

## Shared-host statistics

For performance-sensitive tests, prefer:

- multiple repetitions;
- median plus min/max or percentile range;
- timestamps;
- short notes on exceptional outliers.

One unusually fast or slow sample is not a platform verdict.

## Issue conclusion format

Every completed issue should state:

1. **Result:** pass / pass with caveats / blocked / not useful.
2. **Evidence:** links to committed evidence paths.
3. **Decisions changed:** any update to `DECISIONS.md`.
4. **New risks/unknowns:** follow-up issue if needed.
5. **Cleanup:** test data/services removed or intentionally retained.
