vim9 noclear

if exists('loaded') | finish | endif
var loaded = true

# Interface {{{1
def exchange#clear() #{{{2
    unlet! b:exchange
    if exists('b:exchange_matches')
        HighlightClear(b:exchange_matches)
        unlet! b:exchange_matches
    endif
enddef

def exchange#op(type = ''): string #{{{2
    if type == ''
        &opfunc = 'exchange#op'
        return 'g@'
    endif
    if !exists('b:exchange')
        b:exchange = ExchangeGet(type)
        b:exchange_matches = Highlight(b:exchange)
        # tell vim-repeat that '.' should repeat the Exchange motion
        # https://github.com/tommcdo/vim-exchange/pull/32#issuecomment-69509516
         sil! repeat#invalidate()
    else
        var exchange1: dict<any> = b:exchange
        var exchange2: dict<any> = ExchangeGet(type)
        var reverse: bool = false
        var expand: bool = false

        var cmp: string = Compare(exchange1, exchange2)
        if cmp == 'overlap'
            echohl WarningMsg
            echo 'Exchange aborted: overlapping text'
            echohl None
            exchange#clear()
            return ''
        elseif cmp == 'outer'
            [expand, reverse] = [true, true]
            [exchange1, exchange2] = [exchange2, exchange1]
        elseif cmp == 'inner'
            expand = true
        elseif cmp == 'gt'
            reverse = true
            [exchange1, exchange2] = [exchange2, exchange1]
        endif

        Exchange(exchange1, exchange2, reverse, expand)
        exchange#clear()
    endif
    return ''
enddef
#}}}1
# Core {{{1
def ApplyType(pos: dict<number>, type: string): dict<number> #{{{2
    if type == 'V'
        pos.column = col([pos.line, '$'])
    endif
    return pos
enddef

def Compare(x: dict<any>, y: dict<any>): string #{{{2
# Return < 0 if x comes before y in buffer,
#        = 0 if x and y overlap in buffer,
#        > 0 if x comes after y in buffer

    # Compare two blockwise regions.
    if x.type == "\<c-v>" && y.type == "\<c-v>"
        if Intersects(x, y)
            return 'overlap'
        endif
        var cmp: number = x.start.column - y.start.column
        return cmp <= 0 ? 'lt' : 'gt'
    endif

    # TODO: Compare a blockwise region with a linewise or characterwise region.
    # NOTE: Comparing blockwise with characterwise has one exception:
    #       When the characterwise region spans only one line, it is like blockwise.

    # Compare two linewise or characterwise regions.
    if ComparePos(x.start, y.start) <= 0 && ComparePos(x.end, y.end) >= 0
        return 'outer'
    elseif ComparePos(y.start, x.start) <= 0 && ComparePos(y.end, x.end) >= 0
        return 'inner'
    elseif (ComparePos(x.start, y.end) <= 0 && ComparePos(y.start, x.end) <= 0)
        || (ComparePos(y.start, x.end) <= 0 && ComparePos(x.start, y.end) <= 0)
        # x and y overlap in buffer.
        return 'overlap'
    endif

    var cmp: number = ComparePos(x.start, y.start)
    return cmp == 0 ? 'overlap' : cmp < 0 ? 'lt' : 'gt'
enddef

def ComparePos(x: dict<number>, y: dict<number>): number #{{{2
    if x.line == y.line
        return x.column - y.column
    else
        return x.line - y.line
    endif
enddef

def Exchange( #{{{2
    x: dict<any>,
    y: dict<any>,
    reverse: bool,
    expand: bool
    )
    var reg_z: dict<any> = SaveReg('z')
    var reg_unnamed: dict<any> = SaveReg('"')
    var sel_save: string = &sel | set sel=inclusive

    var indent: bool = x.type == 'V' && y.type == 'V'

    var xindent: string
    var yindent: string
    if indent
        xindent = nextnonblank(y.start.line)->getline()->matchstr('^\s*')
        yindent = nextnonblank(x.start.line)->getline()->matchstr('^\s*')
    endif

    var view: dict<any> = winsaveview()

    Setpos("'[", y.start)
    Setpos("']", y.end)
    setreg('z', x.reginfo)
    sil exe "norm! `[" .. y.type .. "`]\"zp"

    if !expand
        Setpos("'[", x.start)
        Setpos("']", x.end)
        setreg('z', y.reginfo)
        sil exe "norm! `[" .. x.type .. "`]\"zp"
    endif

    if indent
        var xlines: number = 1 + x.end.line - x.start.line
        var ylines: number = expand ? xlines : 1 + y.end.line - y.start.line
        if !expand
            Reindent(x.start.line, ylines, yindent)
        endif
        Reindent(y.start.line - xlines + ylines, xlines, xindent)
    endif

    winrestview(view)

    if !expand
        FixCursor(x, y, reverse)
    endif

    &sel = sel_save
    RestoreReg('z', reg_z)
    RestoreReg('"', reg_unnamed)
enddef

