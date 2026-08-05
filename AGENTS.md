# Agent Instructions

These instructions guide AI agents working in UUSwiftCore.

UU libraries provide thin, opinionated layers over native platform APIs. Their purpose is to improve consistency, safety, readability, and cross-project reuse, not to replace or hide the underlying platform.

Every abstraction must justify its existence. Before introducing a new type, protocol, wrapper, helper, or extension, ask whether it meaningfully improves correctness, readability, reusability, validation, testability, or project consistency.

If it merely renames a native API or adds indirection without reusable value, use the native API directly.

## When in Doubt

Choose:

- Native APIs
- Smaller code
- Simpler designs
- Explicit behavior
- Focused tests

Avoid:

- Clever abstractions
- Framework-style architecture
- Generic helpers with unclear ownership
- Wrapping APIs just to rename them
- Broad rewrites unrelated to the task

## Mission

UU libraries should feel like natural extensions of the platform, not replacements for it.

UU code should optimize for:

1. Correctness
2. Native platform behavior
3. Readability
4. Simplicity
5. Reusability
6. Testability
7. Performance when justified

UU libraries are not intended to:

- Replace native SDKs
- Hide platform concepts
- Wrap every platform API
- Become dependency injection frameworks
- Introduce large framework-style architectures
- Make simple platform behavior look proprietary

## Decision Priorities

Use this order when making implementation decisions.

1. Correctness: the implementation must be correct, predictable, and safe. Do not trade correctness for cleverness, concision, or abstraction.
2. Native APIs: prefer Apple-provided APIs and Swift language features before creating UU-specific abstractions. Use the native API directly unless a UU abstraction adds meaningful reusable behavior.
3. Readability: prefer obvious code over compact or clever code. A future maintainer should be able to understand the implementation without tracing unnecessary abstraction layers.
4. Simplicity: choose the smallest design that solves the problem well. Avoid broad rewrites, generalized frameworks, or speculative extensibility.
5. Reusability: reusable code is valuable when it captures real repeated behavior, shared policy, validation, or testability. Do not create reusable abstractions for one-off behavior.
6. Performance: optimize performance when there is a demonstrated need or clear risk. Do not make code harder to understand for theoretical performance gains.

## Rules

These rules are intended to be applied directly by coding agents.

### MUST

- MUST prefer native Apple APIs before introducing UU abstractions.
- MUST follow existing project structure, naming, style, and test organization.
- MUST keep changes focused on the requested behavior.
- MUST write readable, maintainable code.
- MUST add focused tests for new behavior and regression risks.
- MUST surface useful error information.
- MUST document public APIs when the purpose, behavior, errors, or concurrency expectations are not obvious.

### MUST NOT

- MUST NOT introduce large third-party dependencies without documented need and maintainer approval.
- MUST NOT create wrappers that merely rename native APIs.
- MUST NOT hide standard platform concepts without meaningful reusable value.
- MUST NOT perform broad rewrites unless explicitly requested.
- MUST NOT silently ignore failures.
- MUST NOT add framework-style architecture for small problems.
- MUST NOT add speculative abstractions for hypothetical future use.

### SHOULD

- SHOULD use explicit APIs that are difficult to misuse.
- SHOULD favor focused types with single responsibilities.
- SHOULD test observable behavior rather than implementation details.
- SHOULD preserve native developer expectations.
- SHOULD prefer deterministic tests without timing assumptions.

### MAY

- MAY introduce UU wrappers when they provide shared policy, validation, reusable behavior, testability, or project consistency.
- MAY add convenience helpers when they significantly reduce duplicated code and remain easy to understand.
- MAY use third-party dependencies only when they provide significant value that native APIs do not provide.

## API Design

Public APIs should be small, predictable, discoverable, easy to compose, and difficult to misuse.

Prefer explicit behavior over hidden magic.

Before creating a new type, protocol, wrapper, helper, or extension, answer these questions:

1. Does a native API already solve this clearly?
2. Does the abstraction add reusable project behavior?
3. Does it improve correctness or safety?
4. Does it improve validation or policy enforcement?
5. Does it improve testability?
6. Does it make the calling code easier to read without hiding important platform concepts?

If the answer is no, do not create the abstraction.

Create a UU wrapper when it provides one or more of:

- Shared project policy
- Validation
- Reusable behavior
- Improved testability
- Cross-project consistency
- Safer or more ergonomic APIs

