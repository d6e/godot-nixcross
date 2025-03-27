{ crossenv }:

let
  godot_version = "4.4";
  godot_src = crossenv.nixpkgs.fetchFromGitHub {
    owner = "godotengine";
    repo = "godot";
    rev = "${godot_version}-stable";
    # We use this placeholder to get the right hash from the first build attempt
    # You can also use nix-prefetch-url https://github.com/godotengine/godot/archive/4.4-stable.tar.gz
    sha256 = "sha256-net4F3qgxAP0TIEuecwuf/ltYF0d33f2fpfpsc3UQdE=";
  };

  # Native build dependencies
  python3 = crossenv.nixpkgs.python3;
  scons = crossenv.nixpkgs.scons;
  
  # Helper function to determine platform-specific options
  getPlatformOptions = platform: arch: 
    let
      baseOptions = [
        "production=yes"
        "verbose=yes"
        "warnings=no"
        "progress=no"
      ];
      
      # Updated Windows options based on official build containers
      windowsOptions = [
        "use_mingw=yes"
#        "d3d12=yes" // TODO: Add this later
      ] ++ (if arch == "arm64" then [ 
        "use_llvm=yes" 
       ] else []);
      
      # Linux options based on official build containers
      linuxOptions = [
        "use_static_cpp=yes"
        "use_llvm=no"
        "pulseaudio=no"  # Use Buildroot SDK instead of system libraries
        "wayland=yes"    # Explicitly enable Wayland support
        "production=yes" # Ensure production builds
        "accesskit_sdk_path=" # We're not using AccessKit
      ];
      
      macosOptions = [
        "osxcross_sdk=darwin15.2" # Use the SDK version available in nixcrpkgs
        "use_volk=no"
      ];
      
      webOptions = [
        "use_closure_compiler=yes"
        "javascript_eval=no"
      ];
      
      # Select platform-specific options
      platformSpecificOptions = 
        if platform == "windows" then windowsOptions
        else if platform == "linux" then linuxOptions
        else if platform == "macos" then macosOptions
        else if platform == "web" then webOptions
        else [];
    in
    baseOptions ++ platformSpecificOptions;

  # Determine the correct target
  getTarget = platform: 
    if platform == "windows" || platform == "web" then "template_release"
    else "template_release"; # Default to template_release
  
  # For Linux we build both debug and release templates + editor in the build script

  # Map OS to Godot's platform identifier
  getPlatformName = os:
    if os == "macos" then "macos"
    else if os == "linux" then "linuxbsd" # Godot uses "linuxbsd" as its platform identifier
    else if os == "windows" then "windows"
    else if os == "emscripten" then "web"
    else throw "Unsupported OS for Godot: ${os}";

  # Map architecture to Godot's format
  getArchName = arch:
    if arch == "aarch64" then "arm64"
    else if arch == "x86_64" then "x86_64"
    else if arch == "i686" then "x86_32"
    else if arch == "arm" then "arm32"
    else if arch == "wasm32" then "wasm32"
    else throw "Unsupported architecture for Godot: ${arch}";

  # Determine platform
  platform = getPlatformName crossenv.os;
  
  # Determine architecture
  arch = getArchName crossenv.arch;
  
  # Get build target
  target = getTarget platform;
  
  # Get platform-specific options
  platformOptions = getPlatformOptions platform arch;
  optionsString = builtins.concatStringsSep " " (map (opt: "${opt}") platformOptions);

  # Source the appropriate build script based on platform
  # Each platform has its own specialized build script
  buildScript = 
    if platform == "linuxbsd" then ./scripts/build-linux.sh
    else if platform == "windows" then ./scripts/build-windows.sh
    else if platform == "macos" then ./scripts/build-macos.sh
    else if platform == "web" then ./scripts/build-web.sh
    else throw "Unsupported platform: ${platform}. Add a build script for this platform.";
  
  # Additional dependencies for Windows builds 
  # Based on official Godot build container (Dockerfile.windows)
  windowsDeps = [
    # Using the mingw toolchain from nixcrpkgs instead of nixpkgs
    # nixcrpkgs automatically provides the appropriate mingw toolchain
    # based on the selected crossenv
    # This is preferred over crossenv.nixpkgs.mingw32-w64
  ];
  
  # Import Buildroot SDK derivation
  buildroot_sdk = import ./buildroot-sdk.nix { 
    inherit crossenv;
    inherit (crossenv.nixpkgs) fetchurl;
  };
  
  # Additional dependencies for Linux builds
  # Based on official Godot build container (Dockerfile.linux)
  linuxDeps = [
    # Wayland support
    crossenv.nixpkgs.wayland.scanner
    crossenv.nixpkgs.wayland-protocols
    # Standard build tools
    crossenv.nixpkgs.bzip2
    crossenv.nixpkgs.xz
  ];

in crossenv.make_derivation rec {
  name = "godot-${godot_version}-${crossenv.host}";
  
  src = godot_src;
  
  # Native build dependencies
  native_inputs = [ python3 scons crossenv.nixpkgs.gcc ];

  # Target-specific dependencies based on platform
  target_inputs = 
    if platform == "windows" then windowsDeps
    else if platform == "linux" then linuxDeps
    else [];

  # Pass variables to the build script
  passAsFile = [];
  
  # Use the platform-specific build script directly
  builder = buildScript;
  
  # Environment variables to pass to the build script
  inherit godot_version platform arch target optionsString scons;
  
  # Pass buildroot SDK for Linux builds
  godot_buildroot_sdk = 
    if platform == "linuxbsd" then
      buildroot_sdk.${arch}
    else null;
}
