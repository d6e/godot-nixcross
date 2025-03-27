{ crossenv, fetchurl }:

let
  buildroot_version = "godot-2023.08.x-4";

  # Define buildroot SDK URLs and hashes for each architecture
  sdks = {
    x86_64 = {
      url = "https://github.com/godotengine/buildroot/releases/download/${buildroot_version}/x86_64-godot-linux-gnu_sdk-buildroot.tar.bz2";
      sha256 = "sha256-bAf8QQ03wMDygfN9e5VyJiOahE5C9bUZjIJjqWj9mVo=";
      prefix = "x86_64-godot-linux-gnu";
    };
    x86_32 = {
      url = "https://github.com/godotengine/buildroot/releases/download/${buildroot_version}/i686-godot-linux-gnu_sdk-buildroot.tar.bz2";
      sha256 = "sha256-JI7H0J4zxRXSNwkSS+LXlWZp5wQxH06ZVUYRzGjEKRw=";
      prefix = "i686-godot-linux-gnu";
    };
    arm64 = {
      url = "https://github.com/godotengine/buildroot/releases/download/${buildroot_version}/aarch64-godot-linux-gnu_sdk-buildroot.tar.bz2";
      sha256 = "sha256-Bl/7NnrfayDv/mFRmMkGfYMF3b+2ZoBYXq13rw+E+Ss=";
      prefix = "aarch64-godot-linux-gnu";
    };
    arm32 = {
      url = "https://github.com/godotengine/buildroot/releases/download/${buildroot_version}/arm-godot-linux-gnueabihf_sdk-buildroot.tar.bz2";
      sha256 = "sha256-nxKvvb1rJrEwnuYdkE5ekBM9H68kbFJC+iQB5EKOSXk=";
      prefix = "arm-godot-linux-gnueabihf";
    };
  };
  
  # Function to create a derivation for a specific SDK
  mkSdkDerivation = arch: sdk: 
    crossenv.make_derivation {
      name = "godot-buildroot-sdk-${arch}";
      
      # Download the SDK tarball
      src = fetchurl {
        url = sdk.url;
        sha256 = sdk.sha256;
      };
      
      # No need for special build dependencies
      native_inputs = [];
      target_inputs = [];
      
      # Determine prefix based on architecture
      sdk_prefix = sdk.prefix;
      
      # Custom build script to prepare the SDK
      builder = builtins.toFile "builder.sh" ''
        #!/bin/sh
        source $setup
        
        # Create output directory
        mkdir -p $out
        
        # Extract the SDK
        echo "Extracting buildroot SDK for $sdk_prefix..."
        tar xf $src -C $out
        
        # Run the relocate script to fix paths
        cd $out/$sdk_prefix"_sdk-buildroot"
        chmod +x relocate-sdk.sh
        ./relocate-sdk.sh
        
        # Ensure pkgconf is available and executable
        if [ -f "$out/$sdk_prefix"_sdk-buildroot/bin/pkgconf ]; then
          chmod +x "$out/$sdk_prefix"_sdk-buildroot/bin/pkgconf
        else
          echo "Warning: pkgconf not found in SDK"
        fi
        
        # Create a wrapper script that sets up environment variables
        mkdir -p $out/bin
        cat > $out/bin/setup-env.sh << EOF
        #!/bin/sh
        export PATH="$out/$sdk_prefix"_sdk-buildroot/bin":\$PATH"
        export CC="$sdk_prefix-gcc"
        export CXX="$sdk_prefix-g++"
        export AR="$sdk_prefix-ar"
        export STRIP="$sdk_prefix-strip"
        export RANLIB="$sdk_prefix-ranlib" 
        export LD="$sdk_prefix-ld"
        export GODOT_SDK_PATH="$out/$sdk_prefix"_sdk-buildroot""
        
        # Create a symlink for pkg-config if it doesn't exist
        if [ ! -f "$out/$sdk_prefix"_sdk-buildroot/bin/pkg-config ] && [ -f "$out/$sdk_prefix"_sdk-buildroot/bin/pkgconf" ]; then
          ln -sf "$out/$sdk_prefix"_sdk-buildroot/bin/pkgconf" "$out/$sdk_prefix"_sdk-buildroot/bin/pkg-config"
        fi
        
        # Also check if pkgconf exists and create it if needed
        if [ ! -f "$out/$sdk_prefix"_sdk-buildroot/bin/pkgconf" ]; then
          cat > "$out/$sdk_prefix"_sdk-buildroot/bin/pkgconf" << PKGCONF
        #!/bin/sh
        # Minimal pkgconf wrapper
        echo ""
        exit 0
        PKGCONF
          chmod +x "$out/$sdk_prefix"_sdk-buildroot/bin/pkgconf"
          # Create pkg-config symlink
          ln -sf "$out/$sdk_prefix"_sdk-buildroot/bin/pkgconf" "$out/$sdk_prefix"_sdk-buildroot/bin/pkg-config"
        fi
        EOF
        
        chmod +x $out/bin/setup-env.sh
      '';
    };
  
  # Create derivations for all architectures
  sdk_derivations = builtins.mapAttrs mkSdkDerivation sdks;
  
in sdk_derivations