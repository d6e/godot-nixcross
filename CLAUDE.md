# Godot NixCross Development Guidelines

## Build Commands
- `nix build` - Build for all platforms (default target: Linux x86_64)
- `nix build .#godot.all` - Build all supported platforms and architectures
- `nix build .#godot.windows.x86_64` - Build Windows x86_64
- `nix build .#godot.windows.x86_32` - Build Windows x86_32 
- `nix build .#godot.windows.arm64` - Build Windows ARM64
- `nix build .#godot.linux.x86_64` - Build Linux x86_64
- `nix build .#godot.linux.x86_32` - Build Linux x86_32
- `nix build .#godot.linux.arm64` - Build Linux ARM64
- `nix build .#godot.linux.arm32` - Build Linux ARM32
- `nix build .#godot.macos.x86_64` - Build macOS x86_64
- `nix build .#godot.macos.aarch64` - Build macOS ARM64
- `nix build .#godot.macos.universal` - Build Universal macOS (combined x86_64 + ARM64)
- `nix build .#godot.web.wasm32` - Build Web/WebAssembly

## Prerequisites
- Nix package manager installed
- For macOS builds: macOS SDK (see instructions in README.md)
  - On a macOS machine, install Xcode
  - Run the SDK packaging script from nixcrpkgs: `./nixcrpkgs/macos/gen_sdk_package.sh`
  - Copy the resulting SDK file (e.g., `MacOSX15.2.sdk.tar.xz`) to the root of this repository

## Code Style Guidelines
- Follow Nix flake conventions for Nix files
- Use 2-space indentation in Nix files
- Keep functions pure and minimize side effects
- Document package attributes clearly
- Follow Godot's SCons build conventions when modifying build scripts
- Prefer descriptive variable names over abbreviations
- Use camelCase for variables in Nix expressions
- Maintain cross-platform compatibility
- Follow the nixcrpkgs framework conventions
- Use structured pathing: godot.<os>.<arch> for packages

## Project Structure
- `flake.nix` - Main build configuration
- `godot/` - Godot build definitions
- `build-containers/` - Reference Dockerfiles for official Godot builds
- `godot-build-scripts/` - Reference build scripts for in-container Godot builds

## Supported Platforms and Architectures
This project supports cross-compilation for:

- Windows:
  * x86_64 (64-bit)
  * x86_32 (32-bit)
  * arm64 (ARM64/AArch64)
- Linux:
  * x86_64 (64-bit)
  * x86_32 (32-bit)
  * arm64 (ARM64/AArch64)
  * arm32 (ARM32/ARMv7)
- macOS:
  * x86_64 (Intel)
  * aarch64 (Apple Silicon)
  * universal (Combined Intel + Apple Silicon)
- Web:
  * wasm32 (WebAssembly)

Note: Android and iOS support is currently not implemented due to their more complex build requirements.

## Toolchain Versions (Reference)
Based on Godot's official build containers:
- Linux: GCC 13.2.0 built against glibc 2.28, binutils 2.40
- Windows:
  * x86_64/x86_32: MinGW 12.0.0, GCC 14.2.1, binutils 2.42
  * arm64: llvm-mingw 20241203, LLVM 19.1.5
- macOS: Xcode 16.2 with Apple Clang (LLVM 17.0.6), MacOSX SDK 15.2
- Web: Emscripten 3.1.64

## Version Configuration
- Edit the `godot/default.nix` file to change the Godot version being built
- Current version: 4.4-stable

## Working with SHA256 Hashes
When updating to a new Godot version, you'll need to update the SHA256 hash in `godot/default.nix`. The easiest way to do this:

1. Set the sha256 to a placeholder: `sha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";`
2. Run a build: `nix build .#godot.linux.x86_64`
3. Nix will fail and provide the correct hash
4. Update the file with the correct hash and rebuild