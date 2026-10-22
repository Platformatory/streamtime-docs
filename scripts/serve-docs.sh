#!/usr/bin/env bash
# Serve the docs site locally at http://127.0.0.1:4000 (Ctrl-C to stop).
#
#   scripts/serve-docs.sh            # serve the working tree
#   scripts/serve-docs.sh --regen    # livereload while editing
#   scripts/serve-docs.sh --docker   # skip the probe, use the CI image
#   scripts/serve-docs.sh --local    # never fall back to Docker
#   PORT=5000 scripts/serve-docs.sh  # other port
#
# Why the fallback: the site pins just-the-docs 0.10.1 (liquid 4.0.4) and
# google-protobuf 3.25.8. Ruby >= 3.4 cannot run that pair (bigdecimal is
# gone from core; no protobuf binary exists), while CI builds on Ruby 3.3.
# So this script tries bundler locally, and falls back to the same
# ruby:3.3 image CI uses. Either path ends in `bundle exec jekyll serve`.

set -euo pipefail
cd "$(dirname "$0")/.."

port="${PORT:-4000}"
regen=0
force=""
while [ $# -gt 0 ]; do
  case "$1" in
    --regen) regen=1 ;;
    --docker) force=docker ;;
    --local) force=local ;;
    -h|--help) sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
  shift
done

# A local bundle is only usable if the site actually builds: `jekyll
# --version` succeeds even when native gems (google-protobuf on Ruby
# >= 3.4) can't load. Probe with a real build into a throwaway dir.
local_ok() {
  env RUBYOPT="${RUBYOPT:--rbigdecimal}" \
    bundle exec jekyll build --quiet --destination _site-probe >/dev/null 2>&1
}
if [ "$force" != docker ]; then
  if local_ok; then
    rm -rf _site-probe
    echo "serving with local bundler at http://127.0.0.1:${port}"
    serve_args=(bundle exec jekyll serve --host 127.0.0.1 --port "$port")
    [ "$regen" -eq 1 ] && serve_args+=(--livereload)
    exec env RUBYOPT="${RUBYOPT:--rbigdecimal}" "${serve_args[@]}"
  fi
  rm -rf _site-probe
  [ "$force" = local ] && { echo "local bundle failed the build probe" >&2; exit 1; }
  echo "local bundle can't build this site (Ruby >= 3.4 vs the pinned"
  echo "theme); falling back to the CI image."
fi

command -v docker >/dev/null || { echo "docker is required for --docker (or the fallback)" >&2; exit 1; }
echo "serving with the CI image (ruby:3.3) at http://127.0.0.1:${port}"
# Livereload inside a container needs its own published port; plain serve
# needs none beyond the site port.
if [ "$regen" -eq 1 ]; then
  inner="bundle exec jekyll serve --host 0.0.0.0 --port ${port} --livereload --livereload-port 35729"
  extra="-p 35729:35729"
else
  inner="bundle exec jekyll serve --host 0.0.0.0 --port ${port}"
  extra=""
fi
# shellcheck disable=SC2086
docker run --rm -p "${port}:${port}" ${extra} -v "$PWD":/src -w /src ruby:3.3 \
  sh -c "gem install bundler -v 2.5.23 >/dev/null 2>&1; \
         bundle config set --local path vendor/bundle >/dev/null; \
         bundle install >/dev/null 2>&1; \
         trap 'rm -rf /src/vendor /src/.bundle' EXIT; \
         ${inner}"
