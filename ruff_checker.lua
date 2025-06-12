-- Function to fix errors with Ruff
function FixRuffErrors()
    local buf = vim.api.nvim_get_current_buf()
    local success, original_file = pcall(vim.api.nvim_buf_get_var, buf, 'original_file')
    if not success or not original_file then
        vim.notify("Original file not set", vim.log.levels.ERROR)
        return
    end

    local output_lines = {}
    vim.fn.jobstart({'ruff', 'check', '--fix', original_file}, {
        on_stdout = function(_, data)
            for _, line in ipairs(data) do
                if line ~= "" then
                    table.insert(output_lines, line)
                end
            end
        end,
        on_stderr = function(_, data)
            for _, line in ipairs(data) do
                if line ~= "" then
                    table.insert(output_lines, line)
                end
            end
        end,
        on_exit = function(_, code)
            vim.cmd('checktime')
            local summary = table.concat(output_lines, "\n")
            local fixed, remaining = summary:match("Found %d+ errors %((%d+) fixed, (%d+) remaining%)")
            if fixed and remaining then
                if tonumber(fixed) > 0 then
                    vim.notify(string.format("Fixed %s errors, %s remaining", fixed, remaining), vim.log.levels.INFO)
                else
                    vim.notify("No errors fixed, " .. remaining .. " remaining", vim.log.levels.WARN)
                end
            elseif summary:match("No fixes available") then
                vim.notify("No fixes available", vim.log.levels.WARN)
            elseif code == 0 then
                vim.notify("No errors found or no changes made", vim.log.levels.INFO)
            else
                vim.notify("Failed to fix errors: " .. summary, vim.log.levels.ERROR)
            end
            vim.cmd('close')
        end
    })
end

-- Function to show Ruff errors in a floating window
local function show_ruff_errors()
    local file = vim.fn.expand('%:p')
    if vim.bo.filetype ~= 'python' then
        vim.notify("Not a Python file", vim.log.levels.WARN)
        return
    end

    local output_lines = {}
    local job_id = vim.fn.jobstart({'ruff', 'check', file}, {
        on_stdout = function(_, data)
            for _, line in ipairs(data) do
                if line ~= "" then
                    table.insert(output_lines, line)
                end
            end
        end,
        on_stderr = function(_, data)
            for _, line in ipairs(data) do
                if line ~= "" then
                    table.insert(output_lines, line)
                end
            end
        end,
        on_exit = function(_, code)
            if #output_lines == 0 then
                vim.notify("No errors found", vim.log.levels.INFO)
            else
                local buf = vim.api.nvim_create_buf(false, true)
                vim.api.nvim_buf_set_var(buf, 'original_file', file)
                table.insert(output_lines, "F -> --fix")
                vim.api.nvim_buf_set_lines(buf, 0, -1, false, output_lines)
                -- Apply syntax highlighting
                for lnum, line in ipairs(output_lines) do
                    if lnum < #output_lines then
                        -- Match error lines like "file.py:8:9: F841 Unused variable"
                        local file_path, row, col, code, msg = string.match(line, "^(.-):(%d+):(%d+): (%w+) (.*)$")
                        if not file_path then
                            -- Fallback for lines without column numbers
                            file_path, row, code, msg = string.match(line, "^(.-):(%d+): (%w+) (.*)$")
                        end
                        if file_path then
                            vim.api.nvim_buf_add_highlight(buf, -1, 'Directory', lnum-1, 0, #file_path)
                            local start_col = #file_path + 1
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
                        else
                            -- Highlight error indicators like "  |     ^^ F841"
                            local indicator = string.match(line, "^%s+%|%s+(.*)")
                            if indicator then
                                local caret_start = string.find(line, "%^")
                                if caret_start then
                                    vim.api.nvim_buf_add_highlight(buf, -1, 'Error', lnum-1, caret_start - 1, -1)
                                end
                            end
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

-- Your fixed format_ruff function
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

-- Set up keybindings for Python files
vim.api.nvim_create_autocmd("FileType", {
    pattern = "python",
    callback = function()
        vim.keymap.set('n', '<F5>', show_ruff_errors, { buffer = true })
        vim.keymap.set('n', '<F7>', format_ruff, { buffer = true })
    end,
})-- Expose the function to be called via command or keymap
vim.api.nvim_create_user_command('RuffCheck', show_ruff_errors, {})
