#!/bin/sh
source $setup

echo "Building Godot ${godot_version} for macOS (${arch})..."

# Create build directory and copy source
mkdir -p build
cp -r $src/* build/
cd build

# Set up cross-compilation environment variables for macOS
export CC=$host-clang
export CXX=$host-clang++
export AR=$host-ar
export STRIP=$host-strip
export RANLIB=$host-ranlib
export LD=$host-ld
export CFLAGS=$CFLAGS
export CXXFLAGS=$CXXFLAGS
export LDFLAGS=$LDFLAGS
export OSXCROSS_SDK=darwin15.2

# Handle universal build specially
if [ "${arch}" = "universal" ]; then
  echo "Creating universal macOS build combining x86_64 and arm64..."
  
  # Build for x86_64 first
  x86_64_build_cmd="${scons}/bin/scons \
    platform=macos \
    arch=x86_64 \
    target=${target} \
    ${optionsString}"
    
  echo "Running x86_64 build: $x86_64_build_cmd"
  $x86_64_build_cmd
  
  # Rename the x86_64 binaries temporarily
  for file in bin/*.macos.*; do
    mv -v "$file" "${file}.x86_64"
  done
  
  # Build for arm64
  arm64_build_cmd="${scons}/bin/scons \
    platform=macos \
    arch=arm64 \
    target=${target} \
    ${optionsString}"
    
  echo "Running arm64 build: $arm64_build_cmd"
  $arm64_build_cmd
  
  # Create universal binaries using lipo
  mkdir -p bin/universal
  
  # For each arm64 binary, find the corresponding x86_64 binary and create a universal binary
  for arm64_file in bin/*.macos.*; do
    base_name=$(basename "$arm64_file")
    x86_64_file="bin/${base_name}.x86_64"
    universal_file="bin/universal/${base_name}"
    
    if [ -f "$x86_64_file" ]; then
      echo "Creating universal binary: $universal_file"
      lipo -create -output "$universal_file" "$x86_64_file" "$arm64_file"
    else
      echo "Warning: No x86_64 counterpart found for $arm64_file"
      # Copy arm64 version as fallback
      cp -v "$arm64_file" "$universal_file"
    fi
  done
  
  # Create output directory structure
  mkdir -p $out/bin
  mkdir -p $out/templates/universal
  mkdir -p $out/templates/x86_64
  mkdir -p $out/templates/arm64
  
  # Copy universal binaries to output location
  cp -v bin/universal/* $out/templates/universal/
  cp -v bin/universal/* $out/bin/
  
  # Also save the individual architecture binaries
  cp -v bin/*.macos.*.x86_64 $out/templates/x86_64/
  cp -v bin/*.macos.* $out/templates/arm64/
  
  # If we need an editor version, build it for both architectures and create universal binary
  echo "Building universal editor..."
  
  # Build editor for x86_64
  x86_64_editor_cmd="${scons}/bin/scons \
    platform=macos \
    arch=x86_64 \
    target=editor \
    ${optionsString}"
  
  echo "Running x86_64 editor build: $x86_64_editor_cmd"
  $x86_64_editor_cmd
  
  # Rename the x86_64 editor binaries temporarily
  for file in bin/*editor*; do
    mv -v "$file" "${file}.x86_64"
  done
  
  # Build editor for arm64
  arm64_editor_cmd="${scons}/bin/scons \
    platform=macos \
    arch=arm64 \
    target=editor \
    ${optionsString}"
  
  echo "Running arm64 editor build: $arm64_editor_cmd"
  $arm64_editor_cmd
  
  # Create universal editor binaries
  mkdir -p bin/universal-editor
  
  # For each arm64 editor binary, create a universal binary
  for arm64_file in bin/*editor*; do
    base_name=$(basename "$arm64_file")
    x86_64_file="bin/${base_name}.x86_64"
    universal_file="bin/universal-editor/${base_name}"
    
    if [ -f "$x86_64_file" ]; then
      echo "Creating universal editor binary: $universal_file"
      lipo -create -output "$universal_file" "$x86_64_file" "$arm64_file"
    else
      echo "Warning: No x86_64 counterpart found for $arm64_file"
      # Copy arm64 version as fallback
      cp -v "$arm64_file" "$universal_file"
    fi
  done
  
  # Copy universal editor binaries to output location
  cp -v bin/universal-editor/* $out/bin/
  
  echo "Universal macOS build completed"
else
  # Regular single-architecture build
  
  # Configure template build command
  template_build_cmd="${scons}/bin/scons \
    platform=macos \
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
  cp -v bin/*.macos.* $out/templates/${arch}/
  cp -v bin/*.macos.* $out/bin/
  
  # If we're building for an architecture that can run the editor, build it
  if [ "${arch}" = "x86_64" ] || [ "${arch}" = "arm64" ]; then
    # Build editor version
    editor_build_cmd="${scons}/bin/scons \
      platform=macos \
      arch=${arch} \
      target=editor \
      ${optionsString}"
    
    echo "Running: $editor_build_cmd"
    $editor_build_cmd
    
    # Copy editor binaries
    cp -v bin/*editor* $out/bin/
  fi
fi

# Print summary of build
echo "Build completed for macOS (${arch})"
echo "Files in template directory:"
ls -la $out/templates/${arch}/
echo "Files in bin directory:"
ls -la $out/bin/