let mapleader=","

"custom map"
nnoremap <Leader>rc :rightbelow vnew $MYVIMRC<CR>

" Common
set nobackup		" backup file 안만듬
set noswapfile
set wildignorecase	" Ignore the case sensitive when using tab autocompletion

" indentation
set autoindent		" 자동 들여쓰기
set smartindent 	" 스마트한 들여쓰기
set cindent			" C 프로그래밍용 자동 들여쓰기
set ruler
set number
set ignorecase		" 검색시 대소문자 무시
set cursorline

" Tab size
set ts=4
set shiftwidth=4

" encoding setting
set enc=utf8
set fileencoding=utf-8
set fencs=ucs-bom,utf-8,euc-kr,latin1 "한글 파일은 euc-kr로, 유니코드는 유니코드로

" Find /
vmap / y/<C-r>"<CR>

" indentation by tab
vmap <Tab> >gv
vmap <S-Tab> <gv

" New line
nnoremap <C-l> o<ESC>

" Disable highlighted search word.
nmap t :let @/=""<CR>

set nocompatible

