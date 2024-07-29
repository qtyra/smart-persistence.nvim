# (WIP DON'T USE IT) smart-persistence.nvim

smart-persistence.nvim is a tiny lua plugin that uses the global working directory to save sessions.

## Contents

- [Rationale](#rationale)
- [Features](#features)
- [Installation](#installation)
- [Configuration](#configuration)
- [Usage](#usage)
- [Acknowledgements](#acknowledgements)
- [Other plugins](#other-plugins)

## Rationale

**There are a lot of auto-session plugins, why another one, how is this different?**

Currently most auto-session plugins (or at least the ones i've tried) use the window/tab local directory (`vim.fn.getcwd()` or `vim.uv.cwd()`) **before exiting** Neovim as the session filename. To illustrate why this can be problematic, consider this case:

1. Open Neovim from /foo, example: `nvim test.txt`
2. Open a new tab with `:tabnew` and change the directory with `:tcd bar` to /foo/bar
3. Close neovim with `:xa`, the directory returned by `vim.fn.getcwd()` and `vim.uv.cwd()` will be /foo/bar.
4. The auto-session plugin will save the session as something like `$SESSIONDIR/%foo%bar.vim`.
5. Open Neovim again, The behavior here may differ between plugins but two possible outcomes are:
    - An old session is restored.
    - No session is restored.

Both because the directory was saved with an tab/window local directory. Note that you may need to open some files to replicate this case.

**Why would you want tabs with different directories? Are you trying to use tabs as workspaces?**

While you can recreate workspaces (different projects) with tabs and `:tcd`, it's often more convenient to just open a new neovim instance. My use case (and likely that of anyone who is insterested in this plugin) is related but slightly different:

1. I have a directory and a project under that directory, let's say /foo and /foo/project. /foo contains valuable information like books, notes and related projects. I want to share buffers and modify content from both /foo and /fooproject without constantly switching between two OS windows.
2. Fuzzy finders like [fzf-lua](https://github.com/ibhagwan/fzf-lua) or [telescope](https://github.com/nvim-telescope/telescope.nvim) use the current working directory to search for files or to call grep, plugins like [neogit](https://github.com/NeogitOrg/neogit) expect a .git directory, which may not exist in /foo or its parent directory.

The best approach to my workflow I've come up with is to use `:tcd`, but as I mentioned earlier, auto-session plugins don't work correctly with this setup, leading me to write this plugin.

**How do you track the global working directory?**

Just use `vim.fn.getcwd(-1, -1)` instead of `vim.fn.getcwd()`. Another solution, which I used in the very first implementation of this plugin, is to set an autocommand for `DirChanged` to track directory changes made by `:cd` while ignoring `:tcd` and `:lcd`.

## Features
- Session's associated directory is based in the global working directory instead of the window/tab one.
- TODO: Respect git branches.
- TODO: Support auto restore.

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
-- lazy.nvim
{
    "qtyra/smart-persistence.nvim",
    opts = {}
},
```

## Configuration

```lua
-- default settings, no need to copy
require("smart-persistence").setup({
    -- Where to save the sessions
    dir = vim.fn.stdpath("data") .. "/smart-persistence/",
})
```

## Usage

My recommended workflow is to have a dashboard plugin like dashboard [dashboard.nvim](https://github.com/nvimdev/dashboard-nvim) or [alpha-nvim](https://github.com/goolord/alpha-nvim) and add a one-key option to open the last session.

Alternatively, you can set a keymap like this:

```lua
vim.keymap.set("n", "<leader>q", require("smart-persistence").restore)
```

or with lazy.nvim:

```lua
{
    "qtyra/smart-persistence.nvim",
    -- ...
    keys = {
        { "<leader>q", function() require("smart-persistence").restore() end },
    }
}
```

## Acknowledgements

The code is based on [persistence.nvim](https://github.com/folke/persistence.nvim) if not outright copied. It was the auto-session plugin I used before making my own.

## Other plugins

- [auto-session](https://github.com/rmagatti/auto-session): The use of the global working directory [was requested in 2022](https://github.com/rmagatti/auto-session/issues/189) but is still open.
