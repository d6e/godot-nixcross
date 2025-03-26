{ crossenv }:

let
  godot_version = "4.2.1";
  godot_src = crossenv.nixpkgs.fetchFromGitHub {
    owner = "godotengine";
    repo = "godot";
    rev = "${godot_version}-stable";
    sha256 = "sha256-YwGWFVv8ZIGBF7qMfzXqD9tVKx4xWX6P0QcdNuKW6KM="; # Replace with actual hash
  };

  python3 = crossenv.nixpkgs.python3;
  scons = crossenv.nixpkgs.scons;

in crossenv.make_derivation rec {
  name = "godot-${godot_version}-${crossenv.host}";
  
  src = godot_src;
  
  # Native build dependencies
  native_inputs = [ 
    python3
    scons
  ];

  # Build configuration varies by target platform
  platform = if crossenv.os == "macos" then "macos"
    else if crossenv.os == "linux" then "linuxbsd"
    else if crossenv.os == "windows" then "windows"
    else throw "Unsupported OS for Godot: ${crossenv.os}";

  target = if crossenv.os == "windows" then "template_release"
    else "release";

  bits = if crossenv.arch == "i686" then "32"
    else "64";

  # Additional platform-specific configuration
  use_mingw = crossenv.os == "windows";

  arch = if crossenv.arch == "aarch64" then "arm64"
    else if crossenv.arch == "x86_64" then "x86_64"
    else if crossenv.arch == "i686" then "x86_32"
    else throw "Unsupported architecture for Godot: ${crossenv.arch}";

  # Use a placeholder builder - in a real project, this would actually build Godot
  builder = crossenv.nixpkgs.writeScript "build-godot.sh" ''
    #!/bin/sh
    source $setup

    echo "Building Godot ${godot_version} for ${platform} (${arch})..."
    # In a real build, we would run something like:
    # scons platform=${platform} target=${target} bits=${bits} arch=${arch} ...
    
    # For now, just create a directory structure with a placeholder executable
    mkdir -p $out/bin
    echo "#!/bin/sh\necho \"This is a placeholder for Godot ${godot_version} for ${platform} (${arch})\"" > $out/bin/godot
    chmod +x $out/bin/godot
  '';
}
