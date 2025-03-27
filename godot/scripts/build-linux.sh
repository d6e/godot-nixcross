#!/bin/sh
source $setup

echo "Building Godot ${godot_version} for Linux (${arch})..."

# Create build directory and copy source
mkdir -p build
cp -r $src/* build/
cd build
# Ensure we have write permissions in the build directory
chmod -R +w .

# Setup buildroot SDK environment
echo "Setting up buildroot SDK environment..."
source $godot_buildroot_sdk/bin/setup-env.sh

# Configure template build command with buildroot SDK environment
template_build_cmd="${scons}/bin/scons \
  platform=linuxbsd \
  arch=${arch} \
  target=${target} \
  ${optionsString} \
  builtin_freetype=yes \
  builtin_libpng=yes \
  builtin_zlib=yes \
  use_static_cpp=yes"

# Build Godot template
echo "Running: $template_build_cmd"
echo "Using buildroot SDK from: $GODOT_SDK_PATH"
echo "Using compiler: $(which $CC)"
$template_build_cmd

# Create output directory structure
mkdir -p $out/bin
mkdir -p $out/templates/${arch}

# Copy binaries to output location - fail if binaries not found
echo "Copying built binaries to output locations..."
cp -v bin/godot.*.linuxbsd.* $out/templates/${arch}/
cp -v bin/godot.*.linuxbsd.* $out/bin/
# Also copy any shared libraries if they exist (optional)
if ls bin/*.so* >/dev/null 2>&1; then
  cp -v bin/*.so* $out/templates/${arch}/
  cp -v bin/*.so* $out/bin/
fi

# If we're building for an architecture that can run the editor, build it
if [ "${arch}" = "x86_64" ] || [ "${arch}" = "arm64" ]; then
  # Build editor version with buildroot SDK environment
  editor_build_cmd="${scons}/bin/scons \
    platform=linuxbsd \
    arch=${arch} \
    target=editor \
    ${optionsString} \
    builtin_freetype=yes \
    builtin_libpng=yes \
    builtin_zlib=yes \
    use_static_cpp=yes"
  
  echo "Running: $editor_build_cmd"
  echo "Using buildroot SDK from: $GODOT_SDK_PATH"
  $editor_build_cmd
  
  # Copy editor binaries - fail if not found
  cp -v bin/*editor* $out/bin/
  
  # Copy additional dependencies (optional)
  if ls bin/*.so* >/dev/null 2>&1; then
    cp -v bin/*.so* $out/bin/
  fi
  
  # ARM-specific handling
  if [ "${arch}" = "arm64" ] || [ "${arch}" = "arm32" ]; then
    echo "Copying additional files for Linux ${arch} build..."
    # Copy any architecture-specific files (optional)
    if ls bin/*.so.* >/dev/null 2>&1; then
      cp -v bin/*.so.* $out/bin/
    fi
  fi
fi

# Print summary of build
echo "Build completed for Linux (${arch})"
echo "Files in template directory:"
ls -la $out/templates/${arch}/
echo "Files in bin directory:"
ls -la $out/bin/