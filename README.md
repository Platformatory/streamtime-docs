# Streamtime Documentation

The public docs site for [Streamtime](https://streamtime.ai), built with
[Jekyll](https://jekyllrb.com/) and the
[just-the-docs](https://just-the-docs.github.io/just-the-docs/) theme,
published to GitHub Pages from `main`.

## Serve locally

```bash
scripts/serve-docs.sh            # http://127.0.0.1:4000
scripts/serve-docs.sh --regen    # livereload while editing
PORT=5000 scripts/serve-docs.sh  # other port
```

The script runs `bundle exec jekyll serve` with your local bundler when
that works, and otherwise falls back to the `ruby:3.3` image CI builds
with (Docker required for that path). The fallback exists because the
site pins just-the-docs 0.10.1 (liquid 4.0.4) and google-protobuf
3.25.8, a pair Ruby ≥ 3.4 cannot run. `--local` forbids the fallback,
`--docker` skips the probe.

Or build only:

```bash
bundle install && bundle exec jekyll build   # output in _site/
```

## Repo layout

| Path | What |
|---|---|
| `*.md`, `*/*.md` | Content. Task pages use the tabbed interface (below). |
| `architecture/` | Mermaid-based architecture page |
| `_includes/tabs.html`, `code-tabs.html`, `tabset.html` | The UI/API/CLI/MCP tab component (CSS-only, works without JS) |
| `_includes/versions.html`, `_data/versions.yml` | The version switcher in the page header |
| `scripts/version-snapshot.sh` | Registers a released docs version under `_versions/<version>/` |
| `scripts/serve-docs.sh` | Local preview (above) |
| `assets/` | Images and the component CSS/JS |

Every task page presents each task in four tabs — **UI**, **API** (HTTP,
Python, TypeScript, Go sub-tabs), **CLI**, **MCP** — with a
*Not available* panel where an interface can't do the task yet. See
`examples/tabbed-interface.md` for the component.

## Writing docs

- Verify facts against the product, not from memory: the OpenAPI snapshot
  in the SDK for API pages, the live UI for UI pages. Mark anything
  schema-derived and un-executed as such on the page.
- Diagrams are Mermaid: write a ` ```mermaid ` block on an architecture
  page; the site renders it (and nothing else pays for the library).
- No screencast videos in content: they go stale faster than text ages.
  Prefer numbered steps with screenshots.
- CI (`bundle exec jekyll build` on Ruby 3.3) must stay green.

## Release versions

Released docs versions are snapshots, served under `/<version>/` and
selected with the switcher in the page header. At release time:

```bash
scripts/version-snapshot.sh <version> <release-tag>
# review, then commit _versions/<version>/, _data/versions.yml, _config.yml
```

`latest` always means the live `main` tree.
