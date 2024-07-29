-- NOTE: all this code it's based on https://github.com/folke/persistence.nvim

local M = {}

---@class SmartPersistence.Config
---@field dir string
---@field auto_restore boolean
local defaults = {
    dir = vim.fn.stdpath("data") .. "/smart-persistence/",
    auto_restore = false,
}

---@type SmartPersistence.Config
local conf

--- Session path according to a directory.
---@param dir string
---@return string path
local function session_path(dir)
    dir = dir:gsub("[\\/:]+", "%%")
    if vim.uv.fs_stat(".git") then
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
            and vim.bo[b].filetype ~= "gitcommit"
            and vim.bo[b].filetype ~= "gitrebase"
            and vim.api.nvim_buf_get_name(b) ~= ""
    end, bufs)
end

local function main()
    if vim.fn.argc() == 0 and conf.auto_restore then
        M.restore()
    end
    vim.api.nvim_create_autocmd("VimLeavePre", {
        group = vim.api.nvim_create_augroup("smart-persistence", { clear = true }),
        callback = function()
            local buffers = valid_buffers(vim.api.nvim_list_bufs())
            if #buffers > 0 then
                local file = vim.fn.fnameescape(session_path(vim.fn.getcwd(-1, -1)))
                vim.cmd("mks! " .. file)
            end
        end,
    })
end

--- Setup the module.
---@param opts SmartPersistence.Config
function M.setup(opts)
    conf = vim.tbl_deep_extend("force", defaults, opts or {})
    vim.fn.mkdir(conf.dir, "p")
    main()
end

--- Restore last session
function M.restore()
    local file = session_path(vim.fn.getcwd(-1, -1))
    if vim.uv.fs_stat(file) then
        vim.cmd("silent! so " .. vim.fn.fnameescape(file))
    end
end

return M
