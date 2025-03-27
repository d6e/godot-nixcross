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
      
      # Add pkgconf, file, patchelf as native inputs for the wrapper script
      native_inputs = with crossenv.nixpkgs; [
        pkgconf
        file
        patchelf
        glibc
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
        
        # Set up SDK paths
        SDK_DIR="$out/$sdk_prefix"_sdk-buildroot
        
        # Get the dynamic linker path directly
        DYNAMIC_LINKER=$(patchelf --print-interpreter $(which sh) 2>/dev/null || echo "/lib64/ld-linux-x86-64.so.2")
        echo "Using dynamic linker: $DYNAMIC_LINKER"
        
        # Fix the interpreter for all executables using patchelf
        find "$SDK_DIR/bin" -type f -executable -exec sh -c '
          if file -b "$1" | grep -q "ELF.*executable"; then
            echo "Patching ELF executable: $1"
            patchelf --set-interpreter "'$DYNAMIC_LINKER'" "$1" || echo "Failed to patch $1"
          fi
        ' sh {} \;
        
        # Also patch shared libraries in the lib directory
        echo "Patching shared libraries..."
        find "$SDK_DIR/lib" -type f -name "*.so*" -exec sh -c '
          if file -b "$1" | grep -q "ELF.*shared object"; then
            echo "Patching shared library: $1"
            patchelf --set-rpath "'$SDK_DIR/lib'" "$1" || echo "Failed to patch RPATH for $1"
          fi
        ' sh {} \;
        
        # The Buildroot SDK already has pkgconf and pkg-config
        echo "Verifying pkg-config in SDK..."
        if [ ! -f "$SDK_DIR/bin/pkg-config" ]; then
          echo "Warning: pkg-config not found in SDK, this is unexpected"
        else
          echo "Found pkg-config in SDK: $(file $SDK_DIR/bin/pkg-config)"
        fi
        
        if [ ! -f "$SDK_DIR/bin/pkgconf" ]; then
          echo "Warning: pkgconf not found in SDK, this is unexpected"
        else
          echo "Found pkgconf in SDK: $(file $SDK_DIR/bin/pkgconf)"
        fi
        
        # Create compiler wrapper scripts
        echo "Creating compiler wrapper scripts..."

        # Get the gcc and g++ paths
        GCC_PATH=$(type -p gcc)
        GPP_PATH=$(type -p g++)
        AR_PATH=$(type -p ar)
        
        # Create wrapper for gcc
        echo "Creating gcc wrapper..."
        cat > "$SDK_DIR/bin/$sdk_prefix-gcc" << EOF
#!/bin/sh
# Wrapper for gcc
$GCC_PATH "\$@"
EOF
        chmod +x "$SDK_DIR/bin/$sdk_prefix-gcc"

        # Create wrapper for g++
        echo "Creating g++ wrapper..."
        cat > "$SDK_DIR/bin/$sdk_prefix-g++" << EOF
#!/bin/sh
# Wrapper for g++
$GPP_PATH "\$@"
EOF
        chmod +x "$SDK_DIR/bin/$sdk_prefix-g++"

        # Create wrapper for ar
        echo "Creating ar wrapper..."
        cat > "$SDK_DIR/bin/$sdk_prefix-ar" << EOF
#!/bin/sh
# Wrapper for ar
$AR_PATH "\$@"
EOF
        chmod +x "$SDK_DIR/bin/$sdk_prefix-ar"

        # Create wrapper for gcc-ar
        echo "Creating gcc-ar wrapper..."
        cat > "$SDK_DIR/bin/$sdk_prefix-gcc-ar" << EOF
#!/bin/sh
# Wrapper for gcc-ar
$AR_PATH "\$@"
EOF
        chmod +x "$SDK_DIR/bin/$sdk_prefix-gcc-ar"

        # Create wrapper for gcc-ranlib
        echo "Creating gcc-ranlib wrapper..."
        RANLIB_PATH=$(type -p ranlib)
        cat > "$SDK_DIR/bin/$sdk_prefix-gcc-ranlib" << EOF
#!/bin/sh
# Wrapper for gcc-ranlib
$RANLIB_PATH "\$@"
EOF
        chmod +x "$SDK_DIR/bin/$sdk_prefix-gcc-ranlib"

        # Create symlinks for other tools
        ln -sf "$sdk_prefix-gcc" "$SDK_DIR/bin/gcc"
        ln -sf "$sdk_prefix-g++" "$SDK_DIR/bin/g++"
        ln -sf "$sdk_prefix-ar" "$SDK_DIR/bin/ar"
        ln -sf "$sdk_prefix-gcc-ar" "$SDK_DIR/bin/gcc-ar"
        ln -sf "$sdk_prefix-gcc-ranlib" "$SDK_DIR/bin/gcc-ranlib"
        
        # Verify pkgconf and pkg-config are working
        echo "Verifying pkgconf and pkg-config setup..."
        
        # Special handling for pkgconf - make sure it's patched properly
        if [ -f "$SDK_DIR/bin/pkgconf" ]; then
          echo "Found pkgconf, ensuring it's properly patched..."
          patchelf --set-interpreter "$DYNAMIC_LINKER" "$SDK_DIR/bin/pkgconf" || echo "Failed to patch pkgconf"
          patchelf --set-rpath "$SDK_DIR/lib" "$SDK_DIR/bin/pkgconf" || echo "Failed to set RPATH for pkgconf"
          chmod +x "$SDK_DIR/bin/pkgconf"
        fi
        
        # Fix pkg-config script to correctly reference pkgconf
        if [ -f "$SDK_DIR/bin/pkg-config" ]; then
          echo "Fixing pkg-config script..."
          # Update the exec line to use an absolute path to pkgconf
          sed -i "s|exec.*pkgconf|exec $SDK_DIR/bin/pkgconf|" "$SDK_DIR/bin/pkg-config"
          chmod +x "$SDK_DIR/bin/pkg-config"
        fi
        
        echo "Testing pkgconf and pkg-config..."
        $SDK_DIR/bin/pkgconf --version || echo "Warning: pkgconf binary not working"
        $SDK_DIR/bin/pkg-config --version || echo "Warning: pkg-config script not working"
        
        # Create a wrapper script that sets up environment variables
        mkdir -p $out/bin
        cat > "$out/bin/setup-env.sh" << EOE
#!/bin/sh
export PATH="$SDK_DIR/bin:\$PATH"
export CC="$sdk_prefix-gcc"
export CXX="$sdk_prefix-g++"
export AR="$sdk_prefix-ar"
export STRIP="$sdk_prefix-strip"
export RANLIB="$sdk_prefix-ranlib" 
export LD="$sdk_prefix-ld"
export GODOT_SDK_PATH="$SDK_DIR"
EOE
        
        # Verify pkg-config paths are working
        echo "Testing pkg-config in SDK..."
        $SDK_DIR/bin/pkg-config --version
        echo "PKG_CONFIG_PATH in SDK should be: $SDK_DIR/lib/pkgconfig"
        
        chmod +x $out/bin/setup-env.sh
      '';
    };
  
  # Create derivations for all architectures
  sdk_derivations = builtins.mapAttrs mkSdkDerivation sdks;
  
in sdk_derivations
