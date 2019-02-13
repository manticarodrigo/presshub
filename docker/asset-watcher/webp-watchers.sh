#!/usr/bin/env bash

echo "Setting up watches...";

# watch for any created, moved, or deleted image files
inotifywait -q -m -r --format '%e %w%f' -e modify -e delete $1 \
| grep -i -E '\.(jpe?g|png)$' --line-buffered \
| while read operation path; do

  echo "$operation $path";
  webp_path="$path.webp";

  if [ $operation = "DELETE" ]; then # if the file is deleted
    if [ -f "$webp_path" ]; then
      $(rm -f "$webp_path");
    fi;
  elif [ $operation = "MODIFY" ]; then  # if new file is created or modified
    if [ $(grep -i '\.png$' <<< "$path") ]; then
      $(cwebp -quiet -lossless "$path" -o "$webp_path");
    else
      $(cwebp -quiet -q 90 "$path" -o "$webp_path");
    fi;
  fi;
done;