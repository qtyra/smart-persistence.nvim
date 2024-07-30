-- NOTE: all this code it's based on https://github.com/folke/persistence.nvim

local M = {}

---@class SmartPersistence.Config
---@field dir string
---@field auto_restore boolean
---@field excluded_dirs string[]?
---@field max_sessions number
local defaults = {
    dir = vim.fn.stdpath("data") .. "/smart-persistence/",
    auto_restore = false,
    excluded_dirs = { "~/Downloads" },
    max_sessions = 10,
}

---@type SmartPersistence.Config
local conf

--- Builds the session dir respecting git branches
---@return string path
local function get_session_dir()
    local cwd = vim.fn.getcwd(-1, -1)
    local dir = conf.dir .. cwd:gsub("[\\/:]+", "%%")
    if vim.fn.isdirectory(".git") then
        local obj = vim.system({ "git", "branch", "--show-current" }, { text = true }):wait()
        local branch = vim.trim(obj.stdout)
        if obj.code == 0 and branch ~= "master" and branch ~= "main" then
            dir = dir .. "%%" .. branch:gsub("[\\/:]+", "%%")
        end
    end
    vim.fn.mkdir(dir, "p")
    return dir
end

local function get_session_file(file)
    return vim.fs.joinpath(get_session_dir(), file) .. ".vim"
end

--- Filter valid buffers.
---@param bufs number[]
---@return number[] valid_bufs
local function get_valid_buffers(bufs)
    return vim.tbl_filter(function(b)
        return vim.bo[b].buftype == ""
            and vim.api.nvim_buf_get_name(b) ~= ""
            and not vim.tbl_contains({ "gitcommit", "gitrebase" }, vim.bo[b].filetype)
    end, bufs)
end

--- Sessions in the current directory
--- @return string[]
local function get_sessions()
    local sessions = vim.fn.glob(get_session_file("*"), true, true)
    table.sort(sessions, function(a, b)
        return vim.uv.fs_stat(a).mtime.sec > vim.uv.fs_stat(b).mtime.sec
    end)
    return sessions
end

--- Auto restore session if conditions are met.
local function auto_restore_session()
    local started_with_stdin = false
    if not (vim.fn.argc() == 0 and conf.auto_restore) then
        return
    end
    vim.api.nvim_create_autocmd({ "StdinReadPre" }, {
        once = true,
        callback = function()
            started_with_stdin = true
        end,
    })
    if vim.o.filetype ~= "lazy" then
        vim.api.nvim_create_autocmd("VimEnter", {
            nested = true,
            once = true,
            callback = function()
                if not started_with_stdin then
                    M.restore()
                end
            end,
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
local function setup_commands()
    ---@type table<string, SmartPersistence.subcmd>
    local subcmds = {
        restore = {
            impl = M.restore,
        },
        stop = {
            impl = M.stop,
        },
        select = {
            impl = M.select,
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

local function save_at_exit()
    vim.api.nvim_create_autocmd("VimLeavePre", {
        group = vim.api.nvim_create_augroup("smart-persistence", { clear = true }),
        callback = function()
            if vim.list_contains(conf.excluded_dirs, vim.fn.getcwd(-1, -1)) then
                return
            end
            local sessions = get_sessions()
            if #sessions >= conf.max_sessions then
                vim.uv.fs_unlink(sessions[#sessions])
            end
            local buffers = get_valid_buffers(vim.api.nvim_list_bufs())
            if #buffers > 0 then
                local file = get_session_file(vim.fn.localtime())
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
    setup_commands()
    save_at_exit()
end

--- Restore last session
function M.restore()
    local file = get_sessions()[1]
    if vim.fn.filereadable(file) ~= 0 then
        vim.cmd("silent so " .. vim.fn.fnameescape(file))
    end
end

--- Select a session from the cwd
function M.select()
    local sessions = get_sessions()
    vim.ui.select(sessions, {
        prompt = "Select a session: ",
        format_item = function(item)
            local date = vim.fs.basename(item):match("%d+")
            return vim.fn.strftime("%d-%m-%Y %H:%M:%S", date)
        end,
    }, function(file)
        if file then
            vim.cmd("%bd!")
            vim.cmd("silent so " .. vim.fn.fnameescape(file))
        end
    end)
end

--- Don't save current session
function M.stop()
    pcall(vim.api.nvim_del_augroup_by_name, "smart-persistence")
end

return M
