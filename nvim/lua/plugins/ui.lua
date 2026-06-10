return {
  {
    "nvim-mini/mini.nvim",
    lazy = false,
    config = function()
      local starter = require("mini.starter")

      starter.setup({
        autoopen = true,
        evaluate_single = false,
        header = table.concat({
          "Neovim review workspace",
          "",
          "Markdown plans • Changed files • Git review",
        }, "\n"),
        items = {
          {
            name = "Working tree diff",
            action = "DiffviewOpen",
            section = "Review",
          },
          {
            name = "Repo commit history",
            action = "DiffviewFileHistory",
            section = "Review",
          },
          {
            name = "Open git status",
            action = function()
              require("neogit").open({ kind = "tab" })
            end,
            section = "Review",
          },
          {
            name = "Find markdown plans",
            action = function()
              require("telescope.builtin").find_files({
                hidden = true,
                find_command = { "rg", "--files", "-g", "*.md" },
              })
            end,
            section = "Markdown",
          },
          starter.sections.recent_files(5, true, true),
          {
            name = "Browse files",
            action = "NvimTreeToggle",
            section = "General",
          },
          {
            name = "Quit Neovim",
            action = "qall",
            section = "General",
          },
        },
        content_hooks = {
          starter.gen_hook.adding_bullet(),
          starter.gen_hook.aligning("center", "center"),
        },
        footer = "Use query or arrows + Enter",
      })
    end,
  },
  {
    "nvim-lualine/lualine.nvim",
    event = "VeryLazy",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = {
      options = {
        theme = "auto",
        globalstatus = true,
        section_separators = "",
        component_separators = "|",
      },
      sections = {
        lualine_c = {
          {
            "filename",
            path = 1,
          },
        },
        lualine_x = { "diff", "branch", "filetype" },
      },
    },
  },
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {
      spec = {
        { "<leader>d", group = "diff" },
        { "<leader>f", group = "find" },
        { "<leader>g", group = "git" },
        { "<leader>m", group = "markdown" },
        { "<leader>s", group = "start" },
        { "<leader>t", group = "terminal" },
      },
    },
    keys = {
      {
        "<leader>?",
        function()
          require("which-key").show({ global = false })
        end,
        desc = "Buffer local keymaps",
      },
    },
  },
}
