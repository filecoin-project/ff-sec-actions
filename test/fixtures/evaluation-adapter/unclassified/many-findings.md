# Evaluation: fixture-scan

- Tool: `fixture@1.2.3`
- Completion: **complete** — validated findings are advisory
- Findings: **25**; highest severity: **high**
- Gate: **pass** (advisory)
- Scope: `repository`
- Evidence artifact: `fixture-sarif`; file: `@TEST_ROOT@/many.sarif`
- Coverage included: repository files
- Coverage limitations: fixture limitation

## Findings

| Severity | Rule | Location | What was found | Rule guidance |
|---|---|---|---|---|
| `error` | `fixture:high` | `src/fixture,file.js:1` | fixture finding | https://example.invalid/rules/fixture-high |
| `error` | `fixture:high` | `src/fixture,file.js:2` | fixture finding | https://example.invalid/rules/fixture-high |
| `error` | `fixture:high` | `src/fixture,file.js:3` | fixture finding | https://example.invalid/rules/fixture-high |
| `error` | `fixture:high` | `src/fixture,file.js:4` | fixture finding | https://example.invalid/rules/fixture-high |
| `error` | `fixture:high` | `src/fixture,file.js:5` | fixture finding | https://example.invalid/rules/fixture-high |
| `error` | `fixture:high` | `src/fixture,file.js:6` | fixture finding | https://example.invalid/rules/fixture-high |
| `error` | `fixture:high` | `src/fixture,file.js:7` | fixture finding | https://example.invalid/rules/fixture-high |
| `error` | `fixture:high` | `src/fixture,file.js:8` | fixture finding | https://example.invalid/rules/fixture-high |
| `error` | `fixture:high` | `src/fixture,file.js:9` | fixture finding | https://example.invalid/rules/fixture-high |
| `error` | `fixture:high` | `src/fixture,file.js:10` | fixture finding | https://example.invalid/rules/fixture-high |
| `error` | `fixture:high` | `src/fixture,file.js:11` | fixture finding | https://example.invalid/rules/fixture-high |
| `error` | `fixture:high` | `src/fixture,file.js:12` | fixture finding | https://example.invalid/rules/fixture-high |
| `error` | `fixture:high` | `src/fixture,file.js:13` | fixture finding | https://example.invalid/rules/fixture-high |
| `error` | `fixture:high` | `src/fixture,file.js:14` | fixture finding | https://example.invalid/rules/fixture-high |
| `error` | `fixture:high` | `src/fixture,file.js:15` | fixture finding | https://example.invalid/rules/fixture-high |
| `error` | `fixture:high` | `src/fixture,file.js:16` | fixture finding | https://example.invalid/rules/fixture-high |
| `error` | `fixture:high` | `src/fixture,file.js:17` | fixture finding | https://example.invalid/rules/fixture-high |
| `error` | `fixture:high` | `src/fixture,file.js:18` | fixture finding | https://example.invalid/rules/fixture-high |
| `error` | `fixture:high` | `src/fixture,file.js:19` | fixture finding | https://example.invalid/rules/fixture-high |
| `error` | `fixture:high` | `src/fixture,file.js:20` | fixture finding | https://example.invalid/rules/fixture-high |

Showing 20 of 25 findings; download `fixture-sarif` for the complete result.

## How to remediate

Replace the unsafe fixture behavior with the documented safe pattern.
