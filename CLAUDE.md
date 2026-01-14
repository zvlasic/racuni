# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# Setup (install deps, assets)
mix setup

# Run dev server
mix phx.server
# or with IEx
iex -S mix phx.server

# Run tests
mix test
mix test test/path/to/test.exs           # single file
mix test test/path/to/test.exs:42        # single test at line
mix test --failed                         # re-run failed tests

# Pre-commit (run before committing)
mix precommit   # compile --warnings-as-errors, deps.unlock --unused, format, test

# Assets
mix assets.build    # build CSS/JS
mix assets.deploy   # minified build + digest
```

## Architecture

This is a Phoenix 1.8 web application using:
- **Bandit** as the HTTP server
- **Phoenix LiveView 1.1** for real-time UI
- **Tailwind CSS v4** with daisyUI plugin for styling
- **esbuild** for JavaScript bundling

### Project Structure

- `lib/racuni/` - Business logic (contexts, schemas)
- `lib/racuni_web/` - Web layer (controllers, LiveViews, components)
- `lib/racuni_web.ex` - Defines `use RacuniWeb, :controller`, `:live_view`, `:html`, etc.
- `assets/css/app.css` - Tailwind config using v4 `@import "tailwindcss"` syntax
- `assets/js/app.js` - JavaScript entry point

### Key Patterns

**LiveView templates** must wrap content with `<Layouts.app flash={@flash}>` (Layouts is auto-aliased in html_helpers).

**Forms** always use `to_form/2` in LiveView and `<.form for={@form}>` in templates. Never pass changesets directly to templates.

**Streams** for collections: use `stream/3`, `stream_insert/3`, `stream_delete/3`. Template requires `phx-update="stream"` on parent.

**Icons** use the `<.icon name="hero-x-mark" />` component from CoreComponents.

**Colocated JS hooks** use `:type={Phoenix.LiveView.ColocatedHook}` with `.` prefix names (e.g., `.MyHook`).

## Guidelines from AGENTS.md

- Use `Req` for HTTP requests (included by default), not HTTPoison/Tesla/httpc
- Never use `@apply` in CSS
- Never write inline `<script>` tags in templates
- Use `start_supervised!/1` in tests, avoid `Process.sleep/1`
- Lists don't support index access (`list[i]`), use `Enum.at/2`
- Never nest multiple modules in the same file
