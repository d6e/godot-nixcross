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
      # Cross-compile Godot for different platforms
      godot-win64 = build-godot cr.crossenvs.x86_64-w64-mingw32;
      godot-linux64 = build-godot cr.crossenvs.x86_64-linux-musl;
      godot-macos = build-godot cr.crossenvs.x86_64-macos;
      godot-macos-arm = build-godot cr.crossenvs.aarch64-macos;
      
      # Set a default package (Linux x86_64)
      default = self.packages.${system}.godot-linux64;
    };
  };
}
