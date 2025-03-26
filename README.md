# Godot NixCross

Cross-compile Godot using nixcrpkgs.

This project demonstrates how to build Godot for multiple platforms using the nixcrpkgs cross-compilation framework.

## Prerequisites

- Nix package manager
- For macOS builds: A macOS SDK (see instructions below)

## Getting Started

### Setting up the macOS SDK

To build for macOS, you need a macOS SDK:

1. On a macOS machine, install Xcode
2. Run the SDK packaging script from nixcrpkgs:
   ```
   ./nixcrpkgs/macos/gen_sdk_package.sh
   ```
3. Copy the resulting SDK file (e.g., `MacOSX15.2.sdk.tar.xz`) to the root of this repository

### Building

Build for all platforms:
```
nix build
```

Build for a specific platform:
```
nix build .#godot-win64
nix build .#godot-linux64  
nix build .#godot-macos
nix build .#godot-macos-arm
```

## Project Structure

- `flake.nix` - The main build configuration
- `godot/` - Build definitions for Godot

The project uses [d6e/nixcrpkgs](https://github.com/d6e/nixcrpkgs) for cross-compilation functionality.
