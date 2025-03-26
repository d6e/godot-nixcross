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
  cp -v bin/*.windows.* $out/templates/${arch}/
  # Also rename to match Godot's template naming convention
  for file in $out/templates/${arch}/*; do
    cp -v "$file" $out/bin/
  done
elif [ "${platform}" = "macos" ]; then
  cp -v bin/*.macos.* $out/templates/${arch}/
  cp -v bin/*.macos.* $out/bin/
elif [ "${platform}" = "linuxbsd" ]; then
  cp -v bin/*.linuxbsd.* $out/templates/${arch}/
  cp -v bin/*.linuxbsd.* $out/bin/
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
      cp -v bin/*editor*.exe $out/bin/
      cp -v bin/*.dll $out/bin/ || true
    elif [ "${platform}" = "macos" ]; then
      cp -v bin/*editor* $out/bin/
    elif [ "${platform}" = "linuxbsd" ]; then
      cp -v bin/*editor* $out/bin/
    fi
  fi
fi