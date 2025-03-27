#!/bin/sh
source $setup

echo "Building Godot ${godot_version} for Windows (${arch})..."

# Create build directory and copy source
mkdir -p build
cp -r $src/* build/
chmod -R +w build/
cd build

# Set up cross-compilation environment variables for Windows
export CC=$host-gcc
export CXX=$host-g++
export AR=$host-ar
export STRIP=$host-strip
export RANLIB=$host-ranlib
export LD=$host-ld
export WINDRES=$host-windres

# Configure template build command
template_build_cmd="${scons}/bin/scons \
  platform=windows \
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
cp -v bin/*.windows.* $out/templates/${arch}/
# Copy to bin directory for direct access
for file in $out/templates/${arch}/*; do
  cp -v "$file" $out/bin/
done

# If we're building for an architecture that can run the editor, build it
if [ "${arch}" = "x86_64" ] || [ "${arch}" = "arm64" ]; then
  # Build editor version
  editor_build_cmd="${scons}/bin/scons \
    platform=windows \
    arch=${arch} \
    target=editor \
    ${optionsString}"
  
  echo "Running: $editor_build_cmd"
  $editor_build_cmd
  
  # Copy editor binaries
  cp -v bin/*editor*.exe $out/bin/
  cp -v bin/*.dll $out/bin/ || true
  
  # For arm64 Windows builds with LLVM, ensure all required files are copied
  if [ "${arch}" = "arm64" ]; then
    echo "Copying additional files for Windows ARM64 build..."
    # Ensure any additional LLVM-specific files are copied
    cp -v bin/*.bin $out/bin/ || true
    cp -v bin/*.json $out/bin/ || true
  fi
fi

# Print summary of build
echo "Build completed for Windows (${arch})"
echo "Files in template directory:"
ls -la $out/templates/${arch}/
echo "Files in bin directory:"
ls -la $out/bin/