-- =====================================================================
-- Neovim Configuration - Minimal & Optimized for Code Reading
-- Languages: Go, Python, SQL, Shell Script
-- =====================================================================

vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

-- Essential settings
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.tabstop = 2
vim.opt.shiftwidth = 2
vim.opt.expandtab = true
vim.opt.wrap = false
vim.opt.termguicolors = true
vim.opt.cursorline = true
vim.opt.signcolumn = "yes"
vim.opt.scrolloff = 10
vim.opt.swapfile = false
vim.opt.undofile = true
vim.opt.hlsearch = true
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.updatetime = 250
vim.opt.timeoutlen = 300
vim.opt.splitright = true
vim.opt.splitbelow = true
vim.opt.cmdheight = 0
vim.opt.mouse = 'a'
vim.opt.background = "dark"
vim.opt.wildmenu = true
vim.opt.wildmode = 'longest:full,full'

-- Clipboard integration
vim.schedule(function() vim.opt.clipboard = 'unnamedplus' end)

-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  vim.fn.system({ 'git', 'clone', '--filter=blob:none', '--branch=stable',
    'https://github.com/folke/lazy.nvim.git', lazypath })
end
vim.opt.rtp:prepend(lazypath)

-- Plugin Setup (Minimal Configuration)
require("lazy").setup({

  -- Color Scheme
 {
  'catppuccin/nvim',
  name = 'catppuccin',
  priority = 1000,
  config = function()
    require('catppuccin').setup({
      flavour = 'mocha', -- Options: latte, frappe, macchiato, mocha
      transparent_background = false,
      term_colors = true,
      styles = {
        comments = { 'italic' },
        keywords = { 'italic' },
        functions = {},
        variables = {},
      },
      integrations = {
        treesitter = true,
        native_lsp = {
          enabled = true,
          virtual_text = {
            errors = { 'italic' },
            hints  = { 'italic' },
            warnings = { 'italic' },
            information = { 'italic' },
            },
            underlines = {
              errors = { 'underline' },
              hints  = { 'underline' },
              warnings = { 'underline' },
              information = { 'underline' },
            },
          },
        },
      })

      vim.cmd.colorscheme('catppuccin')
    end,
  },

  -- File Explorer
  {
    "nvim-tree/nvim-tree.lua",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    cmd = { "NvimTreeToggle", "NvimTreeFocus" },
    keys = {
      { "<leader>e", "<cmd>NvimTreeToggle<cr>", desc = "File Tree" },
      { "<C-b>", "<cmd>NvimTreeToggle<cr>", desc = "File Tree" },
    },
    opts = {
      view = { width = 35 },
      renderer = { group_empty = true },
      filters = { dotfiles = false },
      git = { enable = true },
    },
  },

  -- Fuzzy Finder
  {
    "nvim-telescope/telescope.nvim",
    cmd = "Telescope",
    keys = {
      { "<C-p>", "<cmd>Telescope find_files<cr>", desc = "Find Files" },
      { "<leader>ff", "<cmd>Telescope find_files<cr>", desc = "Find Files" },
      { "<leader>fg", "<cmd>Telescope live_grep<cr>", desc = "Live Grep" },
      { "<leader>fb", "<cmd>Telescope buffers<cr>", desc = "Buffers" },
      { "<leader>fw", "<cmd>Telescope grep_string<cr>", desc = "Find Word" },
    },
    dependencies = {
      "nvim-lua/plenary.nvim",
      { "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
    },
    config = function()
      require('telescope').setup({
        extensions = { fzf = { fuzzy = true, override_generic_sorter = true } }
      })
      pcall(require('telescope').load_extension, 'fzf')
    end,
  },

  -- Git Review
  {
    'lewis6991/gitsigns.nvim',
    event = { 'BufReadPre', 'BufNewFile' },
    opts = {},
    keys = {
      { ']h', '<cmd>Gitsigns next_hunk<CR>', desc = 'Next hunk' },
      { '[h', '<cmd>Gitsigns prev_hunk<CR>', desc = 'Previous hunk' },
      { '<leader>gp', '<cmd>Gitsigns preview_hunk<CR>', desc = 'Preview hunk' },
      { '<leader>gs', '<cmd>Gitsigns stage_hunk<CR>', desc = 'Stage hunk' },
      { '<leader>gb', '<cmd>Gitsigns blame_line<CR>', desc = 'Blame line' },
    },
  },
  {
    'sindrets/diffview.nvim',
    cmd = { 'DiffviewOpen', 'DiffviewFileHistory' },
    dependencies = { 'nvim-lua/plenary.nvim' },
    keys = {
      { '<leader>go', '<cmd>DiffviewOpen main...HEAD<CR>', desc = 'Open branch diff' },
      { '<leader>gh', '<cmd>DiffviewFileHistory %<CR>', desc = 'File history' },
    },
  },

  -- LSP
  {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = {
      { 'mason-org/mason.nvim', config = true },
      'mason-org/mason-lspconfig.nvim',
      'WhoIsSethDaniel/mason-tool-installer.nvim',
      'saghen/blink.cmp',
    },
    config = function()
      vim.api.nvim_create_autocmd('LspAttach', {
        callback = function(event)
          local map = function(keys, func, desc)
            vim.keymap.set('n', keys, func, { buffer = event.buf, desc = 'LSP: ' .. desc })
          end
          map('gd', require('telescope.builtin').lsp_definitions, 'Go to Definition')
          map('gr', require('telescope.builtin').lsp_references, 'References')
          map('gi', require('telescope.builtin').lsp_implementations, 'Implementation')
          map('K', vim.lsp.buf.hover, 'Hover')
          map('<F2>', vim.lsp.buf.rename, 'Rename')
          map('<leader>.', vim.lsp.buf.code_action, 'Code Action')
          map('<leader>f', function() vim.lsp.buf.format({ async = true }) end, 'Format')
        end,
      })

      local capabilities = require('blink.cmp').get_lsp_capabilities()

      require('mason-tool-installer').setup({
        ensure_installed = {
          'gopls', 'pyright', 'ts_ls', 'sqlls', 'bashls',
          'gofumpt', 'black', 'isort', 'shfmt'
        }
      })

      require('mason-lspconfig').setup({
        handlers = {
          function(server_name)
            require('lspconfig')[server_name].setup({ capabilities = capabilities })
          end,
        },
      })
    end,
  },

  -- Auto-formatting
  {
    'stevearc/conform.nvim',
    event = { 'BufWritePre' },
    opts = {
      format_on_save = { timeout_ms = 500, lsp_format = 'fallback' },
      formatters_by_ft = {
        go = { 'gofumpt' },
        python = { 'isort', 'black' },
        sql = { 'sqlfluff' },
        sh = { 'shfmt' },
        bash = { 'shfmt' },
      },
    },
  },

  -- Autocompletion
  {
    'saghen/blink.cmp',
    version = '1.*',
    event = "InsertEnter",
    opts = {
      keymap = {
        preset = 'default',
        ['<CR>'] = { 'accept', 'fallback' },
      },
      appearance = { nerd_font_variant = 'mono' },
      completion = { documentation = { auto_show = true } },
      sources = { default = { 'lsp', 'path', 'buffer' } },
    },
  },

  -- Syntax Highlighting
{
  "nvim-treesitter/nvim-treesitter",
  build = ":TSUpdate",
  branch = "main",
  lazy = false,
  config = function()
    require('nvim-treesitter').setup()

    -- Install parsers (replaces ensure_installed)
    require('nvim-treesitter').install({
      'go', 'python', 'javascript', 'typescript', 'tsx',
      'sql', 'bash', 'lua', 'markdown', 'markdown_inline'
    })

    -- Enable highlighting and indentation
    vim.api.nvim_create_autocmd('FileType', {
      callback = function()
        pcall(vim.treesitter.start)
        vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
      end,
    })
  end,
},

  -- Terminal
  {
    "akinsho/toggleterm.nvim",
    keys = {
      { "<C-\\>", "<cmd>ToggleTerm<cr>", desc = "Terminal", mode = {"n", "t"} },
      { "<leader>t", "<cmd>ToggleTerm<cr>", desc = "Terminal" },
    },
    opts = {
      size = 15,
      open_mapping = [[<C-\>]],
      direction = "horizontal",
    }
  },

  -- Indent Guides
  {
    "lukas-reineke/indent-blankline.nvim",
    event = { "BufReadPost", "BufNewFile" },
    main = "ibl",
    opts = {
      indent = { char = "│" },
      scope = { enabled = false },
    },
  },

  -- Commenting
  {
    'numToStr/Comment.nvim',
    keys = {
      { "gc", mode = { "n", "v" }, desc = "Comment toggle linewise" },
      { "gb", mode = { "n", "v" }, desc = "Comment toggle blockwise" },
    },
    opts = {},
  },

  -- Status Line
  {
    "nvim-lualine/lualine.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    event = "VeryLazy",
    opts = {
      options = {
        theme = "auto",
        globalstatus = true,
        section_separators = '',
        component_separators = '|',
      },
    }
  },

  -- GitHub Copilot
  {
    'github/copilot.vim',
    event = "InsertEnter",
  },
  {
    'CopilotC-Nvim/CopilotChat.nvim',
    dependencies = { 'nvim-lua/plenary.nvim' },
    cmd = { "CopilotChat", "CopilotChatToggle", "CopilotChatExplain", "CopilotChatFix", "CopilotChatOptimize" },
    keys = {
      { "<leader>a", "<cmd>CopilotChatToggle<cr>", desc = "AI Chat", mode = {"n", "v"} },
      { "<leader>ai", mode = {"n", "v"}, desc = "AI Inline Chat" },
      { "<leader>ae", "<cmd>CopilotChatExplain<cr>", desc = "AI Explain", mode = "v" },
      { "<leader>af", "<cmd>CopilotChatFix<cr>", desc = "AI Fix", mode = "v" },
      { "<leader>ao", "<cmd>CopilotChatOptimize<cr>", desc = "AI Optimize", mode = "v" },
    },
    opts = {
      window = { layout = 'float', width = 0.8, height = 0.8 },
    },
  },

 -- markdown Rendering
  {
    'MeanderingProgrammer/render-markdown.nvim',
    dependencies = { 'nvim-treesitter/nvim-treesitter', 'nvim-mini/mini.nvim' },
    ---@module 'render-markdown'
    ---@type render.md.UserConfig
    opts = {},
  },

  -- which-key for Buffer Local Keymaps
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    keys = {
      {
        "<leader>?",
        function()
          require("which-key").show({ global = false })
        end,
        desc = "Buffer Local Keymaps (which-key)",
      },
    },
  },

})

