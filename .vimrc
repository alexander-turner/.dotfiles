" An example for a vimrc file.
"
" Maintainer:	Bram Moolenaar <Bram@vim.org>
" Last change:	2019 Jan 26
"
" To use it, copy it to
"     for Unix and OS/2:  ~/.vimrc
"	      for Amiga:  s:.vimrc
"  for MS-DOS and Win32:  $VIM\_vimrc
"	    for OpenVMS:  sys$login:.vimrc

" When started as "evim", evim.vim will already have done these settings, bail
" out.
if v:progname =~? "evim"
  finish
endif

" Get the defaults that most users want.
" source /usr/share/vim/vim90/defaults.vim

if has("vms")
  set nobackup		" do not keep a backup file, use versions instead
else
  set backup		" keep a backup file (restore to previous version)
  if has('persistent_undo')
    set undofile	" keep an undo file (undo changes after closing)
  endif
endif

if &t_Co > 2 || has("gui_running")
  " Switch on highlighting the last used search pattern.
  set hlsearch
endif

" Put these in an autocmd group, so that we can delete them easily.
augroup vimrcEx
  au!

  " For all text files set 'textwidth' to 78 characters.
  " autocmd FileType text setlocal textwidth=78
augroup END                                  

" Add optional packages.
"                                                           
" The matchit plugin makes the % command work better, but it is not backwards
" compatible.
" The ! means the package won't be loaded right away but when plugins are
" loaded during initialization.
if has('syntax') && has('eval')
  packadd! matchit            

endif

set number
set nocompatible
set hidden
set mouse=a
set tabstop=4

" Set up keybindings
nnoremap <F9> :!%:p<Enter>

" #### LEADER COMMANDS ####
" NORMAL MODE
" nnoremap <leader>f :HopWord<CR>
" nnoremap <leader>q :bdelete<CR>
"
" " open config file for filetype
" nnoremap <leader>c :e ~/.config/nvim/ftplugin/<C-R>=&filetype<CR>.vim<CR>
"
" " Copy whole file
" nnoremap <leader>y
"
" " VISUAL MODE
" " in visual mode, select a word
" " h: replace all with prompt // H: replace all without prompt
" vnoremap <leader>h "hy:%s/<C-r>h//gc<left><left><left>
" vnoremap <leader>H "hy:%s/<C-r>h//g<left><left>
"
" " sort selected lines
" vnoremap <leader>s :sort<CR>
"
" " copy selected text to clipboard
" vnoremap <leader>y "+y

" Fix issue where visual mode highlighting was invisible
set nocompatible
if (has("termguicolors"))
  set termguicolors
endif
syntax enable

" Set the width of a tab character
set tabstop=4

" Control the number of spaces for autoindent
set shiftwidth=4

" Convert tabs to spaces
set expandtab

" Enable smart/auto indentation
set smartindent
" Alternatively, you can use:
" set autoindent

" Enable file-type specific indentation
filetype plugin indent on

" Set soft tabstop
set softtabstop=4

" Copy the indentation from the previous line
set copyindent

" Preserve as much of the indent structure as possible
set preserveindent

" Custom indentation rules for specific file types
autocmd FileType python setlocal shiftwidth=4 tabstop=4 expandtab
autocmd FileType html setlocal shiftwidth=2 tabstop=2 expandtab

" SPLIT MANAGEMENT
" Easier split navigations
nnoremap <C-J> <C-W><C-J>
nnoremap <C-K> <C-W><C-K>
nnoremap <C-L> <C-W><C-L>
nnoremap <C-H> <C-W><C-H>

" More natural split opening
set splitbelow
set splitright

"Max out the height of the current split
ctrl + w _

"Max out the width of the current split
ctrl + w |

"Normalize all split sizes, which is very handy when resizing terminal
ctrl + w =
  
