local opt = vim.opt

opt.number = true
opt.relativenumber = false
opt.tabstop = 2
opt.shiftwidth = 2
opt.expandtab = true
opt.wrap = false
opt.linebreak = true
opt.termguicolors = true
opt.cursorline = true
opt.signcolumn = "yes"
opt.scrolloff = 6
opt.swapfile = false
opt.undofile = true
opt.hlsearch = true
opt.ignorecase = true
opt.smartcase = true
opt.updatetime = 200
opt.timeoutlen = 300
opt.splitright = true
opt.splitbelow = true
opt.cmdheight = 0
opt.mouse = "a"
opt.background = "dark"
opt.wildmenu = true
opt.wildmode = "longest:full,full"
opt.confirm = true
opt.spelllang = { "en_us" }

opt.diffopt:append("algorithm:histogram")
opt.diffopt:append("linematch:60")
opt.diffopt:append("vertical")

vim.cmd.colorscheme("catppuccin")

vim.schedule(function()
  opt.clipboard = "unnamedplus"
end)
