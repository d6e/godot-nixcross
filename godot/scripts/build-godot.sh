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
  # Ensure all template binaries are properly copied
  cp -v bin/*.windows.* $out/templates/${arch}/
  # Copy to bin directory for direct access
  for file in $out/templates/${arch}/*; do
    cp -v "$file" $out/bin/
  done
elif [ "${platform}" = "macos" ]; then
  cp -v bin/*.macos.* $out/templates/${arch}/
  cp -v bin/*.macos.* $out/bin/
elif [ "${platform}" = "linuxbsd" ]; then
  # For Linux builds, handle the file patterns properly
  cp -v bin/godot.*.linuxbsd.* $out/templates/${arch}/
  cp -v bin/godot.*.linuxbsd.* $out/bin/
  # Also copy any shared libraries if they exist
  cp -v bin/*.so $out/templates/${arch}/ || true
  cp -v bin/*.so $out/bin/ || true
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
      # Copy all editor executables and required DLLs
      cp -v bin/*editor*.exe $out/bin/
      cp -v bin/*.dll $out/bin/ || true
      
      # For arm64 Windows builds with LLVM, ensure all required files are copied
      if [ "${arch}" = "arm64" ]; then
        echo "Copying additional files for Windows ARM64 build..."
        # Ensure any additional LLVM-specific files are copied
        cp -v bin/*.bin $out/bin/ || true
        cp -v bin/*.json $out/bin/ || true
      fi
    elif [ "${platform}" = "macos" ]; then
      cp -v bin/*editor* $out/bin/
    elif [ "${platform}" = "linuxbsd" ]; then
      # For Linux editor builds, copy all editor binaries and shared libraries
      cp -v bin/*editor* $out/bin/
      # Copy additional architecture-specific files if they exist
      if [ "${arch}" = "arm64" ] || [ "${arch}" = "arm32" ]; then
        echo "Copying additional files for Linux ${arch} build..."
        cp -v bin/*.so.* $out/bin/ || true
      fi
    fi
  fi
fi

# Print summary of build
echo "Build completed for ${platform} (${arch})"
echo "Files in template directory:"
ls -la $out/templates/${arch}/
echo "Files in bin directory:"
ls -la $out/bin/