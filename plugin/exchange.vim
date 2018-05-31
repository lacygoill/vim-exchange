if exists('g:loaded_exchange')
    finish
endif
let g:loaded_exchange = 1

" Commands {{{1

com! XchangeHighlightToggle call  exchange#highlight_toggle()
com! XchangeHighlightEnable call  exchange#highlight_toggle(1)
com! XchangeHighlightDisable call exchange#highlight_toggle(0)
com! XchangeClear call exchange#clear()

XchangeHighlightEnable

" Mappings {{{1

nno  <expr><silent><unique>  cx   ':<c-u>set opfunc=exchange#set<cr>'.(v:count1 == 1 ? '' : v:count1).'g@'
xno  <silent><unique>        X     :<c-u>call exchange#set(visualmode(), 1)<cr>
nno  <silent><unique>        cxc   :<c-u>call exchange#clear()<cr>
nno  <silent><unique>        cxx   :<c-u>set opfunc=exchange#set
                                   \<bar>exe 'norm! '.(v:count1 == 1 ? '' : v:count1).'g@_'<cr>
" HG {{{1

hi link ExchangeRegion Search

