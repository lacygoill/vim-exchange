" Interface {{{1
fu exchange#clear() abort "{{{2
    unlet! b:exchange
    if exists('b:exchange_matches')
        call s:highlight_clear(b:exchange_matches)
        unlet! b:exchange_matches
    endif
endfu

fu exchange#op(...) abort "{{{2
    if !a:0
        let &opfunc = 'exchange#op'
        return 'g@'
    endif
    let type = a:1
    if !exists('b:exchange')
        let b:exchange = s:exchange_get(type)
        let b:exchange_matches = s:Highlight(b:exchange)
        " tell vim-repeat that '.' should repeat the Exchange motion
        " https://github.com/tommcdo/vim-exchange/pull/32#issuecomment-69509516
         sil! call repeat#invalidate()
    else
        let exchange1 = b:exchange
        let exchange2 = s:exchange_get(type)
        let reverse = 0
        let expand = 0

        let cmp = s:compare(exchange1, exchange2)
        if cmp == 'overlap'
            echohl WarningMsg | echo 'Exchange aborted: overlapping text' | echohl None
            return exchange#clear()
        elseif cmp == 'outer'
            let [expand, reverse] = [1, 1]
            let [exchange1, exchange2] = [exchange2, exchange1]
        elseif cmp == 'inner'
            let expand = 1
        elseif cmp == 'gt'
            let reverse = 1
            let [exchange1, exchange2] = [exchange2, exchange1]
        endif

        call s:exchange(exchange1, exchange2, reverse, expand)
        call exchange#clear()
    endif
endfu
"}}}1
" Core {{{1
fu s:apply_type(pos, type) abort "{{{2
    let pos = a:pos
    if a:type is# 'V'
        let pos.column = col([pos.line, '$'])
    endif
    return pos
endfu

fu s:compare(x, y) abort "{{{2
" Return < 0 if x comes before y in buffer,
"        = 0 if x and y overlap in buffer,
"        > 0 if x comes after y in buffer

    " Compare two blockwise regions.
    if a:x.type == "\<c-v>" && a:y.type == "\<c-v>"
        if s:intersects(a:x, a:y)
            return 'overlap'
        endif
        let cmp = a:x.start.column - a:y.start.column
        return cmp <= 0 ? 'lt' : 'gt'
    endif

    " TODO: Compare a blockwise region with a linewise or characterwise region.
    " NOTE: Comparing blockwise with characterwise has one exception:
    "       When the characterwise region spans only one line, it is like blockwise.

    " Compare two linewise or characterwise regions.
    if s:compare_pos(a:x.start, a:y.start) <= 0 && s:compare_pos(a:x.end, a:y.end) >= 0
        return 'outer'
    elseif s:compare_pos(a:y.start, a:x.start) <= 0 && s:compare_pos(a:y.end, a:x.end) >= 0
        return 'inner'
    elseif (s:compare_pos(a:x.start, a:y.end) <= 0 && s:compare_pos(a:y.start, a:x.end) <= 0)
      \ || (s:compare_pos(a:y.start, a:x.end) <= 0 && s:compare_pos(a:x.start, a:y.end) <= 0)
        " x and y overlap in buffer.
        return 'overlap'
    endif

    let cmp = s:compare_pos(a:x.start, a:y.start)
    return cmp == 0 ? 'overlap' : cmp < 0 ? 'lt' : 'gt'
endfu

fu s:compare_pos(x, y) abort "{{{2
    if a:x.line == a:y.line
        return a:x.column - a:y.column
    else
        return a:x.line - a:y.line
    endif
endfu

fu s:exchange(x, y, reverse, expand) abort "{{{2
    let reg_z = s:save_reg('z')
    let reg_unnamed = s:save_reg('"')
    let sel_save = &sel | set sel=inclusive

    " Compare using =~ because "'==' != 0" returns 0
    let indent = s:get_setting('exchange_indent', 1) !~ 0 && a:x.type is# 'V' && a:y.type is# 'V'

    if indent
        let xindent = nextnonblank(a:y.start.line)->getline()->matchstr('^\s*')
        let yindent = nextnonblank(a:x.start.line)->getline()->matchstr('^\s*')
    endif

    let view = winsaveview()

    call s:setpos("'[", a:y.start)
    call s:setpos("']", a:y.end)
    call setreg('z', a:x.reginfo)
    sil exe "norm! `[" .. a:y.type .. "`]\"zp"

    if !a:expand
        call s:setpos("'[", a:x.start)
        call s:setpos("']", a:x.end)
        call setreg('z', a:y.reginfo)
        sil exe "norm! `[" .. a:x.type .. "`]\"zp"
    endif

    if indent
        let xlines = 1 + a:x.end.line - a:x.start.line
        let ylines = a:expand ? xlines : 1 + a:y.end.line - a:y.start.line
        if !a:expand
            call s:reindent(a:x.start.line, ylines, yindent)
        endif
        call s:reindent(a:y.start.line - xlines + ylines, xlines, xindent)
    endif

    call winrestview(view)

    if !a:expand
        call s:fix_cursor(a:x, a:y, a:reverse)
    endif

    let &sel = sel_save
    call s:restore_reg('z', reg_z)
    call s:restore_reg('"', reg_unnamed)
endfu

