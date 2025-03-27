#!/bin/sh
source $setup

echo "Building Godot ${godot_version} for Web (${arch})..."

# Create build directory and copy source
mkdir -p build
cp -r $src/* build/
cd build

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