#!/bin/sh
source $setup

echo "Building Godot ${godot_version} for Linux (${arch})..."

# Create build directory and copy source
mkdir -p build
cp -r $src/* build/
cd build

# Set up cross-compilation environment variables
export CC=$host-gcc
export CXX=$host-g++
export AR=$host-ar
export STRIP=$host-strip
export RANLIB=$host-ranlib
export LD=$host-ld
export CFLAGS=$CFLAGS
export CXXFLAGS=$CXXFLAGS
export LDFLAGS=$LDFLAGS

# Configure template build command
template_build_cmd="${scons}/bin/scons \
  platform=linuxbsd \
  arch=${arch} \
  target=${target} \
  ${optionsString}"

# Build Godot template
echo "Running: $template_build_cmd"
$template_build_cmd

# Create output directory structure
mkdir -p $out/bin
mkdir -p $out/templates/${arch}

# Copy binaries to output location
cp -v bin/godot.*.linuxbsd.* $out/templates/${arch}/
cp -v bin/godot.*.linuxbsd.* $out/bin/
# Also copy any shared libraries if they exist
cp -v bin/*.so* $out/templates/${arch}/ || true
cp -v bin/*.so* $out/bin/ || true

# If we're building for an architecture that can run the editor, build it
if [ "${arch}" = "x86_64" ] || [ "${arch}" = "arm64" ]; then
  # Build editor version
  editor_build_cmd="${scons}/bin/scons \
    platform=linuxbsd \
    arch=${arch} \
    target=editor \
    ${optionsString}"
  
  echo "Running: $editor_build_cmd"
  $editor_build_cmd
  
  # Copy editor binaries
  cp -v bin/*editor* $out/bin/
  # Copy additional dependencies
  cp -v bin/*.so* $out/bin/ || true
  
  # ARM-specific handling
  if [ "${arch}" = "arm64" ] || [ "${arch}" = "arm32" ]; then
    echo "Copying additional files for Linux ${arch} build..."
    # Copy any architecture-specific files
    cp -v bin/*.so.* $out/bin/ || true
  fi
fi

# Print summary of build
echo "Build completed for Linux (${arch})"
echo "Files in template directory:"
ls -la $out/templates/${arch}/
echo "Files in bin directory:"
ls -la $out/bin/