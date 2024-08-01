-- NOTE: all this code it's based on https://github.com/folke/persistence.nvim

local M = {}

---@class SmartPersistence.config
---@field dir string
---@field auto_restore boolean
---@field excluded_dirs string[]?
---@field excluded_filetypes string[]?
---@field max_sessions number
local defaults = {
    dir = vim.fn.stdpath("data") .. "/smart-persistence/",
    auto_save = true,
    auto_restore = true,
    excluded_dirs = { "~" },
    excluded_filetypes = { "gitcommit", "gitrebase" },
    max_sessions = 10,
}

---@type SmartPersistence.config
local conf

--- @return string? branch
local function get_git_branch()
    if vim.fn.isdirectory(".git") then
        local branch = vim.fn.systemlist("git branch --show-current")[1]
        return vim.v.shell_error == 0 and branch or nil
    end
end

---@return string path
local function get_session_dir()
    local cwd = vim.fn.getcwd(-1, -1)
    local dir = conf.dir .. cwd:gsub("[\\/:]+", "%%")
    local branch = get_git_branch()
    if branch and branch ~= "main" and branch ~= "master" then
        dir = dir .. "%%" .. branch:gsub("[\\/:]+", "%%")
    end
    return dir
end

---@param bufs number[]
---@return number[] valid_bufs
local function get_valid_buffers(bufs)
    return vim.tbl_filter(function(b)
        return vim.bo[b].buftype == ""
            and vim.api.nvim_buf_get_name(b) ~= ""
            and not vim.tbl_contains(conf.excluded_filetypes, vim.bo[b].filetype)
    end, bufs)
end

--- @return string[]
local function get_sessions()
    local pattern = vim.fs.joinpath(get_session_dir(), "*.vim")
    local sessions = vim.fn.glob(pattern, true, true)
    table.sort(sessions, function(a, b)
        return vim.uv.fs_stat(a).mtime.sec > vim.uv.fs_stat(b).mtime.sec
    end)
    return sessions
end

local function auto_restore_session()
    local started_with_stdin = false
    if vim.fn.argc() > 0 or vim.list_contains(conf.excluded_dirs, vim.fn.getcwd(-1, -1)) or not conf.auto_restore then
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
                    M.last()
                end
            end,
        })
    else
        vim.api.nvim_create_autocmd("WinClosed", {
            pattern = tostring(vim.api.nvim_get_current_win()),
            once = true,
            callback = vim.schedule_wrap(M.last),
        })
    end
end

local function auto_save_session()
    vim.api.nvim_create_autocmd("VimLeavePre", {
        group = vim.api.nvim_create_augroup("smart-persistence", { clear = true }),
        callback = function()
            local buffers = get_valid_buffers(vim.api.nvim_list_bufs())
            if conf.auto_save and not vim.list_contains(conf.excluded_dirs, vim.fn.getcwd(-1, -1)) and #buffers > 0 then
                M.save()
            end
        end,
    })
end

---@class SmartPersistence.subcmd
---@field impl fun()

local function setup_commands()
    ---@type table<string, SmartPersistence.subcmd>
    local subcmds = {
        last = { impl = M.last },
        stop = { impl = M.stop },
        select = { impl = M.select },
        delete = { impl = M.delete },
        save = { impl = M.save },
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

local function init_config(opts)
    conf = vim.tbl_deep_extend("force", defaults, opts or {})
    conf.excluded_dirs = conf.excluded_dirs and vim.tbl_map(vim.fs.normalize, conf.excluded_dirs)
    vim.fn.mkdir(conf.dir, "p")
end

local function restore_session(session)
    if vim.fn.filereadable(session) == 1 then
        vim.api.nvim_exec_autocmds("User", { pattern = "SmartPersistenceRestorePre", data = { session = session } })
        vim.cmd("silent so " .. vim.fn.fnameescape(session))
        vim.api.nvim_exec_autocmds("User", { pattern = "SmartPersistenceRestorePost", data = { session = session } })
    end
end

--- Setup the module.
---@param opts SmartPersistence.config
function M.setup(opts)
    init_config(opts)
    auto_restore_session()
    setup_commands()
    auto_save_session()
end

--- Restore last session
function M.last()
    restore_session(get_sessions()[1])
end

--- Select a session based on your cwd and git branch.
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
            restore_session(file)
        end
    end)
end

-- Save the current session, it won't stop `auto_save`.
function M.save()
    local dir = get_session_dir()
    local file = vim.fs.joinpath(dir, vim.fn.localtime()) .. ".vim"
    vim.api.nvim_exec_autocmds("User", { pattern = "SmartPersistenceSavePre", data = { session = file } })
    local sessions = get_sessions()
    if #sessions >= conf.max_sessions then
        vim.uv.fs_unlink(sessions[#sessions])
    end
    vim.notify(vim.inspect(dir))
    vim.notify(vim.inspect(file))
    vim.fn.mkdir(dir, "p")
    vim.cmd("mks! " .. vim.fn.fnameescape(file))
    vim.api.nvim_exec_autocmds("User", { pattern = "SmartPersistenceSavePost", data = { session = file } })
end

--- Don't save the current session.
function M.stop()
    pcall(vim.api.nvim_del_augroup_by_name, "smart-persistence")
end

--- Remove all associated sessions with the current directory and git branch.
function M.delete()
    local dir = get_session_dir()
    vim.api.nvim_exec_autocmds("User", { pattern = "SmartPersistenceDeletePre", data = { dir = dir } })
    for file in vim.fs.dir(dir) do
        vim.uv.fs_unlink(vim.fs.joinpath(dir, file))
    end
    vim.uv.fs_rmdir(dir)
    vim.api.nvim_exec_autocmds("User", { pattern = "SmartPersistenceDeletePost", data = { dir = dir } })
end

return M
