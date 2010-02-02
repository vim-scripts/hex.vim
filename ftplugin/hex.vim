" Vim filetype plugin file
" Language:    Intel .hex files
" Maintainer:  Stefan Liebl
"
" Features:    Display hex-address in statusline
"              :HexGotoAddress
"              :HexStatusLineOff
"
" Source:      included in http://code.google.com/p/vimsuite

" Only do this when not done yet for this buffer
if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1


" Parse Intel Hex Line into Dictionary
function! s:HexParseLine(line)
    let Pattern = '^:\(..\)\(....\)\(..\)\(.*\)\(..\)$'
    let Length   = substitute(a:line, Pattern, '\1', '')
    let Address  = substitute(a:line, Pattern, '\2', '')
    let Type     = substitute(a:line, Pattern, '\3', '')
    let Data     = substitute(a:line, Pattern, '\4', '')
    let Checksum = substitute(a:line, Pattern, '\5', '')
    let LineDict = {
                \'Length': Length,
                \'Address': Address,
                \'Type': Type,
                \'Data': Data,
                \'Checksum': Checksum,
                \}
    return LineDict
endfunction

" Get number of current byte of data
function! s:HexGetDataByte()
    let Pos = getpos('.')
    let Column = Pos[2]
    let FirstData = 10
    let LastData = len(getline(line('.'))) - 2
    if Column < FirstData
        let Column = FirstData
    endif
    if Column > LastData
        let Column = LastData
    endif
    let DataByte = eval('('.Column.'-'.FirstData.') / 2')
    return DataByte
endfunction

" Get Extended linear address
function! s:HexGetExtLinAddress()
    let AddressLineNumber = search('^:......04', 'bcnW')
    let AddressLine = getline(AddressLineNumber)
    let LineDict = s:HexParseLine(AddressLine)
    let ExtLinAddress = LineDict['Data']
    return printf('0x%s0000', ExtLinAddress)
endfunction

" Get Address of current line
function! s:HexGetLineAddress()
    let ExtLinAddress = s:HexGetExtLinAddress()

    let LineDict = s:HexParseLine(getline(line('.')))
    let AddressOffset = LineDict['Address']

    let LineAddress = eval(
                \  ' (  '.ExtLinAddress.')'
                \ .'+(0x'.AddressOffset.')'
                \ )
    return printf('0x%x', LineAddress)
endfunction

" Get Address of current cursor position
function! s:HexGetAddress()
    let LineAddress       = s:HexGetLineAddress()
    let LineAddressOffset = s:HexGetDataByte()

    let Address = eval(
                \  ' (  '.LineAddress.')'
                \ .'+(  '.LineAddressOffset.')'
                \ )
    return printf('0x%x', Address)
endfunction

" Split data string in List of byte strings
function! HexSplitData(DataString)
    let DataList = split(a:DataString, '..\zs')
    return DataList
endfunction

" Get ASCII representation of current data
function! s:HexGetAsciiLine()
    let String = ''
    let LineDict = s:HexParseLine(getline(line('.')))
    let Data = LineDict['Data']
    let DataList = HexSplitData(Data)
    for Byte in DataList
        let ByteVal = eval('0x'.Byte)
        let String .= nr2char(ByteVal)
    endfor
    return String
endfunction

" Get value of current data under cursor for a:Bytes
function! HexGetVal(Bytes)
    let StartByte = s:HexGetDataByte()
    let HexString = ''
    let LineDict = s:HexParseLine(getline(line('.')))
    let Data = LineDict['Data']
    let DataList = HexSplitData(Data)
    if (StartByte + a:Bytes) <= len(DataList)
        let ByteNum = 0
        while ByteNum < a:Bytes
            let HexString .= DataList[StartByte + ByteNum]
            let ByteNum += 1
        endwhile
        return eval('0x'.HexString)
    else
        return -1
endfunction

" Get actual values for 1, 2, 4 Bytes in hex and dez
function! s:HexGetDezValuesString()
    let String = ''
    for i in [1, 2, 4]
        let Byte = HexGetVal(i)
        if Byte != -1
            let String .= ' ' . printf('0x%x (%d)', Byte, Byte)
        endif
    endfor
    return String
endfunction

" Build string for statusline
function! HexStatusLine()
    let StatusLine =
                \   ' Address: '
                \ . s:HexGetAddress()
                \ . ' Values: '
                \ . s:HexGetDezValuesString()
"                \ . ' Data: '
"                \ . s:HexGetAsciiLine()
    return StatusLine
endfunction

function! s:HexAddressIsSmaller(a1, a2)
    let a1 = eval(a:a1)
    let a2 = eval(a:a2)
    if (a1 < 0) && (a2 >= 0)
        " a1 is greater
        return 0
    elseif (a1 >= 0) && (a2 < 0)
        " a2 is greater
        return 1
    else
        return a1 < a2
    endif
endfunction

command! -nargs=1 HexGotoAddress call HexGotoAddress("<args>")
function! HexGotoAddress(address)
    let target = a:address
    " Find correct section
    normal G
    while s:HexAddressIsSmaller(target, s:HexGetExtLinAddress())
        call search('^:......04', 'bcW')
        normal k
    endwhile

    " Find correct line
    while s:HexAddressIsSmaller(target, s:HexGetLineAddress())
        normal k
    endwhile

    " Find corret position
    normal $h
    while s:HexAddressIsSmaller(target, s:HexGetAddress())
        normal hh
    endwhile
endfunction

"command! HexAddress call Test()
"function! Test()
"    echo HexStatusLine()
"endfunction

command! HexStatusLine set statusline=%!HexStatusLine()
command! HexStatusLineOff set statusline=
" Always update statusline with HEX info
set statusline=%!HexStatusLine()
" Always show statusline
set laststatus=2
