# Templates - OBSOLETE

> **NOTE: These templates are obsolete**
> 
> These templates were created for the originally planned XCFramework distribution approach.
> The actual v3.0 implementation uses a pure Swift migration instead, making these templates outdated.
> 
> They are kept here for historical reference only.

## Original Templates

- `Package_v3.swift` - Was intended for XCFramework binary target configuration
- `Podspec_v3.podspec` - Was intended for XCFramework CocoaPods distribution

## Current Configuration

The actual v3.0 configuration files are in the repository root:

- `/Package.swift` - Standard Swift package with source targets
- `/HHServices.podspec` - Standard CocoaPods spec with source files

Both use pure Swift source distribution, not binary frameworks.