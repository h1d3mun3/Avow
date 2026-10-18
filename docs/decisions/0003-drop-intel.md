# 3. Apple silicon only

- Status: Accepted
- Date: 2026-10-18

## Context

Avow targets macOS 26, which still runs on some Intel Macs, so the default
build settings produced a universal binary (arm64 + x86_64). The x86_64 slice
roughly doubles the size of the executable and the distributed DMG.

## Decision

1. `ARCHS = arm64` for the project, in both Debug and Release.
2. The README lists Apple silicon as a requirement and states that Intel Macs
   are not supported.

## Consequences

- The app and DMG get smaller. The motivation is size alone, not testing cost
  or an API that Intel lacks.
- Avow no longer launches on Intel Macs. Existing universal releases
  (up to 1.1.1) keep working there but receive no updates.
- macOS 27 and later run on Apple silicon only, so this matches where the
  platform is going.
