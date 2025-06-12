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
                table.insert(output_lines, "F -> --fix")
                vim.api.nvim_buf_set_lines(buf, 0, -1, false, output_lines)
                -- Apply syntax highlighting
                for lnum, line in ipairs(output_lines) do
                    if lnum < #output_lines then  -- Skip the UI hint line
                        local file, row, col, code, msg = string.match(line, "^(.-):(%d+):(%d+): (%w+) (.*)$")
                        if not file then
                            file, row, code, msg = string.match(line, "^(.-):(%d+): (%w+) (.*)$")
                        end
                        if file then
                            vim.api.nvim_buf_add_highlight(buf, -1, 'Directory', lnum-1, 0, #file)
                            local start_col = #file + 1
                            local end_col = start_col + #row
                            vim.api.nvim_buf_add_highlight(buf, -1, 'LineNr', lnum-1, start_col, end_col)
                            if col and col ~= "" then
                                start_col = end_col + 1
                                end_col = start_col + #col
                                vim.api.nvim_buf_add_highlight(buf, -1, 'LineNr', lnum-1, start_col, end_col)
                                start_col = end_col + 2
                            else
                                start_col = end_col + 1
                            end
                            local code_end = start_col + #code
                            vim.api.nvim_buf_add_highlight(buf, -1, 'Error', lnum-1, start_col, code_end)
                        end
                    else
                        -- Highlight the UI hint
                        vim.api.nvim_buf_add_highlight(buf, -1, 'MoreMsg', lnum-1, 0, -1)
                    end
                end
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
                vim.api.nvim_buf_set_keymap(buf, 'n', 'F', ':lua FixRuffErrors()<CR>', {noremap = true, silent = true})
                vim.api.nvim_buf_set_keymap(buf, 'n', 'q', ':close<CR>', {noremap = true, silent = true})
                vim.api.nvim_buf_set_keymap(buf, 'n', '<Esc>', ':close<CR>', {noremap = true, silent = true})
            end
        end,
    })
    if job_id == 0 then
        vim.notify("Failed to start Ruff", vim.log.levels.ERROR)
    end
end

function FixRuffErrors()
    local file = vim.fn.expand('%:p')
    vim.fn.jobstart({'ruff', 'check', '--fix', file}, {
        on_exit = function(j, code, e)
            vim.cmd('checktime')
            vim.notify("Errors fixed", vim.log.levels.INFO)
            vim.cmd('close')
        end
    })
end

local function format_ruff()
    local file = vim.fn.expand('%:p')
    if vim.bo.filetype ~= 'python' then
        vim.notify("Not a Python file", vim.log.levels.WARN)
        return
    end
    vim.fn.jobstart({'ruff', 'format', file}, {
        on_exit = function(j, code, e)
            vim.cmd('checktime')
            vim.notify("File Formatted", vim.log.levels.INFO)
        end
    })
end

vim.api.nvim_create_autocmd("FileType", {
    pattern = "python",
    callback = function()
        vim.keymap.set('n', '<F5>', show_ruff_errors, { buffer = true })
        vim.keymap.set('n', '<F7>', format_ruff, { buffer = true })
    end,
})
