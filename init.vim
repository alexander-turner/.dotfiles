# Read in existing vim commands
source ~/.dotfiles/.vimrc

" Plugins will be downloaded under the specified directory.
call plug#begin(has('nvim') ? stdpath('data') . '/plugged' : '~/.vim/plugged')

" Declare the list of plugins.
Plug 'catppuccin/nvim', { 'as': 'catppuccin' }

" List ends here. Plugins become visible to Vim after this call.
call plug#end()
PlugInstall

colorscheme catppuccin-latte