fu s:exchange_get(type) abort "{{{2
    let reg_save = s:save_reg('"')
    let sel_save = &sel | set sel=inclusive
    if a:type == 'line'
        let type = 'V'
        let [start, end] = s:store_pos("'[", "']")
         sil norm! '[V']y
    elseif a:type == 'block'
        let type = "\<c-v>"
        let [start, end] = s:store_pos("'[", "']")
         sil exe "norm! `[\<c-v>`]y"
    else
        let type = 'v'
        let [start, end] = s:store_pos("'[", "']")
         sil norm! `[v`]y
    endif
    let &sel = sel_save
    let reg_yank = getreginfo('"')
    call s:restore_reg('"', reg_save)
    return {
        \ 'reginfo': reg_yank,
        \ 'type': type,
        \ 'start': start,
        \ 'end': s:apply_type(end, type)
        \ }
endfu

fu s:fix_cursor(x, y, reverse) abort "{{{2
    if a:reverse
        call cursor(a:x.start.line, a:x.start.column)
    else
        if a:x.start.line == a:y.start.line
            let horizontal_offset = a:x.end.column - a:y.end.column
            call cursor(a:x.start.line, a:x.start.column - horizontal_offset)
        elseif (a:x.end.line - a:x.start.line) != (a:y.end.line - a:y.start.line)
            let vertical_offset = a:x.end.line - a:y.end.line
            call cursor(a:x.start.line - vertical_offset, a:x.start.column)
        endif
    endif
endfu

def s:Highlight(exchange: dict<any>): any #{{{2
    var regions: list<list<number>> = []
    if exchange.type == "\<c-v>"
        var blockstartcol = virtcol([exchange.start.line, exchange.start.column])
        var blockendcol = virtcol([exchange.end.line, exchange.end.column])
        if blockstartcol > blockendcol
            [blockstartcol, blockendcol] = [blockendcol, blockstartcol]
        endif
        regions += range(exchange.start.line, exchange.end.line)
            ->map({_, v -> [v, blockstartcol, v, blockendcol]})
    else
        var startline: number
        var endline: number
        [startline, endline] = [exchange.start.line, exchange.end.line]
        var startcol: number
        var endcol: number
        if exchange.type == 'v'
            startcol = virtcol([exchange.start.line, exchange.start.column])
            endcol = virtcol([exchange.end.line, exchange.end.column])
        elseif exchange.type == 'V'
            startcol = 1
            endcol = virtcol([exchange.end.line, '$'])
        endif
        regions += [[startline, startcol, endline, endcol]]
    endif
    return map(regions, {_, v -> Highlight_region(v)})
enddef

fu s:highlight_clear(match) abort "{{{2
    for m in a:match
         sil! call matchdelete(m)
    endfor
endfu

fu s:Highlight_region(region) abort "{{{2
    let pat = '\%' .. a:region[0] .. 'l\%' .. a:region[1] .. 'v\_.\{-}\%' .. a:region[2] .. 'l\(\%>' .. a:region[3] .. 'v\|$\)'
    return matchadd('ExchangeRegion', pat, 0)
endfu

fu s:reindent(start, lines, new_indent) abort "{{{2
    if s:get_setting('exchange_indent', 1) == '=='
        let lnum = nextnonblank(a:start)
        if lnum == 0 || lnum > a:start + a:lines - 1
            return
        endif
        let line = getline(lnum)
        exe " sil norm! " .. lnum .. "G=="
        let new_indent = getline(lnum)->matchstr('^\s*')
        call setline(lnum, line)
    else
        let new_indent = a:new_indent
    endif
    let indent = nextnonblank(a:start)->getline()->matchstr('^\s*')
    if strdisplaywidth(new_indent) > strdisplaywidth(indent)
        for lnum in range(a:start, a:start + a:lines - 1)
            if lnum =~ '\S'
                call setline(lnum, new_indent .. getline(lnum)[strlen(indent):])
            endif
        endfor
    elseif strdisplaywidth(new_indent) < strdisplaywidth(indent)
        let can_dedent = 1
        for lnum in range(a:start, a:start + a:lines - 1)
            if getline(lnum)->stridx(new_indent) != 0 && nextnonblank(lnum) == lnum
                let can_dedent = 0
            endif
        endfor
        if can_dedent
            for lnum in range(a:start, a:start + a:lines - 1)
                if getline(lnum)->stridx(new_indent) == 0
                    call setline(lnum, new_indent .. getline(lnum)[strlen(indent):])
                endif
            endfor
        endif
    endif
endfu
"}}}1
" Util {{{1
fu s:intersects(x, y) abort "{{{2
    return a:x.end.column >= a:y.start.column && a:x.end.line >= a:y.start.line
        \ && a:x.start.column <= a:y.end.column && a:x.start.line <= a:y.end.line
endfu

fu s:get_setting(setting, default) abort "{{{2
    return get(b:, a:setting, get(g:, a:setting, a:default))
endfu

fu s:getpos(mark) abort "{{{2
    let pos = getpos(a:mark)
    let result = {}
    return {
        \ 'buffer': pos[0],
        \ 'line': pos[1],
        \ 'column': pos[2],
        \ 'offset': pos[3]
        \ }
endfu

fu s:setpos(mark, pos) abort "{{{2
    call setpos(a:mark, [a:pos.buffer, a:pos.line, a:pos.column, a:pos.offset])
endfu

fu s:save_reg(name) abort "{{{2
    try
        return getreginfo(a:name)
    catch
        return ['', '']
    endtry
endfu

fu s:restore_reg(name, reg) abort "{{{2
     " `silent!` because of https://github.com/tommcdo/vim-exchange/issues/31
     sil! call setreg(a:name, a:reg)
endfu

fu s:store_pos(start, end) abort "{{{2
    return [s:getpos(a:start), s:getpos(a:end)]
endfu

