# herdr-review

A Neovim plugin to leave review notes on an agent's work and send them to a Herdr agent.

It is a work in progress: `setup()`, `comment()` and `send()` are all it does for now.

## Requirements

- Neovim 0.12 or later (for `vim.pack`)

The plugin is pure Lua: no Herdr plugin and no binary to build.

## Installation

```lua
vim.pack.add({ 'https://github.com/MatthieuELIE/herdr-review' })

require('herdr_review').setup()
```

## Setup

`setup()` takes an optional table.

```lua
require('herdr_review').setup({ agent = 'copilot' })
```

| Option  | Default    | Description                    |
| ------- | ---------- | ------------------------------ |
| `agent` | `"claude"` | The agent launched for a review |

## Leaving a review note

`comment()` opens a floating window in insert mode, for a note on the cursor line in normal mode or on the selected lines in visual mode. Press `<CR>` to save the note and close the window, in insert or normal mode; `<S-CR>` or `<C-j>` breaks the line. Quitting the window with `:q`, or `<Esc>` or `q` in normal mode, saves the note too. Closing it empty saves nothing.

The plugin sets no mapping and no `:` command. Map `comment()` yourself, in both modes:

```lua
vim.keymap.set({ 'n', 'x' }, '<leader>ac', require('herdr_review').comment)
```

A note colors the number of each of its lines and shows its text in virtual lines under the last one, in `Diagnostic` colors. It puts no sign, so the signs of a diff plugin stay visible. It is never written to the file.

## Sending the review

`send()` lists the agents of the Herdr workspace of your nvim through `vim.ui.select`, each as `<tab label> (<status>)`, then `New agent` last. Name your Herdr tabs to tell your agents apart: two tabs with the same label give the same entry. `New agent` starts the `agent` of `setup()` in a new tab at the repo root, both named `review-<HHMMSS>`. Pick an agent to send it the review, then focus moves to that agent and the notes disappear from every buffer. Cancelling the list, or an error (agent blocked, `herdr` missing, nvim outside Herdr), keeps the notes.

```lua
vim.keymap.set('n', '<leader>as', require('herdr_review').send)
```

The review starts with the repo and branch, then gives each note as `path:line` or `path:start-end` (relative to the repo root, absolute outside a git repo) with the selected lines and your comment, and ends with "Fix each point. Do not commit."

Each review sent is saved as `stdpath('state')/herdr-review/<repo>/<YYYY-MM-DD-HHMMSS>.md`, where `<repo>` is the name of the repo root, or of the working directory outside a git repo. A review that is not sent is not saved. If the file cannot be written, an error is shown, and the agent still has the review.

## Development

```sh
nvim --headless -c "PlenaryBustedDirectory tests/ {minimal_init = 'tests/minimal_init.lua'}" -c "qa"
stylua --check .
luacheck .
VIMRUNTIME=$(nvim --clean --headless --cmd 'echo $VIMRUNTIME' --cmd q 2>&1) lua-language-server --check .
```

## License

MIT