Do not create wrappers whose only purpose is:

- Renaming native APIs
- Hiding native concepts
- Making code look more uniform without adding behavior
- Speculative future extensibility
- Avoiding direct use of well-understood platform APIs

Names should be clear, direct, and consistent with existing UU conventions.

Respect Apple terminology when wrapping or extending Apple APIs.

A developer familiar with Foundation should be able to predict what the UU API does.

## Swift Guidance

Prefer Swift language features and Apple frameworks before introducing custom infrastructure.

Use these first when appropriate:

- Foundation
- Codable
- Swift Concurrency
- Task
- MainActor
- actors
- Sendable
- CryptoKit
- Security
- XCTest
- OSLog when appropriate

Avoid large third-party frameworks for problems already handled well by Apple APIs.

Do not introduce third party dependencies unless there is a documented need and maintainer approval.

Prefer async/await and structured concurrency.

Avoid custom concurrency wrappers that merely rename Task, actors, MainActor, continuations, or other native primitives.

When exposing async APIs, make cancellation, threading, and actor isolation clear when relevant.

Prefer typed errors when they help callers respond correctly.

Expose enough error context to debug failures.

Do not swallow errors silently.

Avoid generic Error values when a more meaningful error type is practical.

Extensions should add focused, reusable behavior.

Avoid dumping unrelated helpers into large catch-all extensions.

Do not add extensions that duplicate obvious standard library behavior.

## Testing Guidance

Tests should document public API expectations and protect against regressions.

Prefer tests that verify observable behavior.

Avoid tests that depend on private implementation details unless there is no practical alternative.

A good test should remain valid after internal refactoring.

Add focused tests for:

- New public behavior
- Edge cases
- Error handling
- Regression risks
- Boundary conditions
- Concurrency behavior when relevant

Tests should be deterministic.

Avoid arbitrary sleeps, timing assumptions, external network calls, and order dependencies.

If timing is required, isolate it behind controllable test seams.

Prefer real implementations when they are simple, fast, and deterministic.

Use mocks, fakes, or stubs when they make tests clearer or isolate external systems.

Avoid excessive mocking that makes tests harder to understand than the production code.

Use XCTest conventions already present in the project.

Follow existing naming, organization, and assertion style.

## Patterns

### Native First

Good:

```swift
let data = try JSONEncoder().encode(value)
```

Bad:

```swift
let data = try UUJSONEncoder().encode(value)
```

unless `UUJSONEncoder` adds shared policy, configuration, validation, or testability beyond simple renaming.

### Thin Policy Wrapper

Good:

```swift
struct UURetryPolicy {
    let maxAttempts: Int
    let delay: Duration
}
```

This captures reusable project policy without hiding native APIs.

### Native Type Plus Focused Helper

Good:

```swift
extension URLRequest {
    mutating func setBearerToken(_ token: String) {
        setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }
}
```

This adds focused reusable behavior while preserving the native type.

### Decision Tree

Need a new abstraction?

1. Does Foundation or Swift already solve it?
   - Yes: use the native API.
   - No: continue.
2. Does the abstraction add reusable policy, validation, safety, or testability?
   - Yes: consider a UU abstraction.
   - No: do not create it.
3. Will the API remain obvious to a Swift developer?
   - Yes: proceed carefully.
   - No: simplify.

## Anti-Patterns

Avoid these patterns unless explicitly requested and justified.

### Wrapper-Only Renaming

Bad:

```swift
final class UUURLSession {
    private let session: URLSession
}
```

Do not wrap URLSession merely to rename it.

A wrapper is acceptable only if it adds meaningful reusable behavior such as retry policy, request signing, validation, logging policy, or test seams.

### Generic Utility Dumps

Bad:

```swift
enum UUUtils {
    static func doThing() {}
    static func parseDate() {}
    static func makeRequest() {}
}
```

Avoid catch-all utility containers.

Prefer focused types or extensions organized around a clear concept.

### Framework Architecture for Small Problems

Do not introduce coordinators, service registries, dependency containers, middleware stacks, or plugin systems for simple behavior.

Start small.

### Hidden Magic

Avoid APIs that perform surprising behavior implicitly.

Callers should be able to predict important effects such as network calls, disk writes, keychain access, thread hops, and retries.

### Broad Rewrite During Focused Task

Do not rewrite unrelated code while implementing a small requested change.

Leave surrounding code better only when the improvement is directly related to the task.
