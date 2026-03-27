return {
  "LazyVim/LazyVim",
  keys = {
    {
      "<leader>yy",
      function()
        local start_line = vim.fn.line("v")
        local end_line = vim.fn.line(".")
        if start_line > end_line then
          start_line, end_line = end_line, start_line
        end

        local lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)
        local file = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":~:.")
        local ext = vim.fn.fnamemodify(file, ":e")

        local numbered = {}
        for i, line in ipairs(lines) do
          table.insert(numbered, string.format("%d | %s", start_line + i - 1, line))
        end

        local result =
          string.format("# %s:%d-%d\n```%s\n%s\n```", file, start_line, end_line, ext, table.concat(numbered, "\n"))

        vim.fn.setreg("+", result)
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", false)
        vim.notify("Copied with path and line numbers", vim.log.levels.INFO)
      end,
      mode = "x",
      desc = "Copy code with file path and line numbers",
    },
  },
}
