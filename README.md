# (WIP DON'T USE IT) smart-persistence.nvim

smart-persistence.nvim is a small neovim plugin that uses the global working directory to save sessions.

## Contents

- [Features](#features)
- [Installation](#installation)
- [Configuration](#configuration)
- [Usage](#usage)
- [Acknowledgements](#acknowledgements)
- [Other plugins](#other-plugins)

## Features

- Sessions are loaded and saved based on the global working directory instead of the window/tab one.
- Different sessions are saved based on the git branch.
- Multiple sessions per directory and git branch.
- Support auto session restore

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
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
    -- Don't automatically restore the session
    auto_restore = false,
    -- Don't automatically save session in these directories
    excluded_dirs = { "~/Downloads" },
    -- Maximum number of sessions stored per cwd and git branch.
    max_sessions = 10,
})
```

## Usage

My recommended workflow is to have a dashboard plugin like dashboard [dashboard.nvim](https://github.com/nvimdev/dashboard-nvim) or [alpha-nvim](https://github.com/goolord/alpha-nvim) and adding a one-key map to open the last session. Example with dashboard.nvim:

```lua
require("dashboard").setup({
    config = {
        center = {
            {
                action = 'lua require("smart-persistence").restore()',
                desc = " Restore Session",
                icon = " ",
                key = "s",
            },
            -- other entries...
        },
    },
}
```

All exported functions:

```lua
-- Restore last session, set `auto_restore` to automatically call this function at startup.
vim.keymap.set("n", "<leader>qr", function() require("smart-persistence").restore() end)

-- Don't auto save the this session. Alternatively, set a list of directories in `excluded_dirs`.
vim.keymap.set("n", "<leader>qs", function() require("smart-persistence").stop() end)

-- Select a session based on your cwd and git branch.
vim.keymap.set("n", "<leader>qs", function() require("smart-persistence").select() end)
```

All exported commands:

- `:SmartPersistence restore`
- `:SmartPersistence stop`
- `:SmartPersistence select`

## Acknowledgements

The code is based on [persistence.nvim](https://github.com/folke/persistence.nvim). It was the auto-session plugin I used before making my own.

## Other plugins

- [auto-session](https://github.com/rmagatti/auto-session): The use of the global working directory [was requested in 2022](https://github.com/rmagatti/auto-session/issues/189) but is still open.