def ExchangeGet(arg_type: string): dict<any> #{{{2
    var reg_save: dict<any> = SaveReg('"')
    var sel_save: string = &sel | set sel=inclusive
    var type: string
    var start: dict<number>
    var end: dict<number>
    if arg_type == 'line'
        type = 'V'
        [start, end] = StorePos("'[", "']")
        sil norm! '[V']y
    elseif arg_type == 'block'
        type = "\<c-v>"
        [start, end] = StorePos("'[", "']")
        sil exe "norm! `[\<c-v>`]y"
    else
        type = 'v'
        [start, end] = StorePos("'[", "']")
        sil norm! `[v`]y
    endif
    &sel = sel_save
    var reg_yank: dict<any> = getreginfo('"')
    RestoreReg('"', reg_save)
    return {
        reginfo: reg_yank,
        type: type,
        start: start,
        end: ApplyType(end, type)
        }
enddef

def FixCursor(x: dict<any>, y: dict<any>, reverse: bool) #{{{2
    if reverse
        cursor(x.start.line, x.start.column)
    else
        if x.start.line == y.start.line
            var horizontal_offset: number = x.end.column - y.end.column
            cursor(x.start.line, x.start.column - horizontal_offset)
        elseif (x.end.line - x.start.line) != (y.end.line - y.start.line)
            var vertical_offset: number = x.end.line - y.end.line
            cursor(x.start.line - vertical_offset, x.start.column)
        endif
    endif
enddef

def Highlight(exchange: dict<any>): any #{{{2
    var regions: list<list<number>>
    if exchange.type == "\<c-v>"
        var blockstartcol: number = virtcol([
            exchange.start.line,
            exchange.start.column
            ])
        var blockendcol: number = virtcol([
            exchange.end.line,
            exchange.end.column
            ])
        if blockstartcol > blockendcol
            [blockstartcol, blockendcol] = [blockendcol, blockstartcol]
        endif
        regions += range(exchange.start.line, exchange.end.line)
            ->mapnew((_, v) => [v, blockstartcol, v, blockendcol])
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
    return mapnew(regions, (_, v) => HighlightRegion(v))
enddef

def HighlightClear(match: list<number>) #{{{2
    for m in match
         sil! matchdelete(m)
    endfor
enddef

def HighlightRegion(region: list<number>): number #{{{2
    var pat: string = '\%' .. region[0] .. 'l\%' .. region[1] .. 'v'
        .. '\_.\{-}\%' .. region[2] .. 'l\(\%>' .. region[3] .. 'v\|$\)'
    return matchadd('ExchangeRegion', pat, 0)
enddef

def Reindent(start: number, lines: number, arg_new_indent: string) #{{{2
    var new_indent: string
    if GetSetting('exchange_indent', '') == '=='
        var lnum: number = nextnonblank(start)
        if lnum == 0 || lnum > start + lines - 1
            return
        endif
        var line: string = getline(lnum)
        exe ' sil norm! ' .. lnum .. 'G=='
        new_indent = getline(lnum)->matchstr('^\s*')
        setline(lnum, line)
    else
        new_indent = arg_new_indent
    endif
    var indent: string = nextnonblank(start)->getline()->matchstr('^\s*')
    if strdisplaywidth(new_indent) > strdisplaywidth(indent)
        for lnum in range(start, start + lines - 1)
            setline(lnum, new_indent .. getline(lnum)[strlen(indent) : ])
        endfor
    elseif strdisplaywidth(new_indent) < strdisplaywidth(indent)
        var can_dedent: bool = true
        for lnum in range(start, start + lines - 1)
            if getline(lnum)->stridx(new_indent) != 0 && nextnonblank(lnum) == lnum
                can_dedent = false
            endif
        endfor
        if can_dedent
            for lnum in range(start, start + lines - 1)
                if getline(lnum)->stridx(new_indent) == 0
                    setline(lnum, new_indent .. getline(lnum)[strlen(indent) : ])
                endif
            endfor
        endif
    endif
enddef
#}}}1
# Util {{{1
def Intersects(x: dict<any>, y: dict<any>): bool #{{{2
    return x.end.column >= y.start.column && x.end.line >= y.start.line
        && x.start.column <= y.end.column && x.start.line <= y.end.line
enddef

def GetSetting(setting: string, default: string): string #{{{2
    return get(b:, setting, get(g:, setting, default))
enddef

def Getpos(mark: string): dict<number> #{{{2
    var pos: list<number> = getpos(mark)
    return {
        buffer: pos[0],
        line: pos[1],
        column: pos[2],
        offset: pos[3]
        }
enddef

def Setpos(mark: string, pos: dict<number>) #{{{2
    setpos(mark, [pos.buffer, pos.line, pos.column, pos.offset])
enddef

def SaveReg(name: string): dict<any> #{{{2
    try
        return getreginfo(name)
    catch
    endtry
    return {}
enddef

def RestoreReg(name: string, reg: dict<any>) #{{{2
     # `silent!` because of https://github.com/tommcdo/vim-exchange/issues/31
     sil! setreg(name, reg)
 enddef

def StorePos(start: string, end: string): list<dict<number>> #{{{2
    return [Getpos(start), Getpos(end)]
enddef

