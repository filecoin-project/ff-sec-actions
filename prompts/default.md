# Domain context: general

No specialized domain context applies to this repository. Review the change as
general-purpose software with emphasis on:

- Correctness: logic errors, off-by-one, wrong operator/condition, broken
  error propagation, concurrency races.
- Security: injection (SQL/command/path), unsafe deserialization, SSRF,
  authentication/authorization gaps, secrets in code or logs, unsafe temp
  files, dependency misuse.
- Availability: unbounded work on untrusted input, resource leaks, missing
  timeouts and retries on network calls.
- Maintainability defects with concrete consequences (dead error paths,
  contract-violating APIs), not style preferences.

Calibrate severity to realistic impact in a production service.
