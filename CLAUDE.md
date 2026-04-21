# Claude Code Instructions

## Commits

- Do NOT add "Co-Authored-By" lines to commit messages.
- Commit after completing each task (each user change request, or each step in a plan) unless instructed otherwise.
- Also commit **before** a risky or large refactor as a checkpoint.
- **Hold off** when:
  - Multiple small changes form one logical unit (e.g. move + rename + update tests).
  - The code is in a broken intermediate state.
  - The next change is trivially related to the current one.

## Testing

- Always run tests before considering a task complete.
- If implementation code was changed or added, add or update tests for that code.

## Platform Portability

Public Forge APIs must never contain platform-dependent code. This ensures portability across platforms.

- Never gate public APIs inside `canImport` statements.
- When building a Leaf, Proxy, or Container view, use `canImport` **only** inside `makeRenderer` to select the correct platform renderer (`[Component]UIKitRenderer` or `[Component]AppKitRenderer`).

## Swift File Ordering

Each file must keep the main struct/type it represents at the top. If the filename is `Graphic.swift`, the first struct is `Graphic`. This does not apply to general library files that contain many types of equal importance.

After the core struct, place its dependencies in **breadth-first** order:
1. All types the main struct directly depends on
2. Then all types those depend on (in order)
3. And so on recursively
