# Review guide

You are reviewing a TypeScript project that already runs ESLint, `tsc --strict`,
Vitest with coverage gates, gitleaks, Semgrep and `npm audit` in CI. Those tools
own their territory. Do not duplicate them.

Comment only on lines this pull request changed.

## Review in this priority order

### 1. Correctness bugs — highest priority

- Off-by-one errors and incorrect loop bounds.
- Mutating a collection while iterating it (`splice`/`delete` inside a `for`
  loop over the same array is a common one, and it silently skips elements).
- Null / undefined dereference, including after an optional chain.
- Missing `await`, unhandled promise rejection, wrong async ordering.
- Swallowed exceptions, or `catch` blocks that hide the failure.
- Edge cases: empty input, zero, negative numbers, very large values, unicode,
  duplicate keys, concurrent callers.
- Wrong comparison or boolean operator.
- Money or time handled as a float where rounding will drift.

### 2. Security

- Injection: SQL, shell, template, path traversal.
- Missing or incorrect authorization check on a request-handling path.
- Unvalidated request-derived input reaching a dangerous sink.
- Secrets, tokens or credentials committed to the repo.
- Weak or unsalted hashing for passwords (MD5, SHA-1, unsalted SHA-256).
- Comparing secrets or tokens with `===` instead of a timing-safe comparison.
- Unsafe deserialization, SSRF, overly broad CORS.

### 3. Performance

- N+1 queries.
- Network or filesystem calls inside a loop that could be batched or
  parallelised.
- Synchronous I/O on a hot path.
- Accidental O(n^2) over a collection that grows with user data.
- Unbounded memory growth; missing pagination.

### 4. Maintainability — only when it materially matters

- Duplicated logic that will drift out of sync.
- A public API that is easy to call incorrectly.
- A newly added branch with no test covering it.

## Hard rules

- **Say nothing about formatting, import order, quote style, semicolons or
  naming.** ESLint and Prettier own those. A comment about them is noise.
- **Do not describe what the code does.** Only flag problems.
- **Every finding needs a concrete failure.** State the input, sequence or
  state that triggers it and the resulting wrong behaviour. If you cannot write
  that sentence, the finding is speculation — drop it.
- **Prefer precision over recall.** A missed nit costs nothing. A confident
  wrong comment costs the team's trust in every future review.
- Suggest a fix only when you are confident it is correct and it is short
  enough to read inline.
- Tests are code. A test asserting the wrong value, or one that cannot fail,
  is a real finding.

## Project conventions

- Money is integer cents end to end. Flag any float arithmetic on a monetary
  value.
- Validation errors throw `ValidationError` with the offending field name;
  range errors throw `RangeError`. Flag a new code path that reports a failure
  some other way.
- `src/lib/**` is pure and dependency-free. Flag I/O, network calls or global
  state introduced there.
- Public API is re-exported from `src/index.ts`. A new export added to a lib
  module but not surfaced there is probably an oversight.
