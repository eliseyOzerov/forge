# Forge

A declarative UI framework with one vocabulary and many native backends.

Forge defines a single mental model for building UIs — View, Node, Renderer,
Builder, Model — and ships native implementations per platform. Each platform
uses its own language, its own layout engine, and its own rendering. The
shared asset is *knowledge*: the same component names, the same props, the
same state and invalidation semantics. Learn it once, apply it in Swift,
Kotlin, TypeScript, or Dart.

## Structure

```
forge/
  docs/                    Shared spec: vocabulary, semantics, taxonomy.
                           The contract every implementation must honor.
  apple/                   Swift (UIKit + AppKit)
    SwiftKit/              Library
    SwiftKitDemo/          Host app (pending)
  android/                 Kotlin + Compose (future)
  web/                     TypeScript + DOM (future)
```
