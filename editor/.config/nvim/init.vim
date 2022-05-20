set shell=/bin/bash
let mapleader = "\<Space>"

" =============================================================================
" # Plugins
" =============================================================================
"

call plug#begin()

" language support
Plug 'neoclide/coc.nvim', { 'branch': 'release' }
Plug 'neovim/nvim-lspconfig'
Plug 'glepnir/lspsaga.nvim', { 'branch': 'main' }
Plug 'quilt/vim-etk', { 'branch': 'main' }

" nice vim things
Plug 'junegunn/fzf', { 'dir': '~/.fzf', 'do': './install --all' }
Plug 'junegunn/fzf.vim'
Plug 'airblade/vim-rooter'
Plug 'scrooloose/nerdcommenter'
Plug 'tpope/vim-obsession'
Plug 'dhruvasagar/vim-prosession'
Plug 'tomlion/vim-solidity'

" aux
Plug 'shime/vim-livedown'
Plug 'iamcco/markdown-preview.nvim', { 'do': { -> mkdp#util#install() } }

call plug#end()

let g:coc_global_extensions = [
\ 'coc-rust-analyzer',
\ 'coc-pyright'
\ ]

" add spaces after comment delimiters by default
let g:NERDSpaceDelims = 1

" align line-wise comment delimiters flush left instead of following code indentation
let g:NERDDefaultAlign = 'left'

" livedown
let g:livedown_port = 8080

" =============================================================================
" # Editor settings
" =============================================================================
"

set encoding=utf-8
set hidden
set nowrap

" Sane splits
set splitright
set splitbelow

" Permanent undo
set undodir=~/.vimdid
set undofile

" Use wide tabs
set shiftwidth=8
set softtabstop=8
set tabstop=8
set expandtab

" Wrapping options
set formatoptions=tc " wrap text and comments using textwidth
set formatoptions+=r " continue comments when pressing ENTER in I mode
set formatoptions+=q " enable formatting of comments with gq
set formatoptions+=n " detect lists for formatting
set formatoptions+=b " auto-wrap in insert mode, and do not wrap old long lines

" Proper search
set ignorecase
set smartcase

" =============================================================================
" # GUI settings
" =============================================================================

set vb t_vb= " No more beeps
set backspace=2 " Backspace over newlines
set nofoldenable
set relativenumber " Relative line numbers
set number " Also show current absolute line
set diffopt+=iwhite " No whitespace in vimdiff
" Make diffing better: https://vimways.org/2018/the-power-of-diff/
set diffopt+=algorithm:patience
set diffopt+=indent-heuristic
set showcmd " Show (partial) command in status line.
set cmdheight=2 " More room for coc.nvim
set mouse=a " Enable mouse usage (all modes) in terminals
set shortmess+=c " don't give |ins-completion-menu| messages.
set signcolumn=number

" Having longer updatetime (default is 4000 ms = 4 s) leads to noticeable
" delays and poor user experience.
set updatetime=300

" Colors
set background=dark

" Show those damn hidden characters
" Verbose: set listchars=nbsp:¬,eol:¶,extends:»,precedes:«,trail:•
set nolist
set listchars=nbsp:¬,extends:»,precedes:«,trail:•

" =============================================================================
" # Keyboard shortcuts
" =============================================================================

" ; as :
" nnoremap ; :

imap jk <Esc>

" Ctrl+c and Ctrl+j as Esc
" inoremap <C-j> <Esc>
" vnoremap <C-j> <Esc>
" inoremap <C-c> <Esc>
" vnoremap <C-c> <Esc>

" <leader><leader> toggles between last buffer
nnoremap <leader><leader> <c-^>

" No arrow keys --- force yourself to use the home row
nnoremap <up> <nop>
nnoremap <down> <nop>
inoremap <up> <nop>
inoremap <down> <nop>
inoremap <left> <nop>
inoremap <right> <nop>

" Move by line
nnoremap j gj
nnoremap k gk

" Open hotkeys
map <C-p> :Files<CR>
nmap <leader>; :Buffers<CR>

" Trim whitespace
" nnoremap <C-w> :let _s=@/ <Bar> :%s/\s\+$//e <Bar> :let @/=_s <Bar> :nohl <Bar> :unlet _s <CR>
"
" 'Smart' nevigation
nmap <silent> E <Plug>(coc-diagnostic-prev)
nmap <silent> W <Plug>(coc-diagnostic-next)
nmap <silent> gd <Plug>(coc-definition)
nmap <silent> gy <Plug>(coc-type-definition)
nmap <silent> gi <Plug>(coc-implementation)
nmap <silent> gr <Plug>(coc-references)

try
    nmap <silent> [c :call CocAction('diagnosticNext')<cr>
    nmap <silent> ]c :call CocAction('diagnosticPrevious')<cr>
endtry

" Use K to show documentation in preview window
nnoremap <silent> K :call <SID>show_documentation()<CR>
function! s:show_documentation()
  if (index(['vim','help'], &filetype) >= 0)
    execute 'h '.expand('<cword>')
  else
    call CocAction('doHover')
  endif
endfunction

" Symbol renaming.
nmap <leader>rn <Plug>(coc-rename)

inoremap <expr> <Tab> pumvisible() ? "\<C-n>" : "\<Tab>"
inoremap <expr><S-TAB> pumvisible() ? "\<C-p>" : "\<C-h>"

" =============================================================================
" # Autocommands
" =============================================================================

autocmd FileType python setlocal expandtab shiftwidth=4 tabstop=4 smartindent autoindent foldmethod=indent foldlevel=99 cinwords=if,elif,else,for,while,try,except,finally,def,class,with
autocmd Filetype javascript setlocal ts=4 sw=4 expandtab
autocmd FileType yaml setlocal ts=2 sts=2 sw=2 foldmethod=indent expandtab
autocmd Filetype html setlocal ts=2 sw=2 expandtab
autocmd Filetype css setlocal ts=2 sw=2 expandtab
autocmd Filetype tex setlocal updatetime=1

autocmd BufWritePre *.go :silent call CocAction('runCommand', 'editor.action.organizeImport')
autocmd BufNewFile,BufRead *.md set filetype=markdown ts=4 sw=4 expandtab smarttab
