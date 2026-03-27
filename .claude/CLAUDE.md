# Papion — Claude Workstyle

## How we work together

1. **Discuss first** — Before implementing anything, discuss the approach with Claude. Share ideas, raise concerns, explore trade-offs.

2. **Update the ADR** — Any architectural decision must be reflected in `docs/adr.md` before implementation begins. If a discussion leads to a new decision or changes an existing one, update the ADR first.

3. **Write the README first** — Before writing any code, write the README for the component. Define the interface and behavior from the user's perspective (README Driven Development).

4. **Write tests first** — Write failing tests based on what the README describes before implementing (TDD: Red → Green → Refactor). If a test reveals a problem with the README or ADR, go back to the relevant step.

5. **Implement** — Write the minimal code to make tests pass, then refactor.

## Key references

- Architecture decisions: `docs/adr.md`
