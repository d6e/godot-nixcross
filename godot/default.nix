{ crossenv }:

let
  godot_version = "4.4";
  godot_src = crossenv.nixpkgs.fetchFromGitHub {
    owner = "godotengine";
    repo = "godot";
    rev = "${godot_version}-stable";
    # This is a placeholder hash that will need to be updated when 4.4-stable is released
    # Nix will provide the correct hash when it first attempts to build
    sha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
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
      
      windowsOptions = [
        "use_mingw=yes"
      ] ++ (if arch == "arm64" then [ "use_llvm=yes" ] else []);
      
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
        else if platform == "macos" then macosOptions
        else if platform == "web" then webOptions
        else [];
    in
    baseOptions ++ platformSpecificOptions;

  # Determine the correct target
  getTarget = platform: 
    if platform == "windows" || platform == "web" then "template_release"
    else "release";

  # Map OS to Godot's platform identifier
  getPlatformName = os:
    if os == "macos" then "macos"
    else if os == "linux" then "linuxbsd"
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

in crossenv.make_derivation rec {
  name = "godot-${godot_version}-${crossenv.host}";
  
  src = godot_src;
  
  # Native build dependencies
  native_inputs = [ python3 scons ];

  # Target-specific dependencies based on platform
  target_inputs = [];

  # Actual builder script
  builder = crossenv.nixpkgs.writeScript "build-godot.sh" ''
    #!/bin/sh
    source $setup

    echo "Building Godot ${godot_version} for ${platform} (${arch})..."
    
    # Create build directory and copy source
    mkdir -p build
    cp -r $src/* build/
    cd build
    
    # Configure template build command
    template_build_cmd="${scons}/bin/scons \
      platform=${platform} \
      arch=${arch} \
      target=${target} \
      ${optionsString}"
    
    # Build Godot template
    echo "Running: $template_build_cmd"
    $template_build_cmd
    
    # Create output directory structure
    mkdir -p $out/bin
    mkdir -p $out/templates/${arch}
    
    # Copy binaries to output location based on platform
    if [ "${platform}" = "windows" ]; then
      cp -v bin/*.windows.* $out/templates/${arch}/
      # Also rename to match Godot's template naming convention
      for file in $out/templates/${arch}/*; do
        cp -v "$file" $out/bin/
      done
    elif [ "${platform}" = "macos" ]; then
      cp -v bin/*.macos.* $out/templates/${arch}/
      cp -v bin/*.macos.* $out/bin/
    elif [ "${platform}" = "linuxbsd" ]; then
      cp -v bin/*.linuxbsd.* $out/templates/${arch}/
      cp -v bin/*.linuxbsd.* $out/bin/
    elif [ "${platform}" = "web" ]; then
      cp -v bin/*.wasm* $out/templates/${arch}/
      cp -v bin/*.js* $out/templates/${arch}/
      cp -v bin/*.html* $out/templates/${arch}/
      cp -v bin/*.wasm* $out/bin/
      cp -v bin/*.js* $out/bin/
      cp -v bin/*.html* $out/bin/
    fi
    
    # If we're building for a desktop platform, also build an editor version
    if [ "${platform}" = "windows" ] || [ "${platform}" = "macos" ] || [ "${platform}" = "linuxbsd" ]; then
      if [ "${arch}" = "x86_64" ] || [ "${arch}" = "arm64" ]; then
        # Build editor version
        editor_build_cmd="${scons}/bin/scons \
          platform=${platform} \
          arch=${arch} \
          target=editor \
          ${optionsString}"
        
        echo "Running: $editor_build_cmd"
        $editor_build_cmd
        
        # Copy editor binaries
        if [ "${platform}" = "windows" ]; then
          cp -v bin/*editor*.exe $out/bin/
          cp -v bin/*.dll $out/bin/ || true
        elif [ "${platform}" = "macos" ]; then
          cp -v bin/*editor* $out/bin/
        elif [ "${platform}" = "linuxbsd" ]; then
          cp -v bin/*editor* $out/bin/
        fi
      fi
    fi
  '';
}