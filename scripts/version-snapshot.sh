#!/usr/bin/env bash
# Release-time documentation version snapshot.
#
#   scripts/version-snapshot.sh <version> [source-ref]
#
# Builds _versions/<version>/ for a release line:
#
#   1. copies every content page (all *.md) from the source tree —
#      main's working tree by default, or `source-ref` (a tag or
#      commit) when given;
#   2. rewrites each page so it:
#        * hides from the sidebar and the search index
#          (nav_exclude: true, search_exclude: true),
#        * links site assets under /<version>/... (the script rewrites
#          root-relative asset paths), so a snapshot page never loads
#          the latest tree's images or videos,
#        * carries version_snapshot: <version> in its front matter,
#          which the version switcher reads to mark the active entry;
#   3. appends the version to _data/versions.yml (the switcher's list).
#
# "latest" is never snapshotted: it is what the main tree serves at /.
# Commit the generated _versions/<version>/ tree and the data file
# together. The Pages and CI builds need no changes: Jekyll picks the
# pages up as ordinary pages at /<version>/....

set -euo pipefail
cd "$(dirname "$0")/.."

usage() {
  echo "usage: $(basename "$0") <version> [source-ref]"
  echo "       e.g. $(basename "$0") 1.2          # snapshot today's pages"
  echo "       e.g. $(basename "$0") 1.2 v1.2.0   # snapshot a release tag"
  exit 2
}

version="${1:-}"; shift || true
[ -n "$version" ] || usage
[ "$version" = "latest" ] && usage
ref="${1:-}"; [ $# -eq 0 ] || [ -n "$ref" ] || usage

[ -f _config.yml ] || { echo "run from the docs repo root" >&2; exit 1; }
git rev-parse --git-dir >/dev/null 2>&1 || { echo "not a git repo" >&2; exit 1; }
if [ -n "$ref" ]; then
  git rev-parse --verify --quiet "${ref}^{commit}" >/dev/null || { echo "no such ref: $ref" >&2; exit 1; }
fi

dest="_versions/$version"
[ -e "$dest" ] && { echo "$dest already exists; remove it first to re-snapshot" >&2; exit 1; }
mkdir -p "$dest"

if [ -n "$ref" ]; then
  pages="$(git ls-tree -r --name-only "$ref" -- . | grep '\.md$')"
else
  pages="$(find . -name '*.md' \
    -not -path './_site/*' -not -path './_versions/*' -not -path './vendor/*' \
    -not -path './.bundle/*' -not -path '*/_versions/*' \
    -not -path '*/.*' | sed 's|^\./||' | sort)"
fi
[ -n "$pages" ] || { echo "no content pages found" >&2; exit 1; }
page_count="$(printf '%s\n' "$pages" | wc -l | tr -d ' ')"

for path in $pages; do
  dir="$(dirname "$path")"; [ "$dir" = "." ] && dir="" || dir="$dir/"
  if [ -n "$ref" ]; then
    body="$(git show "$ref:$path")"
  else
    body="$(cat "$path")"
  fi
  # Title: the source front matter's title, else the file name. An
  # assignment is always "true" in bash, so test the value, not the
  # assignment.
  fm_title="$(printf '%s\n' "$body" | awk '/^---$/{n++; next} n==1 && /^title:/{print; exit}' | sed -E 's/^title:[[:space:]]*"?//; s/"[[:space:]]*$//')"
  if [ -n "$fm_title" ]; then
    title="$fm_title"
  else
    title="$(basename "$path" .md | tr '-' ' ' | awk '{ $1=toupper(substr($1,1,1)) substr($1,2); for(i=2;i<=NF;i++) $i=toupper(substr($i,1,1)) substr($i,2)}1')"
  fi
  # Drop the source front matter, keep the body.
  content="$(printf '%s\n' "$body" | awk 'BEGIN{fm=0} /^---$/ && fm<2 {fm++; next} fm==2 {print}')"
  # Assets: point root-relative asset paths at this snapshot's URL
  # space (relative paths and relative_url links stay as they are).
  content="$(printf '%s\n' "$content" | sed -E "s#(src|href)=\"/(assets/[^\"]+)\"#\1=\"/$version/\2\"#g")"
  mkdir -p "$dest/$(dirname "$path")"
  {
    printf -- '---\n'
    printf 'title: "%s"\n' "$title"
    # URL-space the snapshot: its own permalinks keep pages from
    # colliding with (and being overwritten by) the live tree.
    slug="$(basename "$path" .md)"
    if [ "$slug" = "index" ]; then perm="/$version/$dir"; else perm="/$version/$dir$slug/"; fi
    printf 'permalink: "%s"\n' "$perm"
    printf 'nav_exclude: true\nsearch_exclude: true\n'
    printf 'version_snapshot: "%s"\n' "$version"
    printf -- '---\n\n'
    printf '%s\n' "$content"
  } > "$dest/$path"
done

# Register the version in _data/versions.yml (appends the entry with
# its fields indented under the list; comments kept).
data=_data/versions.yml
mkdir -p "$(dirname "$data")"
touch "$data"
if grep -Eq "^  - version: \"?${version}\"?$" "$data"; then
  echo "$data already lists $version; leaving it as is"
else
  printf '  - version: "%s"\n    snapshot_date: %s\n    notes: []\n' "$version" "$(date +%F)" >> "$data"
fi

# Register in _config.yml's include list (Jekyll ignores underscore
# directories otherwise). The list must name every directory that
# contains pages, so we write the version's page directories.
if [ -z "$ref" ] || true; then
  python3 - "$version" <<'PY'
import re, sys
version = sys.argv[1]
src = open("_config.yml").read()
import subprocess
dirs = subprocess.run(["find", f"_versions/{version}", "-type", "d"],
                      capture_output=True, text=True).stdout.split()
entries = "\n".join(f"  - {d}/" for d in sorted(dirs))
m = re.search(r"^include:[ \t]*\[\][ \t]*\n", src, re.M)
if m:
    src = src[:m.start()] + "include:\n" + entries + "\n" + src[m.end():]
else:
    # Replace an existing block-style include list with the merged one.
    def merge(match):
        existing = re.findall(r"^  - (.*)$", match.group(0), re.M)
        merged = sorted({e.strip().strip("/") + "/" for e in existing} | {d + "/" for d in dirs})
        return "include:\n" + "\n".join(f"  - {e}" for e in merged) + "\n"
    src = re.sub(r"^include:\n(?:  - .*\n)+", merge, src, count=1, flags=re.M)
    if "include:" not in src:
        src += "\n# Jekyll ignores underscore-prefixed directories; the version-snapshot\n# script keeps every snapshot directory listed here so its pages build.\ninclude:\n" + entries + "\n"
open("_config.yml", "w").write(src)
PY
fi

echo "snapshotted ${page_count} pages into $dest (version $version)"
echo "review, then: git add $dest $data _config.yml && git commit"