-- Essential Keybindings
local map = vim.keymap.set

-- File operations
map('n', '<Esc>', '<cmd>nohlsearch<CR>')
map('n', '<leader>w', '<cmd>w<CR>', { desc = 'Save' })
map('n', '<leader>q', '<cmd>q<CR>', { desc = 'Quit' })

-- Navigation
map('n', '<C-h>', '<C-w>h', { desc = 'Left window' })
map('n', '<C-j>', '<C-w>j', { desc = 'Down window' })
map('n', '<C-k>', '<C-w>k', { desc = 'Up window' })
map('n', '<C-l>', '<C-w>l', { desc = 'Right window' })
map('n', '<Tab>', '<cmd>bnext<CR>', { desc = 'Next buffer' })
map('n', '<S-Tab>', '<cmd>bprevious<CR>', { desc = 'Previous buffer' })

-- Navigate back/forward (VSCode-style Ctrl+- and Ctrl+Shift+-)
vim.keymap.set("n", "<C-_>", "<C-o>", { desc = "Jump back (Ctrl+-)" })
vim.keymap.set("n", "<C-+>", "<C-i>", { desc = "Jump forward (Ctrl+Shift+-)" })

-- Copilot Chat inline
map({'n', 'v'}, '<leader>ai', function()
  vim.ui.input({ prompt = 'Ask Copilot: ' }, function(input)
    if input then vim.cmd('CopilotChat ' .. input) end
  end)
end, { desc = 'AI Inline Chat' })

-- Terminal
map('t', '<Esc><Esc>', '<C-\\><C-n>', { desc = 'Exit terminal mode' })

-- Diagnostics
map('n', '[d', vim.diagnostic.goto_prev, { desc = 'Previous diagnostic' })
map('n', ']d', vim.diagnostic.goto_next, { desc = 'Next diagnostic' })
map('n', '<leader>d', vim.diagnostic.open_float, { desc = 'Show diagnostic' })

-- Review
map('n', '<leader>md', '<cmd>RenderMarkdown toggle<CR>', { desc = 'Toggle markdown render' })

-- Autocommands
vim.api.nvim_create_autocmd('TextYankPost', {
  callback = function() vim.hl.on_yank() end,
})

vim.api.nvim_create_autocmd('FileType', {
  pattern = { 'go', 'python' },
  callback = function()
    vim.opt_local.tabstop = 4
    vim.opt_local.shiftwidth = 4
  end,
})

