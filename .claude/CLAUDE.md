# Papion — Claude Workstyle

## How we work together

1. **Discuss first** — Before implementing anything, discuss the approach with Claude. Share ideas, raise concerns, explore trade-offs.

2. **Update the ADR** — Any architectural decision must be reflected in `docs/adr.md` before implementation begins. If a discussion leads to a new decision or changes an existing one, update the ADR first.

3. **Write the README first** — Before writing any code, write the README for the component. Define the interface and behavior from the user's perspective (README Driven Development).

4. **Write tests first** — Write failing tests based on what the README describes before implementing (TDD: Red → Green → Refactor). If a test reveals a problem with the README or ADR, go back to the relevant step.

5. **Implement** — Write the minimal code to make tests pass, then refactor.

## MoonBit code navigation

Use `moon ide` for symbol lookup — do not grep or read files blindly.

```sh
# Find definition of a symbol
moon ide goto-definition -tags 'pub fn' -query 'parse_action_yml'

# Find all usages
moon ide find-references -tags 'struct' -query 'ScanResult'

# Scope to a package
moon ide goto-definition -query '@maruloop/papion/parser parse_action_yml'
```

See `core/AGENTS.md` for full `moon ide` reference.

## MoonBit skills available

Three MoonBit skills are installed from `moonbitlang/skills`:

- **`/moonbit-agent-guide`** — Writing, refactoring, and testing MoonBit projects. Comprehensive language reference and toolchain guide.
- **`/moonbit-lang`** — MoonBit language reference and coding conventions.
- **`/moonbit-refactoring`** — Refactor MoonBit code to be idiomatic: shrink public APIs, convert functions to methods, use pattern matching, add loop invariants.

Invoke with `/moonbit-refactoring` etc. when doing refactoring or unfamiliar with a MoonBit pattern.

## Key references

- Architecture decisions: `docs/adr.md`
- MoonBit language guide: `core/AGENTS.md`
