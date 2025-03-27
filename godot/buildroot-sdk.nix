{ crossenv, fetchurl }:

let
  buildroot_version = "godot-2023.08.x-4";

  # Define buildroot SDK URLs and hashes for each architecture
  sdks = {
    x86_64 = {
      url = "https://github.com/godotengine/buildroot/releases/download/${buildroot_version}/x86_64-godot-linux-gnu_sdk-buildroot.tar.bz2";
      sha256 = "sha256-uJ8XOx8vLzXzCQvE761zLxwMHBIG5UgM/LFBl3AQvJQ=";
      prefix = "x86_64-godot-linux-gnu";
    };
    x86_32 = {
      url = "https://github.com/godotengine/buildroot/releases/download/${buildroot_version}/i686-godot-linux-gnu_sdk-buildroot.tar.bz2";
      sha256 = "sha256-W+WRPnTDFaD6Ijmve0v7X5UzSnEjcvxuFBx+UFSN/6s=";
      prefix = "i686-godot-linux-gnu";
    };
    arm64 = {
      url = "https://github.com/godotengine/buildroot/releases/download/${buildroot_version}/aarch64-godot-linux-gnu_sdk-buildroot.tar.bz2";
      sha256 = "sha256-17Zzgj6AeKxw/6ICtEcTVuyjYLgJYMbRpyKvDAOuop0=";
      prefix = "aarch64-godot-linux-gnu";
    };
    arm32 = {
      url = "https://github.com/godotengine/buildroot/releases/download/${buildroot_version}/arm-godot-linux-gnueabihf_sdk-buildroot.tar.bz2";
      sha256 = "sha256-Bp/1GDIu99hFM4Q8T49jq4RDsaJCZLJPMOSPz1K1L00=";
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
      
      # Add pkgconf as a native input for the wrapper script
      native_inputs = with crossenv.nixpkgs; [
        pkgconf
      ];
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
        
        # Ensure pkgconf is available or create it
        if [ -f "$out/$sdk_prefix"_sdk-buildroot/bin/pkgconf ]; then
          # Make existing pkgconf executable
          chmod +x "$out/$sdk_prefix"_sdk-buildroot/bin/pkgconf
        else
          echo "Creating pkgconf in SDK..."
          cat > "$out/$sdk_prefix"_sdk-buildroot/bin/pkgconf" << EOF
#!/bin/sh
# Wrapper for pkgconf using the Nix-provided pkgconf
$pkgconf/bin/pkgconf "\$@"
EOF
          chmod +x "$out/$sdk_prefix"_sdk-buildroot/bin/pkgconf"
        fi
        
        # Ensure pkg-config is a symlink to pkgconf
        if [ ! -f "$out/$sdk_prefix"_sdk-buildroot/bin/pkg-config" ]; then
          echo "Creating pkg-config symlink to pkgconf..."
          ln -sf "$out/$sdk_prefix"_sdk-buildroot/bin/pkgconf" "$out/$sdk_prefix"_sdk-buildroot/bin/pkg-config"
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
        
        # Double-check pkgconf exists (the wrapper should have created it)
        if [ ! -f "$out/$sdk_prefix"_sdk-buildroot/bin/pkgconf" ]; then
          echo "Error: pkgconf not found in the SDK. This should have been created earlier."
          exit 1
        fi
        
        # Double-check pkg-config exists as a symlink to pkgconf
        if [ ! -f "$out/$sdk_prefix"_sdk-buildroot/bin/pkg-config" ]; then
          echo "Creating pkg-config symlink to pkgconf..."
          ln -sf "$out/$sdk_prefix"_sdk-buildroot/bin/pkgconf" "$out/$sdk_prefix"_sdk-buildroot/bin/pkg-config"
        fi
        EOF
        
        chmod +x $out/bin/setup-env.sh
      '';
    };
  
  # Create derivations for all architectures
  sdk_derivations = builtins.mapAttrs mkSdkDerivation sdks;
  
in sdk_derivations
