# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.


## IMPORTANT INSTRUCTIONS ⚠️
- **NEVER** say things like "you're absolutely right". Instead, **be critical and sceptical** if I say something that you disagree with. Let's discuss it first. We're trying to reduce sycophancy here.
- **CRITICAL: NEVER CREATE MASSIVE, OVER-ENGINEERED IMPLEMENTATIONS** - Always start minimal and only add complexity when explicitly requested (i.e. use a KISS, YAGNI and DRY approach).
- Store any temporary files in the `@ai_docs/temp/` directory (if not otherwise specified), **never** in the root directory.
- **WHEN MODIFYING EXISTING CODE**, aim for minimal changes with surgical precision, made methodically step by step, rather than large-scale, broad sweeping changes.
- **When researching** never include an older year in web searches, i.e. prefer search patterns like "XcodeProj swift example usage" over "XcodeProj swift example usage 2024".
- **USE CURRENT DATE AND TIME** - Use `date` command for getting current date/time or timestamps information, when comparing file dates, doing research, checking log entries and in many other cases where current date/time is needed.


## Overview

HHServices is an Objective-C framework for DNS-SD (Bonjour) service discovery over various network interfaces including Bluetooth P2P. It provides a low-level alternative to NSNetService for iOS applications requiring P2P Bluetooth connectivity, which NSNetService no longer supports as of iOS 11.

## Architecture

### Core Components

**Service Discovery Classes:**
- `HHService`: Represents a discovered service and handles resolution of host names and addresses (IPv4/IPv6)
- `HHServiceBrowser`: Discovers services of a specific type on the network
- `HHServicePublisher`: Publishes services for discovery by other devices
- `HHServiceDiscoveryOperation`: Base class for service discovery operations
- `HHAddressInfo`: Contains resolved address information including host name, port, and socket address

### Key Features
- ARC-enabled Objective-C codebase
- IPv4 and IPv6 support
- Bluetooth-only service discovery option (via kDNSServiceInterfaceIndexP2P)
- Interface-specific service discovery
- CocoaPods integration

### Service Type Format

When working with DNS-SD services, use the standard format: `_servicename._tcp.` or `_servicename._udp.`
Example: `_myexampleservice._tcp.`

### Bluetooth P2P Considerations

For Bluetooth-only discovery (avoiding WiFi adhoc mode issues):
- Use `kDNSServiceInterfaceIndexP2P` interface index
- Call methods with `OverBluetoothOnly` suffix
- Or use `beginResolve:includeP2P:` with appropriate parameters

### Memory Management

All classes use ARC. When resolving services:
- Retain `HHService` instances during resolution (add to a collection)
- Set delegate to nil and call `endResolve` when done
- Handle the `moreComing` parameter appropriately in delegate callbacks


## Useful Tools and MCP Servers

### Xcode related commands
- **xcodebuild**: The command line tool for building Xcode projects and workspaces
- **xcrun**: A command line tool for running Xcode tools and utilities
- **simctl**: A command line tool for managing iOS simulators and running apps, taking screenshots, and capturing logs

### xcpretty
For formatting Xcode build output in a clear and readable way
```bash
# Example
xcodebuild -workspace PlayMyQueue.xcworkspace -scheme PlayMyQueue -sdk iphonesimulator -configuration Debug -destination 'generic/platform=iOS Simulator' build | xcpretty
```

### SwiftFormat (https://github.com/swiftlang/swift-format)
For formatting and linting Swift code according to a set of standard (and customizable) rules
```bash
# Example: Format all Swift files in the project
swift-format --in-place --recursive ./Pomaddoro/

# Example: Lint all Swift files in the project
swift-format lint --recursive ./Pomaddoro/
```

### Context7 (https://github.com/upstash/context7)
Context7 MCP pulls up-to-date, version-specific documentation and code examples straight from the source.

### Fetch (https://github.com/modelcontextprotocol/servers/tree/main/src/fetch)
A Model Context Protocol server that provides web content fetching capabilities

### XcodeBuildMCP (https://github.com/mxcl/swift-sh)
A Model Context Protocol server that provides Xcode build and log capture capabilities

### swift-sh (https://github.com/mxcl/swift-sh)
For writing Swift scripts

### XcodeProj CLI tool (https://github.com/tolo/xcodeproj-cli)
A powerful command-line utility for programmatically manipulating Xcode project files (.xcodeproj)

### gitingest (https://gitingest.com/llms.txt)
For turning any Git repository into a prompt-ready text digest

Example use: 
```bash
gitingest https://github.com/octocat/Hello-World -o test_output.txt
```


## Critical Development Guidelines and Standards

