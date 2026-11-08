# herdr-review

A Neovim plugin to leave review notes on an agent's work and send them to a Herdr agent.

You comment lines of code in Neovim, then send every note, in one review, to an agent running in Herdr.

## Requirements

- Neovim 0.12 or later (for `vim.pack`)
- `herdr` in your `PATH`, and Neovim running in a Herdr pane, to send a review

The plugin is pure Lua: no Herdr plugin and no binary to build.

## Installation

```lua
vim.pack.add({ 'https://github.com/MatthieuELIE/herdr-review' })

local review = require('herdr_review')
review.setup()
vim.keymap.set({ 'n', 'x' }, '<leader>ac', review.comment)
vim.keymap.set('n', '<leader>as', review.send)
```

The plugin sets no mapping and no command: map `comment()` in normal and visual mode, and `send()`. `setup({ agent = 'copilot' })` picks the agent that a new Herdr tab starts, `claude` by default.

## Usage

`comment()` opens a window for a note on the cursor line, or on the selected lines. `<CR>` saves it. On a line that already has a note, `comment()` reopens it: correct the text, or empty the window to delete the note.

A note tints its lines and shows its text under them, in colors taken from your theme. It is never written to the file, and it lasts until you send it or quit Neovim.

`send()` lists the agents of your Herdr workspace, plus `New agent`. The agent you pick gets every note with its location and the quoted lines, then the focus moves to it. Each review sent is also saved under `stdpath('state')/herdr-review/`.

The colors, the review format and the error cases are in `:help herdr-review`.

## Development

```sh
nvim --headless -c "PlenaryBustedDirectory tests/ {minimal_init = 'tests/minimal_init.lua'}" -c "qa"
stylua --check .
luacheck .
VIMRUNTIME=$(nvim --clean --headless --cmd 'echo $VIMRUNTIME' --cmd q 2>&1) lua-language-server --check .
```

## License

MIT
