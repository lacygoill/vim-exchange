if exists('g:loaded_exchange')
    finish
endif
let g:loaded_exchange = 1

" FIXME: Consider these 2 paragraphs{{{
"
"          ┌ load the script only if it makes sense
"          │
"          ├───────────────────────────┐
"       if stridx(&rtp, 'vim-...') == -1
"           finish
"       endif
"
"       if !exists(g:loaded_...)
"           finish
"       endif
"
" Uncomment them, and try to exchange their position by pressing `cxip` on both.
" One of them is mangled.
" I think it's due to the multi-byte characters used in the diagram.
"}}}

" Mappings {{{1

nno  <expr><silent><unique>  cx   ':<c-u>set opfunc=exchange#set<cr>'.(v:count1 == 1 ? '' : v:count1).'g@'
xno  <silent><unique>        X     :<c-u>call exchange#set(visualmode(), 1)<cr>
nno  <silent><unique>        cxc   :<c-u>call exchange#clear()<cr>
nno  <silent><unique>        cxx   :<c-u>set opfunc=exchange#set
                                   \<bar>exe 'norm! '.(v:count1 == 1 ? '' : v:count1).'g@_'<cr>

" HG {{{1

hi link ExchangeRegion Search
