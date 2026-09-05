# Harbor Architecture

Harbor is organized as a small layered SwiftUI application. Dependencies point
inward: views render state, view models coordinate use cases, and core services
own networking, persistence, and domain rules.

## Source layout

- `App/` contains application entry points, navigation, adaptive layout, and theme.
- `Views/` contains SwiftUI screens and focused reusable components. Screens do
  not define API response models or long-lived stores.
- `ViewModels/` owns screen-specific asynchronous state and stale-request guards.
- `Core/API/` owns transport, endpoint construction, response validation, and
  service response DTOs.
- `Core/Engine/` owns stream ranking, subtitle discovery, and title parsing.
- `Core/Models/` owns protocol and domain values with no UI dependencies.
- `Core/Stores/` owns shared session state and cloud synchronization.
- `Core/Analytics/` is the only boundary allowed to talk to Firebase.
- `Core/Support/` contains small cross-domain utilities such as date formatting.

## State and concurrency rules

1. Shared stores and screen view models are `@MainActor` observable objects.
2. Published state is read-only outside its owner unless it is an intentional
   user-editable binding such as a search query or scope.
3. A request that can be superseded must compare a request ID before publishing
   its result. This prevents a slow response for an old region, key, or query
   from overwriting newer state.
4. Addon capability checks go through `AddonManifest.supports(...)`; feature
   code must not reimplement manifest type or ID-prefix filtering.
5. Stremio episode IDs are parsed through `EpisodeCoordinates`, dates through
   `HarborDate`, and stream-selection analytics through `StreamAnalytics`.

## Verification

The XcodeGen project includes unit tests, iPhone UI smoke tests, and an iPad
design smoke test. CI regenerates the project, runs all tests, archives the app,
and packages an unsigned IPA. Because Xcode is required, local Windows changes
should at minimum parse every Swift source and run `git diff --check` before CI.
