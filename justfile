version new:
  #!/usr/bin/env bash
  current=$(perl -lne 'print for /\.version.*\=.*"(.*)"/' build.zig.zon)
  find -type f \
       -not -path './.*' \
       -exec perl -i -pe "s/\Q${current}/{{new}}/g" {} \;

  git commit -am "chore(release): v{{new}}"
  git tag "v{{new}}"
