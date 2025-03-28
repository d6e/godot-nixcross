#!/bin/sh
source $setup

echo "Building Godot ${godot_version} for Linux (${arch})..."

# Create build directory and copy source
mkdir -p build
cp -r $src/* build/
cd build
# Ensure we have write permissions in the build directory
chmod -R +w .

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
GODOT_SDK_PATH="$godot_buildroot_sdk/${SDK_PREFIX}_sdk-buildroot"
echo "Using Buildroot SDK from: $GODOT_SDK_PATH"

# The Buildroot SDK should be properly set up by the buildroot-sdk.nix derivation
# Store the original PATH to restore it later if needed
export BASE_PATH=$PATH

# Add the SDK bin directory to PATH (following the official build containers approach)
export PATH="$GODOT_SDK_PATH/bin:$PATH"

# Set up environment variables for the build
echo "Setting up environment for Buildroot SDK..."

# Set compiler environment variables
export CC="${SDK_PREFIX}-gcc"
export CXX="${SDK_PREFIX}-g++"
export AR="${SDK_PREFIX}-ar"
export LD="${SDK_PREFIX}-ld"
export STRIP="${SDK_PREFIX}-strip"
export RANLIB="${SDK_PREFIX}-ranlib"

# Set pkg-config environment variables
export PKG_CONFIG="$GODOT_SDK_PATH/bin/pkg-config"
export PKG_CONFIG_PATH="$GODOT_SDK_PATH/lib/pkgconfig"
export PKG_CONFIG_LIBDIR="$GODOT_SDK_PATH/lib/pkgconfig"
export PKG_CONFIG_SYSROOT_DIR="$GODOT_SDK_PATH"

# Set compiler flags
export CFLAGS="-I$GODOT_SDK_PATH/include -fpermissive -Wno-enum-conversion"
export CXXFLAGS="-I$GODOT_SDK_PATH/include -fpermissive -Wno-enum-conversion"
export LDFLAGS="-L$GODOT_SDK_PATH/lib"

# Verify that everything is set up correctly
echo "Verifying Buildroot SDK setup:"
echo "SDK path: $GODOT_SDK_PATH"
echo "C compiler: $(which $CC)"
echo "C++ compiler: $(which $CXX)"
echo "pkg-config: $(which $PKG_CONFIG)"

# Test pkg-config
$PKG_CONFIG --version || echo "Warning: pkg-config is not working properly"

# Create output directory structure
mkdir -p $out/bin
mkdir -p $out/templates/${arch}
mkdir -p $out/templates-debug/${arch}
mkdir -p $out/tools/${arch}

# Common SCons options
COMMON_OPTS="platform=linuxbsd \
  arch=${arch} \
  ${optionsString} \
  builtin_freetype=yes \
  builtin_libpng=yes \
  builtin_zlib=yes \
  use_static_cpp=yes \
  use_lto=no \
  verbose=yes"

# If we're building for an architecture that can run the editor, build it first
if [ "${arch}" = "x86_64" ] || [ "${arch}" = "arm64" ] || [ "${arch}" = "x86_32" ] || [ "${arch}" = "arm32" ]; then
  echo "Building editor for ${arch}..."
  
  # Build the editor
  ${scons}/bin/scons $COMMON_OPTS target=editor
  
  # Copy editor binaries
  mkdir -p $out/tools/${arch}
  cp -vp bin/* $out/tools/${arch}/
  
  # Clean up before next build
  rm -rf bin
fi

# Build debug template
echo "Building debug template for ${arch}..."
${scons}/bin/scons $COMMON_OPTS target=template_debug

# Copy debug template binaries
mkdir -p $out/templates-debug/${arch}
cp -vp bin/* $out/templates-debug/${arch}/

# Clean up before next build
rm -rf bin

# Build release template
echo "Building release template for ${arch}..."
${scons}/bin/scons $COMMON_OPTS target=template_release

# Copy release template binaries
mkdir -p $out/templates/${arch}
cp -vp bin/* $out/templates/${arch}/

# Copy binaries to bin directory for easy access
mkdir -p $out/bin/${arch}
cp -vp bin/godot.*.linuxbsd.* $out/bin/${arch}/ || echo "Note: Editor binary not found for bin directory"

# Print summary of build
echo "Build completed for Linux (${arch})"
echo "Files in template directory:"
ls -la $out/templates/${arch}/
echo "Files in template-debug directory:"
ls -la $out/templates-debug/${arch}/
if [ -d "$out/tools/${arch}" ]; then
  echo "Files in tools directory:"
  ls -la $out/tools/${arch}/
fi
echo "Files in bin directory:"
ls -la $out/bin/${arch}/