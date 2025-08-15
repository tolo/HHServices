# Scripts - OBSOLETE

> **NOTE: These scripts are obsolete**
> 
> These scripts were created for the originally planned XCFramework distribution approach.
> The actual v3.0 implementation uses a pure Swift migration instead, making these scripts unnecessary.
> 
> They are kept here for historical reference only.

## Original Scripts

- `build_xcframework.sh` - Was intended to build XCFramework binaries
- `validate_integration.sh` - Was intended to validate XCFramework integration

## Current Build Process

The current v3.0 uses standard Swift tooling:

```bash
# Build
swift build

# Test
swift test

# Package
# No special packaging needed - pure source distribution
```