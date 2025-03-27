#!/bin/sh
source $setup

echo "Building Godot ${godot_version} for Linux (${arch})..."

# Create build directory and copy source
mkdir -p build
cp -r $src/* build/
cd build
# Ensure we have write permissions in the build directory
chmod -R +w .

# We don't need to patch the source code
# Instead, we'll set the CFLAGS for SCons to handle type conversions
# by adding a custom flag export

# Export extra flags to handle type conversion issues
export GODOT_EXTRA_CFLAGS="-fpermissive -Wno-enum-conversion"

# Set up basic build environment
echo "Setting up buildroot SDK environment..."

# Switch to using the cross-compiler from the Buildroot SDK
# instead of the native host compiler
if [ "${arch}" = "x86_64" ]; then
  export CC="x86_64-godot-linux-gnu-gcc"
  export CXX="x86_64-godot-linux-gnu-g++"
elif [ "${arch}" = "x86_32" ]; then
  export CC="i686-godot-linux-gnu-gcc"
  export CXX="i686-godot-linux-gnu-g++"
elif [ "${arch}" = "arm64" ]; then
  export CC="aarch64-godot-linux-gnu-gcc"
  export CXX="aarch64-godot-linux-gnu-g++"
elif [ "${arch}" = "arm32" ]; then
  export CC="arm-godot-linux-gnueabihf-gcc"
  export CXX="arm-godot-linux-gnueabihf-g++"
else
  echo "Error: Unknown architecture ${arch}"
  exit 1
fi

# Determine the SDK prefix based on architecture
if [ "${arch}" = "x86_64" ]; then
  SDK_PREFIX="x86_64-godot-linux-gnu"
elif [ "${arch}" = "x86_32" ]; then
  SDK_PREFIX="i686-godot-linux-gnu"
elif [ "${arch}" = "arm64" ]; then
  SDK_PREFIX="aarch64-godot-linux-gnu"
elif [ "${arch}" = "arm32" ]; then
  SDK_PREFIX="arm-godot-linux-gnueabihf"
else
  echo "Error: Unknown architecture ${arch}"
  exit 1
fi

# Set up Buildroot SDK paths
export GODOT_SDK_PATH="$godot_buildroot_sdk/${SDK_PREFIX}_sdk-buildroot"

# Add the SDK bin directory to PATH (like in the official build script)
export PATH="$GODOT_SDK_PATH/bin:$PATH"

# Add include and library paths from Buildroot
export CFLAGS="-I$GODOT_SDK_PATH/include"
export CXXFLAGS="-I$GODOT_SDK_PATH/include"
export LDFLAGS="-L$GODOT_SDK_PATH/lib"

# Set up pkg-config with the SDK
export PKG_CONFIG_PATH="$GODOT_SDK_PATH/lib/pkgconfig:$PKG_CONFIG_PATH"
export PKG_CONFIG_LIBDIR="$GODOT_SDK_PATH/lib/pkgconfig"
export PKG_CONFIG_SYSROOT_DIR="$GODOT_SDK_PATH"

# Use the SDK's pkg-config instead of system one
export PKG_CONFIG="$GODOT_SDK_PATH/bin/pkg-config"

# Make sure we're using SDK's pkg-config
echo "Testing pkg-config setup:"
echo "Using SDK pkg-config: $PKG_CONFIG"
echo "PKG_CONFIG_PATH: $PKG_CONFIG_PATH"
echo "PKG_CONFIG_LIBDIR: $PKG_CONFIG_LIBDIR"
echo "PKG_CONFIG_SYSROOT_DIR: $PKG_CONFIG_SYSROOT_DIR"

# Try running pkg-config to verify it works
echo "Testing pkg-config functionality:"
$PKG_CONFIG --version || echo "pkg-config is not working properly"

# Verify pkg-config can find specific packages
echo "Checking if pkg-config can find zlib:"
$PKG_CONFIG --exists zlib && echo "zlib found" || echo "zlib not found via pkg-config"
echo "Listing available packages:"
ls -la $PKG_CONFIG_LIBDIR

# Add fpermissive flag and remove LTO flag
# Also cast between VkFormat and uint32_t should be allowed
export CXXFLAGS="-fpermissive -fno-lto -Wno-enum-conversion"
export CFLAGS="-fpermissive -fno-lto -Wno-enum-conversion"

# Pass these flags to SCons
echo "Adding extra flags to handle type conversion issues"

# Configure template build command with buildroot SDK environment
template_build_cmd="${scons}/bin/scons \
  platform=linuxbsd \
  arch=${arch} \
  target=${target} \
  ${optionsString} \
  builtin_freetype=yes \
  builtin_libpng=yes \
  builtin_zlib=yes \
  use_static_cpp=yes \
  use_mingw=no \
  use_lto=no \
  CC=$CC \
  CXX=$CXX \
  AR=${SDK_PREFIX}-ar \
  PKG_CONFIG=$PKG_CONFIG \
  PKG_CONFIG_PATH=$PKG_CONFIG_PATH \
  PKG_CONFIG_LIBDIR=$PKG_CONFIG_LIBDIR \
  PKG_CONFIG_SYSROOT_DIR=$PKG_CONFIG_SYSROOT_DIR"

# Create output directory structure
mkdir -p $out/bin
mkdir -p $out/templates/${arch}
mkdir -p $out/templates-debug/${arch}
mkdir -p $out/tools/${arch}

# If we're building for an architecture that can run the editor, build it first
if [ "${arch}" = "x86_64" ] || [ "${arch}" = "arm64" ] || [ "${arch}" = "x86_32" ] || [ "${arch}" = "arm32" ]; then
  # Build editor version with buildroot SDK environment
  editor_build_cmd="${scons}/bin/scons \
    platform=linuxbsd \
    arch=${arch} \
    target=editor \
    ${optionsString} \
    builtin_freetype=yes \
    builtin_libpng=yes \
    builtin_zlib=yes \
    use_static_cpp=yes \
    use_mingw=no \
    use_lto=no \
    CC=$CC \
    CXX=$CXX \
    AR=${SDK_PREFIX}-ar \
    PKG_CONFIG=$PKG_CONFIG \
    PKG_CONFIG_PATH=$PKG_CONFIG_PATH \
    PKG_CONFIG_LIBDIR=$PKG_CONFIG_LIBDIR \
    PKG_CONFIG_SYSROOT_DIR=$PKG_CONFIG_SYSROOT_DIR"
  
  echo "Running: $editor_build_cmd"
  echo "Using buildroot SDK from: $GODOT_SDK_PATH"
  echo "Using compiler: $(which $CC)"
  $editor_build_cmd
  
  # Copy editor binaries - fail if not found
  cp -v bin/* $out/tools/${arch}/
  
  # Clean up before next build
  rm -rf bin
fi

# Build debug template
debug_build_cmd="${scons}/bin/scons \
  platform=linuxbsd \
  arch=${arch} \
  target=template_debug \
  ${optionsString} \
  builtin_freetype=yes \
  builtin_libpng=yes \
  builtin_zlib=yes \
  use_static_cpp=yes \
  use_mingw=no \
  use_lto=no \
  CC=$CC \
  CXX=$CXX \
  AR=${SDK_PREFIX}-ar \
  PKG_CONFIG=$PKG_CONFIG \
  PKG_CONFIG_PATH=$PKG_CONFIG_PATH \
  PKG_CONFIG_LIBDIR=$PKG_CONFIG_LIBDIR \
  PKG_CONFIG_SYSROOT_DIR=$PKG_CONFIG_SYSROOT_DIR"

echo "Running debug template build: $debug_build_cmd"
echo "Using buildroot SDK from: $GODOT_SDK_PATH"
$debug_build_cmd

# Copy debug template binaries
cp -v bin/* $out/templates-debug/${arch}/

# Clean up before next build
rm -rf bin

# Build release template 
release_build_cmd="${scons}/bin/scons \
  platform=linuxbsd \
  arch=${arch} \
  target=template_release \
  ${optionsString} \
  builtin_freetype=yes \
  builtin_libpng=yes \
  builtin_zlib=yes \
  use_static_cpp=yes \
  use_mingw=no \
  use_lto=no \
  CC=$CC \
  CXX=$CXX \
  AR=${SDK_PREFIX}-ar \
  PKG_CONFIG=$PKG_CONFIG \
  PKG_CONFIG_PATH=$PKG_CONFIG_PATH \
  PKG_CONFIG_LIBDIR=$PKG_CONFIG_LIBDIR \
  PKG_CONFIG_SYSROOT_DIR=$PKG_CONFIG_SYSROOT_DIR"

echo "Running release template build: $release_build_cmd"
echo "Using buildroot SDK from: $GODOT_SDK_PATH"
$release_build_cmd

# Copy release template binaries
cp -v bin/* $out/templates/${arch}/

# Copy binaries to bin directory for easy access
mkdir -p $out/bin/${arch}
cp -v bin/godot.*.linuxbsd.* $out/bin/${arch}/

# Print summary of build
echo "Build completed for Linux (${arch})"
echo "Files in template directory:"
ls -la $out/templates/${arch}/
echo "Files in bin directory:"
ls -la $out/bin/