# Repository Guidelines

## Project Structure & Module Organization
`Layout/` contains the iOS app target. App-wide composition lives in `Layout/App/`, feature slices live under `Layout/Features/<Feature>/`, shared models are in `Layout/Models/`, and images/colors are in `Layout/Assets.xcassets/`. App tests live in `LayoutTests/`.

This repo also includes two local Swift packages: `StateKit/` for reducer/store primitives and macros, and `LocalDI/` for dependency injection helpers. Each package follows the standard SwiftPM layout with sources in `Sources/` and tests in `Tests/`.

## Build, Test, and Development Commands
Use the repo root for all commands.

- `open Layout.xcodeproj` opens the app project in Xcode.
- `xcodebuild -project Layout.xcodeproj -scheme Layout -destination 'platform=iOS Simulator,name=iPhone 16' build` builds the app target.
- `xcodebuild -project Layout.xcodeproj -scheme Layout -destination 'platform=iOS Simulator,name=iPhone 16' test` runs `LayoutTests`.
- `swift test --package-path StateKit` runs the `StateKit` package tests.
- `swift test --package-path LocalDI` runs the `LocalDI` package tests.

## Coding Style & Naming Conventions
Follow the existing Swift style: 4-space indentation, one top-level type per concern, and small files grouped by feature. Use `UpperCamelCase` for types and `lowerCamelCase` for properties, functions, and enum cases.

Match the existing architecture vocabulary:

- feature state types end in `State`
- feature actions end in `Action`
- reducers use names like `homeReducer`
- UI files are typically `<Feature>View.swift` and domain files are `<Feature>Domain.swift`

No formatter or linter config is checked in, so keep changes consistent with surrounding code.

## Testing Guidelines
The app target and `LocalDI` use the Swift `Testing` framework with `@Test` and `#expect`. `StateKit` currently uses `XCTest`. Add tests next to the module you change, and name them after the behavior under test, for example `saveCreatesDirectoryAndWritesText`.

Cover reducer routing, dependency overrides, and user-visible feature behavior when touching those areas.

## Commit & Pull Request Guidelines
Recent commits use short, imperative subjects such as `Add browse feature and reorganize domains` and `Refactor app structure and feature state`. Follow that pattern: one line, present tense, focused on the main change.

Pull requests should include a concise summary, affected modules (`Layout`, `StateKit`, `LocalDI`), test evidence, and screenshots for SwiftUI changes when the UI is affected.
