{
  description = "Cross-compile Godot using nixcrpkgs";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nixcrpkgs = {
      url = "github:d6e/nixcrpkgs";
    };
  };

  outputs = { self, nixpkgs, nixcrpkgs }: 
  let
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};
    
    # For macOS cross-compilation, provide the macOS SDK
    macos_sdk_path = ./MacOSX15.2.sdk.tar.xz;
    
    # Create the nixcrpkgs environment
    cr = nixcrpkgs.lib.nixcrpkgs { 
      nixpkgs = pkgs;
      macos_sdk = macos_sdk_path; 
    };
    
    # Build function for Godot
    build-godot = crossenv: import ./godot { inherit crossenv; };
  in {
    packages.${system} = {
      # Structure as godot.<os>.<arch>
      godot = {
        windows = {
          x86_64 = build-godot cr.crossenvs.x86_64-w64-mingw32;
          x86_32 = build-godot cr.crossenvs.i686-w64-mingw32;
          arm64 = build-godot cr.crossenvs.aarch64-w64-mingw32;
        };
        linux = {
          x86_64 = build-godot cr.crossenvs.x86_64-linux-musl;
          x86_32 = build-godot cr.crossenvs.i686-linux-musl;
          arm64 = build-godot cr.crossenvs.aarch64-linux-musl;
          arm32 = build-godot cr.crossenvs.arm-linux-musleabihf;
        };
        macos = {
          x86_64 = build-godot cr.crossenvs.x86_64-macos;
          aarch64 = build-godot cr.crossenvs.aarch64-macos;
          # Create a virtual target for universal macOS binaries
          universal = 
            let 
              # Use aarch64 as base crossenv but override arch
              crossenv = cr.crossenvs.aarch64-macos // { arch = "universal"; };
            in
              build-godot crossenv;
        };
        # Add Web platform support
        web = {
          wasm32 = build-godot cr.crossenvs.wasm32-emscripten;
        };
        # Note: We're excluding Android and iOS here as they require more complex setup
      };
      
      # Set a default package (Linux x86_64)
      default = self.packages.${system}.godot.linux.x86_64;
      
      # Also create an all-platforms package that depends on all builds
      all = pkgs.symlinkJoin {
        name = "godot-all";
        paths = with self.packages.${system}.godot; [
          # Windows
          windows.x86_64
          windows.x86_32
          windows.arm64
          # Linux
          linux.x86_64
          linux.x86_32
          linux.arm64
          linux.arm32
          # macOS
          macos.x86_64
          macos.aarch64
          macos.universal
          # Web
          web.wasm32
        ];
      };
    };
  };
}