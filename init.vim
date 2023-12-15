" Read in existing vim commands
source ~/.dotfiles/.vimrc

" Plugins will be downloaded under the specified directory.
call plug#begin(has('nvim') ? stdpath('data') . '/plugged' : '~/.vim/plugged')

" Declare the list of plugins.
Plug 'catppuccin/nvim', { 'as': 'catppuccin' }
Plug 'tpope/vim-commentary'
" Plug 'nvim-treesitter/nvim-treesitter', {'do': ':TSUpdate'}

" List ends here. Plugins become visible to Vim after this call.
call plug#end()

colorscheme catppuccin-latte

" Hotkeys for commenting out current line
nnoremap <C-/> :Commentary<CR>
vnoremap <C-/> :Commentary<CR>

" Enable highlighting 
" lua << EOF
" require'nvim-treesitter.configs'.setup{
"  highlight =  {
"    enable = true,
"  },
"}
"EOF
