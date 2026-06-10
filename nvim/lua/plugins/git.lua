return {
  {
    "lewis6991/gitsigns.nvim",
    event = { "BufReadPre", "BufNewFile" },
    opts = {
      preview_config = {
        border = "rounded",
      },
      current_line_blame = false,
    },
    keys = {
      {
        "]h",
        function()
          require("gitsigns").nav_hunk("next")
        end,
        desc = "Next hunk",
      },
      {
        "[h",
        function()
          require("gitsigns").nav_hunk("prev")
        end,
        desc = "Previous hunk",
      },
      {
        "<leader>gp",
        function()
          require("gitsigns").preview_hunk()
        end,
        desc = "Preview hunk",
      },
      {
        "<leader>gr",
        function()
          require("gitsigns").reset_hunk()
        end,
        desc = "Reset hunk",
      },
      {
        "<leader>gs",
        function()
          require("gitsigns").stage_hunk()
        end,
        desc = "Stage hunk",
      },
      {
        "<leader>gb",
        function()
          require("gitsigns").blame_line({ full = true })
        end,
        desc = "Blame line",
      },
    },
  },
  {
    "sindrets/diffview.nvim",
    cmd = {
      "DiffviewOpen",
      "DiffviewClose",
      "DiffviewFileHistory",
      "DiffviewFocusFiles",
      "DiffviewToggleFiles",
    },
    dependencies = { "nvim-lua/plenary.nvim" },
    keys = {
      { "<leader>do", "<cmd>DiffviewOpen<CR>", desc = "Working tree diff" },
      { "<leader>dc", "<cmd>DiffviewClose<CR>", desc = "Close diff view" },
      { "<leader>df", "<cmd>DiffviewToggleFiles<CR>", desc = "Toggle changed files panel" },
      { "<leader>dv", "<cmd>DiffviewFocusFiles<CR>", desc = "Focus changed files panel" },
      { "<leader>dh", "<cmd>DiffviewFileHistory %<CR>", desc = "Current file history" },
      { "<leader>dH", "<cmd>DiffviewFileHistory<CR>", desc = "Repo history" },
    },
    opts = {
      enhanced_diff_hl = true,
      use_icons = true,
      view = {
        default = {
          layout = "diff2_horizontal",
          winbar_info = false,
        },
        file_history = {
          layout = "diff2_horizontal",
          winbar_info = false,
        },
        merge_tool = {
          layout = "diff3_horizontal",
        },
      },
      file_panel = {
        listing_style = "tree",
        win_config = {
          position = "left",
          width = 28,
        },
      },
      file_history_panel = {
        win_config = {
          position = "bottom",
          height = 18,
        },
      },
    },
  },
  {
    "NeogitOrg/neogit",
    cmd = { "Neogit" },
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-tree/nvim-web-devicons",
      "sindrets/diffview.nvim",
    },
    keys = {
      {
        "<leader>gg",
        function()
          require("neogit").open({ kind = "tab" })
        end,
        desc = "Git status",
      },
    },
    opts = {
      integrations = {
        diffview = true,
      },
      graph_style = "ascii",
    },
  },
}
