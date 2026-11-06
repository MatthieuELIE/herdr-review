# herdr-review

A Neovim plugin to leave review notes on an agent's work and send them to a Herdr agent.

It is a work in progress: `setup()` and `comment()` are all it does for now.

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

`comment()` opens a floating window in insert mode, for a note on the cursor line in normal mode or on the selected lines in visual mode. Quit the window with `:q`, or `<Esc>` or `q` in normal mode, to save the note. Closing it empty saves nothing.

The plugin sets no mapping and no `:` command. Map `comment()` yourself, in both modes:

```lua
vim.keymap.set({ 'n', 'x' }, '<leader>ac', require('herdr_review').comment)
```

A note shows as a sign on each of its lines and as its text in virtual lines under the last one, in `Diagnostic` colors. It is never written to the file.

## Development

```sh
nvim --headless -c "PlenaryBustedDirectory tests/ {minimal_init = 'tests/minimal_init.lua'}" -c "qa"
stylua --check .
luacheck .
```

## License

MIT
