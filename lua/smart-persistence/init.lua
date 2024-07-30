-- NOTE: all this code it's based on https://github.com/folke/persistence.nvim

local M = {}

---@class SmartPersistence.Config
---@field dir string
---@field auto_restore boolean
---@field excluded_dirs string[]?
local defaults = {
    dir = vim.fn.stdpath("data") .. "/smart-persistence/",
    auto_restore = false,
    excluded_dirs = { "~/Downloads" },
}

---@type SmartPersistence.Config
local conf

--- Session path according to a directory.
---@param dir string
---@return string path
local function session_path(dir)
    dir = dir:gsub("[\\/:]+", "%%")
    if vim.fn.isdirectory(".git") then
        local obj = vim.system({ "git", "branch", "--show-current" }, { text = true }):wait()
        local branch = vim.trim(obj.stdout)
        if obj.code == 0 and branch ~= "master" and branch ~= "main" then
            dir = dir .. "%%" .. branch:gsub("[\\/:]+", "%%")
        end
    end
    return conf.dir .. dir .. ".vim"
end

--- Filter valid buffers.
---@param bufs number[]
---@return number[] valid_bufs
local function valid_buffers(bufs)
    return vim.tbl_filter(function(b)
        return vim.bo[b].buftype == ""
            and vim.api.nvim_buf_get_name(b) ~= ""
            and not vim.tbl_contains({ "gitcommit", "gitrebase" }, vim.bo[b].filetype)
    end, bufs)
end

--- Auto restore session if conditions are met.
local function auto_restore_session()
    if not (vim.fn.argc() == 0 and conf.auto_restore) then
        return
    end
    if vim.o.filetype ~= "lazy" then
        vim.api.nvim_create_autocmd("VimEnter", {
            nested = true,
            once = true,
            callback = M.restore,
        })
        return
    end
    vim.api.nvim_create_autocmd("WinClosed", {
        pattern = tostring(vim.api.nvim_get_current_win()),
        once = true,
        callback = vim.schedule_wrap(M.restore),
    })
end

---@class SmartPersistence.subcmd
---@field impl fun()

-- https://github.com/nvim-neorocks/nvim-best-practices?tab=readme-ov-file#speaking_head-user-commands
local function set_commands()
    ---@type table<string, SmartPersistence.subcmd>
    local subcmds = {
        restore = {
            impl = M.restore,
        },
        stop = {
            impl = M.stop,
        },
    }
    local function cmd_fn(opts)
        local subcmd = subcmds[opts.fargs[1]]
        if not subcmd then
            vim.notify("SmartPersistence: Unknown command: " .. subcmd, vim.log.levels.ERROR)
            return
        end
        subcmd.impl()
    end
    vim.api.nvim_create_user_command("SmartPersistence", cmd_fn, {
        nargs = "+",
        complete = function(arglead)
            return vim.iter(vim.tbl_keys(subcmds))
                :filter(function(key)
                    return key:find(arglead) ~= nil
                end)
                :totable()
        end,
    })
end

local function set_leave_autocmd()
    vim.api.nvim_create_autocmd("VimLeavePre", {
        group = vim.api.nvim_create_augroup("smart-persistence", { clear = true }),
        callback = function()
            local cwd = vim.fn.getcwd(-1, -1)
            if vim.list_contains(conf.excluded_dirs, cwd) then
                return
            end
            local buffers = valid_buffers(vim.api.nvim_list_bufs())
            if #buffers > 0 then
                local file = session_path(cwd)
                vim.cmd("mks! " .. vim.fn.fnameescape(file))
            end
        end,
    })
end

local function init_config(opts)
    conf = vim.tbl_deep_extend("force", defaults, opts or {})
    conf.excluded_dirs = conf.excluded_dirs and vim.tbl_map(vim.fs.normalize, conf.excluded_dirs)
    vim.fn.mkdir(conf.dir, "p")
end

--- Setup the module.
---@param opts SmartPersistence.Config
function M.setup(opts)
    init_config(opts)
    auto_restore_session()
    set_commands()
    set_leave_autocmd()
end

--- Restore last session
function M.restore()
    local file = session_path(vim.fn.getcwd(-1, -1))
    if vim.fn.filereadable(file) ~= 0 then
        vim.cmd("silent so " .. vim.fn.fnameescape(file))
    end
end

--- Don't save current session
function M.stop()
    pcall(vim.api.nvim_del_augroup_by_name, "smart-persistence")
end

return M
