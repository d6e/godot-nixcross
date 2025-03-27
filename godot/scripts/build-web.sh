#!/bin/sh
source $setup

echo "Building Godot ${godot_version} for Web (${arch})..."

# Create build directory and copy source
mkdir -p build
cp -r $src/* build/
cd build

# Set up cross-compilation environment variables for Web/Emscripten
# These are usually set up by the emscripten environment in nixcrpkgs
export EMSCRIPTEN_ROOT=${EMSCRIPTEN_ROOT:-/usr/lib/emscripten}
export EM_CONFIG=${EM_CONFIG:-""}
export EM_CACHE=${EM_CACHE:-""}
export CC=$host-emcc
export CXX=$host-em++
export AR=$host-emar
export RANLIB=$host-emranlib
export CFLAGS=$CFLAGS
export CXXFLAGS=$CXXFLAGS
export LDFLAGS=$LDFLAGS

# Configure template build command
template_build_cmd="${scons}/bin/scons \
  platform=web \
  arch=${arch} \
  target=${target} \
  ${optionsString}"

# Build Godot template
echo "Running: $template_build_cmd"
$template_build_cmd

# Create output directory structure
mkdir -p $out/bin
mkdir -p $out/templates/${arch}

# Copy binaries to output location - web has multiple file types
cp -v bin/*.wasm* $out/templates/${arch}/
cp -v bin/*.js* $out/templates/${arch}/
cp -v bin/*.html* $out/templates/${arch}/
cp -v bin/*.wasm* $out/bin/
cp -v bin/*.js* $out/bin/
cp -v bin/*.html* $out/bin/

# Print summary of build
echo "Build completed for Web (${arch})"
echo "Files in template directory:"
ls -la $out/templates/${arch}/
echo "Files in bin directory:"
ls -la $out/bin/