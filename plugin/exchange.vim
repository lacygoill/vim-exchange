if exists('g:loaded_exchange')
    finish
endif
let g:loaded_exchange = 1

" FIXME: Sometimes, the plugin fails to exchange to 2 sections separated by a "rule" in a markdown file.{{{
"
" Write this in a markdown file
"
"     aaa
"
"         bbb
"
"     ---
"
"         ccc
"
"     ddddd
"
" Press `cxi-` while on `aaa`, then press `cxi-` while on `ddddd`.
" You get this text, which is wrong (the underscores stand for spaces):
"
"     ccc
"
"     d
"     ---
"         aaa
"     ____
"             bbb
"     ____
"
" Notice how:
"
"    - `aaa`, `bbb`, and the empty lines below them have all been wrongly indented
"    - `aaa` is right below the rule (there should be an empty line between them)
"    - `ddddd` has been truncated to `d`
"}}}

" Mappings {{{1

nno <expr><silent><unique> cx  ':<c-u>set opfunc=exchange#set<cr>'..(v:count1 == 1 ? '' : v:count1)..'g@'
xno <silent><unique>       X    :<c-u>call exchange#set(visualmode(), 1)<cr>
nno <silent><unique>       cxc  :<c-u>call exchange#clear()<cr>
nno <silent><unique>       cxx  :<c-u>set opfunc=exchange#set
                                \<bar>exe 'norm! '..(v:count1 == 1 ? '' : v:count1)..'g@_'<cr>

" HG {{{1

hi link ExchangeRegion Search
