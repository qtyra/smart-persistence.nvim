# (WIP DON'T USE IT) smart-persistence.nvim

smart-persistence.nvim is a small neovim plugin that uses the global working directory to save sessions.

## Contents

- [Features](#features)
- [Installation](#installation)
- [Configuration](#configuration)
- [Usage](#usage)
- [Alternatives](#alternatives)

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
    -- Don't automatically save or restore a session in these directories.
    excluded_dirs = { "~/Downloads" },
    -- smart-persistence.nvim will only auto save when there is at least one
    -- 'valid buffer', check out the 'valid_buffers' function in the code to
    -- understand what that means, excludes certain filetypes for being valid,
    -- especifically those listed here.
    excluded_filetypes = { "gitcommit", "gitrebase" },
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

-- Save the current session, it won't stop `auto_save`.
vim.keymap.set("n", "<leader>qv", function() require("smart-persistence").save() end)

-- Select a session based on your cwd and git branch.
vim.keymap.set("n", "<leader>qs", function() require("smart-persistence").select() end)

-- Don't save the current session
vim.keymap.set("n", "<leader>qS", function() require("smart-persistence").stop() end)

-- Remove all associated sessions with the current directory and git branch.
vim.keymap.set("n", "<leader>qd", function() require("smart-persistence").delete() end)
```

All exported commands:

- `:SmartPersistence restore`
- `:SmartPersistence stop`
- `:SmartPersistence select`
- `:SmartPersistence delete`
- `:SmartPersistence save`

All events:

- `SmartPersistenceSavePre`
- `SmartPersistenceSavePost`
- `SmartPersistenceRestorePre`
- `SmartPersistenceRestorePost`
- `SmartPersistenceDeletePre`
- `SmartPersistenceDeletePost`

## Alternatives

- [persistence.nvim](https://github.com/folke/persistence.nvim):
    - Minimal wrapper around native vim sessions, it's your best option if you don't need all the bells and whistles of this or other plugins. The codebase is based on this plugin and i was the session plugin it was using before making my own.
    - Doesn't support auto restore, the author [is not willing to add it](https://github.com/folke/persistence.nvim/issues/21#issuecomment-1656161859)
    - Doesn't use the global working directory.

- [auto-session](https://github.com/rmagatti/auto-session):
    - Has a telescope extension, smart-persistence.nvim uses `vim.ui.select` so you can use [dressing.nvim](https://github.com/stevearc/dressing.nvim) to use telescope (or [fzf-lua](https://github.com/ibhagwan/fzf-lua) as a selector).
    - Much more customizable, more options and more mature.
    - Doesn't support multiple sessions per directory.
    - The use of the global working directory [was requested in 2022](https://github.com/rmagatti/auto-session/issues/189) but it's still open.
