local function show_ruff_errors()
    local file = vim.fn.expand('%:p')
    if vim.bo.filetype ~= 'python' then
        vim.notify("Not a Python file", vim.log.levels.WARN)
        return
    end

    local output_lines = {}
    local job_id = vim.fn.jobstart({'ruff', 'check', file}, {
        on_stdout = function(j, d, e)
            for _, line in ipairs(d) do
                if line ~= "" then
                    table.insert(output_lines, line)
                end
            end
        end,
        on_stderr = function(j, d, e)
            for _, line in ipairs(d) do
                if line ~= "" then
                    table.insert(output_lines, line)
                end
            end
        end,
        on_exit = function(j, code, e)
            if #output_lines == 0 then
                vim.notify("No errors found", vim.log.levels.INFO)
            else
                local buf = vim.api.nvim_create_buf(false, true)
                vim.api.nvim_buf_set_lines(buf, 0, -1, false, output_lines)
                local width = 80
                local height = math.min(20, #output_lines)
                local row = math.floor((vim.o.lines - height) / 2)
                local col = math.floor((vim.o.columns - width) / 2)
                local win = vim.api.nvim_open_win(buf, true, {
                    relative = 'editor',
                    width = width,
                    height = height,
                    row = row,
                    col = col,
                    style = 'minimal',
                    border = 'single',
                })
                vim.api.nvim_buf_set_option(buf, 'modifiable', false)
                vim.api.nvim_buf_set_option(buf, 'readonly', true)
                vim.api.nvim_buf_set_keymap(buf, 'n', 'q', ':close<CR>', {noremap = true, silent = true})
                vim.api.nvim_buf_set_keymap(buf, 'n', '<Esc>', ':close<CR>', {noremap = true, silent = true})
            end
        end,
    })
    if job_id == 0 then
        vim.notify("Failed to start Ruff", vim.log.levels.ERROR)
    end
end

vim.api.nvim_create_autocmd("FileType", {
    pattern = "python",
    callback = function()
        vim.keymap.set('n', '<F5>', show_ruff_errors, { buffer = true })
    end,
})