### Core Development Philosophy
- **Keep It Simple**: All design and implementations should be as simple as possible, but no simpler. Always prefer efficient and straightforward solutions over complex, over-engineered ones whenever possible. Simple solutions are easier to understand, maintain, and debug.
- **Avoid Overengineering**: Focus on simplicity and working solutions, not theoretical flexibility. Implement features only when they are needed, not when you anticipate they might be useful in the future (YAGNI).
- **Dependency Inversion**: High-level modules should not depend on low-level modules. Both should depend on abstractions. This principle enables flexibility and testability.
- **Separation of Concerns**: Each module or component should have a single responsibility. This makes the codebase easier to understand and maintain.
- **Avoid Premature Optimization**: Focus on writing clear and maintainable code first. Optimize only when performance issues are identified through profiling or established facts / best practices.
- **DRY (Don't Repeat Yourself)**: Avoid code duplication by abstracting common functionality into reusable components or services. This reduces maintenance overhead and improves code clarity. But only do this when it makes sense, and doesn't conflict with the *Avoid Overengineering* principle.

### Architectural Considerations
- Avoid major architectural changes to working features unless explicitly instructed
- When implementing features, always check existing patterns first

#### Use CUPID for Architectural Decision-Making
CUPID properties (https://cupid.dev/) focus on creating architectures that are "joyful" to work with. CUPID emphasizes properties rather than rigid rules for architectural design.

- **C - Composable Architecture**: Design system components that harmonize cohesively with minimal dependencies / coupling and clear interfaces / API contracts, framework-agnostic design where possible.
- **U - Unix Philosophy for Systems**: Apply the Unix philosophy to system boundaries and service design, meaning each service/component does one thing well (single responsibility), appropriate granularity, clear separation between different system concerns, well-defined system boundaries
- **P - Predictable System Behavior**: Ensure system behavior is consistent and unsurprising, with predictable performance characteristics, well-defined failure modes, clear data flow and state management, and observable and debuggable behavior.
- **I - Idiomatic Architecture**: Use architecture patterns that are familiar and reduce cognitive load for the development team, including industry-standard architectural patterns, consistent technology choices across the system, familiar deployment and operational patterns, team-appropriate technology selections, and convention-over-configuration approaches.
- **D - Domain-Aligned Architecture**: Ensure the architecture clearly expresses business concepts and aligns with domain boundaries, including domain-driven design principles, clear separation of business logic from infrastructure concerns, and alignment with business processes and terminology.

### Workflow Patterns
- Focus only on code relevant to the task
- Only make changes that are requested or well-understood
- Preferably create tests BEFORE implementation (TDD)
- Break complex tasks into smaller, testable units
- Validate understanding before implementation
- Always use up-to-date documentation to ensure use of correct APIs
  - Use the `Context7` MCP for looking up API documentation
- Update README.md when important/major new features are added, dependencies change, or setup steps are modified.

### Visual UI Feature Requirements
- **CRITICAL**: UI features require visual validation - code implementation alone is insufficient
- For responsive UI, multi-device UI, or visual design changes, **ALWAYS** include:
  - Screenshot capture across target devices and orientations
  - Visual quality assessment and documentation
  - Touch target verification through visual inspection
  - Theme/design authenticity confirmation across screen sizes
- **Use the visual-design-reviewer agent** for systematic validation against baseline references
- Consider creating feature requests for visual validation (see @ai_docs/features/visual-validation-responsive-ui.md as example)
- **Remember**: Users experience UI visually, not architecturally

### Coding Guidelines
- Log significant operations and errors
- Use descriptive variable names
- Use the simplest solution that meets the requirements
- Avoid code duplication - check for existing similar functionality first
- Never overwrite .env files without explicit confirmation
- Make absolutely sure implementations are based on the latest versions of frameworks/libraries
- Write thorough tests for all major functionality

### Documentation Guidelines
- Never document code that is self-explanatory
- Never write full API-level documentation for application code
- For complex or non-obvious code, add concise comments explaining the purpose and logic (but only when needed)

### **COMMON PITFALLS TO AVOID**
- **NEVER** create duplicate files with version numbers or suffixes (e.g., file_v2.xyz, file_new.xyz) when refactoring or improving code
- **NEVER** modify core frameworks without explicit instruction
- **NEVER** add dependencies without checking existing alternatives
- **NEVER** create a new branch unless explicitly instructed to do so
- **ABSOLUTELY FORBIDDEN: NEVER USE `git rebase --skip` EVER** (can cause data loss and repository corruption, ask the user for help if you encounter rebase conflicts)

**Mandatory Reality Check:**
Before implementing ANY feature, ask:
1. **What is the core user need?** (e.g., "validate UI looks right")
2. **What's the minimal solution?** (e.g., "screenshot comparison")
3. **Am I adding enterprise features to a simple app?** (if yes, STOP)


## Development Commands

### Building the Framework
```bash
# Build the main framework using Xcode
xcodebuild -project HHServices.xcodeproj -scheme HHServices build

# Build for specific configuration
xcodebuild -project HHServices.xcodeproj -scheme HHServices -configuration Release build
```

### Sample Applications
```bash
# Build and run BrowserSample (service discovery)
cd samples/BrowserSample
pod install
xcodebuild -workspace BrowserSample.xcworkspace -scheme BrowserSample build

# Build and run PublisherSample (service publishing)  
cd samples/PublisherSample
pod install
xcodebuild -workspace PublisherSample.xcworkspace -scheme PublisherSample build
```

### CocoaPods Integration
```bash
# Validate podspec
pod spec lint HHServices.podspec

# Install dependencies for samples
cd samples/BrowserSample && pod install
cd samples/PublisherSample && pod install
```
