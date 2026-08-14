# Codex Rules

These rules apply to all future Codex work in this repository.

## Scope discipline

Never implement major functionality that was not requested by the current task.

## Small iterations

Prefer small, reviewable changes. Keep each task focused on one coherent outcome.

## No premature architecture

Do not create complicated frameworks for hypothetical future requirements. Let architecture grow from observed needs.

## Godot conventions

- Use Godot 4.x best practices.
- Use typed GDScript where sensible.
- Use semantic Input Map actions instead of hardcoded gameplay keys.
- Prefer composition over deep inheritance trees.

## Separation

Keep gameplay logic reasonably separate from visuals, audio, and UI. A prototype may stay simple, but it should not create unnecessary coupling.

## Assets

- Use primitives and placeholders during prototype development.
- Do not download random third-party assets.
- Do not include copyrighted game assets.

## Dependencies

Do not introduce third-party plugins unless they are specifically approved.

## Testing

After implementation:

- run available tests;
- validate scenes;
- check parser errors;
- report anything that cannot be tested.

## Completion response

Every Codex task must finish with:

### Summary

What was implemented.

### Files changed

A list of changed files.

### Testing

Tests or validations performed.

### Known limitations

Anything intentionally incomplete.

### Recommended next task

One logical next step only.

