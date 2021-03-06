vim9script noclear

if exists('loaded') | finish | endif
var loaded = true

# FIXME: Sometimes, the plugin fails to exchange to 2 sections separated by a "rule" in a markdown file.{{{
#
# Write this in a markdown file
#
#     aaa
#
#         bbb
#
#     ---
#
#         ccc
#
#     ddddd
#
# Press `cxi-` while on `aaa`, then press `cxi-` while on `ddddd`.
# You get this text, which is wrong (the underscores stand for spaces):
#
#     ccc
#
#     d
#     ---
#         aaa
#     ____
#             bbb
#     ____
#
# Notice how:
#
#    - `aaa`, `bbb`, and the empty lines below them have all been wrongly indented
#    - `aaa` is right below the rule (there should be an empty line between them)
#    - `ddddd` has been truncated to `d`
#}}}
# FIXME:{{{
#
#     $ vim -S <(cat <<'EOF'
#         vim9script
#     var lines =<< END
#       aaa
#     + bbb
#       ccc
#     + ddd
#     END
#         lines->setline(1)
#         feedkeys('cxj2j.')
#     EOF
#     )
#
# Expected:
#
#       ccc
#     + ddd
#       aaa
#     + bbb
#
# Actual:
#
#     ccc
#     ddd
#     aaa
#     bbb
#}}}

# Mappings {{{1

nnoremap <expr><unique> cx exchange#op()
nnoremap <expr><unique> cxx exchange#op() .. '_'
xnoremap <expr><unique> X exchange#op()

nnoremap <unique> cxc <Cmd>call exchange#clear()<CR>

# HG {{{1

# `:def` is  necessary for  the highlighting  to persist  across changes  of the
# color scheme
highlight default link ExchangeRegion Search
