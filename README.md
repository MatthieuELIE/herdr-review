# herdr-review

A Neovim plugin to leave review notes on an agent's work and send them to a Herdr agent.

It is a work in progress: `setup()` is the only thing it does for now.

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

## Development

```sh
nvim --headless -c "PlenaryBustedDirectory tests/ {minimal_init = 'tests/minimal_init.lua'}" -c "qa"
stylua --check .
luacheck .
```

## License

MIT
