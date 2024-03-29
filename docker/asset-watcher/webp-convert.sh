#!/usr/bin/env bash

echo "Converting current images to webp..";

# convert JPEG images
find $1 -type f -and \( -iname "*.jpg" -o -iname "*.jpeg" \) \
-exec bash -c '
webp_path="$0.webp";
if [ ! -f "$webp_path" ]; then 
  cwebp -quiet -q 90 "$0" -o "$webp_path";
fi;' {} \;

# convert PNG images
find $1 -type f -and -iname "*.png" \
-exec bash -c '
webp_path="$0.webp";
if [ ! -f "$webp_path" ]; then 
  cwebp -quiet -lossless "$0" -o "$webp_path";
fi;' {} \;