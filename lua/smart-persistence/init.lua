-- NOTE: all this code it's based on https://github.com/folke/persistence.nvim

local M = {}

local defaults = {
    dir = vim.fn.stdpath("data") .. "/smart-persistence/",
}

local conf = {}

--- Session path according to a directory.
---@param dir string
---@return string path
local function session_path(dir)
    dir = dir:gsub("[\\/:]+", "%%")
    if vim.uv.fs_stat(".git") then
        local obj = vim.system({ "git", "branch", "--show-current" }, { text = true }):wait()
        if obj.code == 0 then
            dir = dir .. "%%" .. obj.stdout:gsub("[\\/:+", "%%")
        end
    end
    return conf.dir .. dir .. ".vim"
end

local function valid_buffers(bufs)
    return vim.tbl_filter(function(b)
        return vim.bo[b].buftype == ""
            and vim.bo[b].filetype ~= "gitcommit"
            and vim.bo[b].filetype ~= "gitrebase"
            and vim.api.nvim_buf_get_name(b) ~= ""
    end, bufs)
end

local function main()
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
