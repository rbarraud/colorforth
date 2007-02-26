.intel_syntax ;#colorforth, 2001 jul 22, chuck moore, public domain

;# can't use loopnz in 32-bit mode
.macro next adr
    dec  ecx
    jnz  \adr
.endm

;# save contents of eax on data stack
;# (eax is already a copy of top of data stack)
.macro dup_
    lea  esi, [esi-4]
    mov  [esi], eax
.endm

;# pop what's at bottom of data stack back into eax
.macro drop
    lodsd
.endm

;# compile Forth words with Huffman coding
.macro packword words:vararg
 .irp word, \words
 .equ packed, 0
 .equ bitcount, 32
 .equ stoppacking, 0
 .irpc letter, "\word"
  .equ savepacked, packed
  .equ huffindex, 0
  .equ huffcode, 0
  .irpc huffman, " rtoeanismcylgfwdvpbhxuq0123456789j-k.z/;:!+@*,?"
   .ifeqs "\letter", "\huffman"
    .equ bitshift, 4 + (huffindex / 8)
    .ifge bitshift - 6
     .equ bitshift, 7
    .endif
    .ifeq stoppacking
     .equ packed, packed | (huffcode << (bitcount - bitshift))
     .equ bitcount, bitcount - bitshift
    .endif
   .else
    .equ huffindex, huffindex + 1
    .equ huffcode, huffcode + 1
    .ifeq huffcode - 0b00001000 ;# going from 4-bit to 5-bit code
     .equ huffcode, 0b00010000
    .endif
    .ifeq huffcode - 0b00011000 ;# going from 5-bit to 7-bit code
     .equ huffcode, 0b01100000
    .endif
   .endif
  .endr
  .ifne packed & 0xf ;# low 4 bits cannot be occupied with packed stuff
   .equ packed, savepacked
   .equ stoppacking, -1
  .endif
 .endr
 .long packed
 .endr
.endm

.macro display string, color
 .ifeqs "\color", ""
  .ascii "\r"; .byte white; .ascii "\n"; .byte white
 .else
  .irpc char, "\string"
   .ascii "\char"; .byte \color
  .endr
 .endif
.endm

.macro zero register
    push 0
    pop \register
.endm

.macro long longwords:vararg
 .irp longword \longwords
  .long \longword + loadaddr
 .endr
.endm

;# Memory map: 'xxxx' amounts vary depending on chosen stack size
;#   100000 dictionary (grows upwards)
;#    a0000 end of available low RAM on most systems, no more code can load 
;#    xxxxx free
;#     xxxx source ;# block 18, first high-level source block (load screen)
;#     xxxx character maps ;# block 12
;#     xxxx relocated bootcode begins here, at "gods"
;#     xxxx top of "god" return stack
;#     xxxx top of "god" data stack
;#     xxxx top of "main" return stack
;#     7c00 (bios boot sector... only during boot)
;#     xxxx top of "main" data stack, grows downwards
;#     4d00 bottom of edit buffer (grows upwards)
;#      500 floppy buffer (0x4800 bytes)
;#      400 system area, 256 bytes
;#        0 BIOS interrupt table
.equ cell, 4  ;# bytes per word
.equ blocksize, 1024  ;# bytes per Forth block
.equ hp, 1024 ;# 1024 or 800
.equ vp, 768 ;# 768 or 600
.equ vesa, 0x4117 ;# bit 12 sets linear address mode in 0x117 or 0x114
.equ iobuffer, 0x500 ;# buffer for reading and writing floppy disk cylinders
.equ buffersize, 0x4800 ;# 512 bytes * 18 tracks * 2 heads per cylinder
.equ retstacksize, (1500 * cell) ;# 1500 cells in CM2001 original
.equ datastacksize, (750 * cell) ;# 750 cells in CM2001 original
.equ buffer, (iobuffer + buffersize) ;# this is the edit buffer
;# wonder if edit buffer can be same as floppy buffer? not in use at same time
.equ maind, buffer + datastacksize
.equ mains, maind + retstacksize
.equ godd, mains + datastacksize
.equ gods, godd + retstacksize
.equ remainder, (blocksize - (gods % blocksize))
.if remainder < blocksize
 .equ gods, gods + remainder ;# no sense wasting space, add to stack
.endif
.equ loadaddr, gods ;# from here upwards is where we relocate the code
.equ bootaddr, 0x7c00
.equ icons, loadaddr + (12 * blocksize) ;# block 12 start of character maps
.equ green, 10
.equ red, 12
.equ white, 15

.include "boot.asm" ;# bootsector and related routines
.code32 ;# protected-mode code from here on out
warm: dup_
start1:
    call show0 ;# set up 'main' task to draw screen
;# number of Forth words and number of macros
    mov  dword ptr forths + loadaddr, offset ((forth1-forth0)/4) 
    mov  dword ptr macros + loadaddr, offset ((macro1-macro0)/4) 
    mov  eax, 18 ;# load start screen, 18
    dup_ ;# so when the load routine "drops" it, the stack won't underflow
;# the start screen loads a bunch of definitions, then 'empty' which shows logo
    call load
    jmp  accept ;# wait for keyhit

;# This version of colorforth has cooperative round-robin multi-tasking.
;# the tasks are: God (the forth kernel), and main
;# Each has two grow-down stacks; 's' indicates the
;# return stack, 'd' indicates the data stack.  Thus 'Gods' and 'Godd'
;# are the tops of the return and data stacks, respectively, for the
;# God task.
.align 4
;# 'me' points to the save slot for the current task
me: long god
screen:
    .long 0 ;# logo will be stored here
;# When we switch tasks, we need to switch stacks as well.  We do this
;# by pushing eax (cached top-of-stack) onto the data stack, pushing
;# the data stack pointer onto the return stack, and then saving the
;# return stack pointer into the save slot for the task.
;#
;# these are the save slots - each is followed by code to resume the
;# next task - the last one jumps 'round to the first.
round: call unpause
god:
    .long 0 ;# gods-2*4
    call unpause
main:
    .long 0 ;# mains-2*4
    jmp  round

pause: dup_ ;# save cached datum from top of data stack
    push esi ;# save data stack pointer on return stack
    mov  eax, me + loadaddr ;# get current task
    mov  [eax], esp ;# put our stack pointer into [me]
    add  eax, 4 ;# skip storage slot, point to round-robin CALL or JMP
    jmp  eax ;# execute the CALL or JMP

unpause: pop  eax ;# return address is that of 'main' slot above
    mov  esp, [eax] ;# load 'main' task return stack
    mov  me + loadaddr, eax ;# 'main' task becomes 'me', current task
    pop  esi ;# restore my task's data-stack pointer
    drop ;# load previously dup'd datum back into EAX
    ret

act: ;# set currently active task
    mov  edx, maind-4 ;# data stack of 'main' task
    mov  [edx], eax ;# 0 if called from 'show'
    mov  eax, mains-4 ;# return stack of 'main' task
    pop  [eax] ;# return of 'god' task now on 'main' stack
    sub  eax, 4 ;# down one slot on 'main' stack
    mov  [eax], edx ;# store 'main' data stack pointer
    mov  main + loadaddr, eax ;# 'main' return stack pointer in 'main' slot
    drop ;# what was 'dup'd before now into eax
    ret ;# to previous caller, since we already popped 'our' return address

show0: call show
    ret
show: pop screen + loadaddr ;# return address into screen; 'ret' if from show0
    dup_
    xor  eax, eax
    call act ;# make following infinite loop the 'active task'
0:  call graphic ;# just 'ret' in gen.asm
    call [screen + loadaddr] ;# ret if called from show0
    call switch ;# load framebuffer into video, then switch task
    inc  eax ;# why bother?
    jmp  0b ;# loop eternally

c_: mov  esi, godd+4
    ret

mark: ;# save current state so we can recover later with 'empty'
    mov  ecx, [macros + loadaddr] ;# save number of macros in longword mk
    mov  [mk + loadaddr], ecx
    mov  ecx, [forths + loadaddr] ;# number of forth words in mk+1
    mov  [mk + loadaddr + 4], ecx
    mov  ecx, [h + loadaddr] ;# 'here' pointer in mk+2
    mov  [mk + loadaddr + 8], ecx
    ret

empty: ;# restore state saved at last 'mark'
    mov  ecx, [mk + loadaddr + 8]
    mov  [h + loadaddr], ecx ;# 'here' pointer restored
    mov  ecx, [mk + loadaddr + 4]
    mov  [forths + loadaddr], ecx ;# number of forth words restored
    mov  ecx, [mk + loadaddr]
    mov  [macros + loadaddr], ecx ;# number of macros restored
    mov  dword ptr class + loadaddr, 0 ;# (jc) not sure what this is for yet
    ret

mfind: ;# find pointer to macro code
    mov  ecx, [macros + loadaddr] ;# number of macros, 1-based
    push edi ;# save destination pointer, we need to use it momentarily
    lea  edi, [macro0 + loadaddr - 4 + ecx * 4] ;# point to last macro
    jmp  0f ;# search dictionary

find: ;# locate code of high- or low-level Forth word
    mov  ecx, forths + loadaddr ;# current number of Forth definitions
    push edi ;# save destination pointer so we can use it
    lea  edi, [forth0 + loadaddr -4+ecx*4] ;# point it to last packed Forth word
0:  std  ;# search backwards
    repne scasd ;# continue moving until we hit a match
    cld  ;# clear direction flag again
    pop  edi ;# no longer need this, can tell from ECX where match was found
    ret

ex1: dec dword ptr words + loadaddr ;# from keyboard
    jz   0f
    drop
    jmp  ex1
0:  call find
    jnz  abort1
    drop
;# jump to low-level code of Forth word or macro
    jmp  [forth2+loadaddr+ecx*4]

execute: mov dword ptr lit + loadaddr, offset alit + loadaddr
    dup_ ;# save EAX on data stack
    mov  eax, [loadaddr-4+edi*4]
ex2:
    and  eax, 0xfffffff0 ;# mask tag bits which indicate word type
    call find ;# look for word in the dictionary
    jnz  abort ;# if not found, abort
    drop ;# restore EAX from data stack
    jmp  [forth2+loadaddr+ecx*4] ;# execute the Forth word found

abort: mov  curs + loadaddr, edi
    shr  edi, 10-2
    mov  blk + loadaddr, edi
abort1: mov  esp, gods ;# reset return stack pointer
    mov  dword ptr spaces+3*4 + loadaddr, offset forthd + loadaddr ;# adefine
    mov  dword ptr spaces+4*4 + loadaddr, offset qcompile + loadaddr
    mov  dword ptr spaces+5*4 + loadaddr, offset cnum + loadaddr
    mov  dword ptr spaces+6*4 + loadaddr, offset cshort + loadaddr
    mov  eax, 057 ;# '?'
    call echo_
    jmp  accept

sdefine: pop adefine + loadaddr
    ret
macro_: call sdefine
macrod: mov  ecx, [macros + loadaddr]
    inc dword ptr [macros + loadaddr]
    lea  ecx, [macro0+loadaddr+ecx*4]
    jmp  0f

forth: call sdefine
forthd:
    mov  ecx, forths + loadaddr ;# current count of Forth words
    inc dword ptr forths + loadaddr ;# make it one more
;# point to the slot for the next definition
    lea  ecx, [forth0+loadaddr+ecx*4]
0:  mov  edx, [loadaddr-4+edi*4] ;# load the packed word from source block
    and  edx, 0xfffffff0 ;# mask out the tag bits
    mov  [ecx], edx ;# store the "naked" word in the dictionary
    mov  edx, h + loadaddr ;# 'here' pointer for new compiled code
    mov  [forth2-forth0+ecx], edx
    lea  edx, [forth2-forth0+ecx]
    shr  edx, 2
    mov  last + loadaddr, edx
    mov  list + loadaddr, esp
    mov  dword ptr lit + loadaddr, offset adup + loadaddr
    test dword ptr class + loadaddr, -1
    jz   0f
    jmp  [class + loadaddr]
0:  ret

cdrop: mov  edx, h + loadaddr
    mov  list + loadaddr, edx
    mov  byte ptr [edx], 0x0ad ;# lodsd
    inc  dword ptr h + loadaddr
    ret

qdup: mov  edx, h + loadaddr
    dec  edx
    cmp  list + loadaddr, edx
    jnz  cdup
    cmp  byte ptr [edx], 0x0ad
    jnz  cdup
    mov  h + loadaddr, edx
    ret
cdup: mov  edx, h + loadaddr
    mov  dword ptr [edx], 0x89fc768d
    mov  byte ptr [4+edx], 06
    add dword ptr h + loadaddr, 5
    ret

adup: dup_
    ret

var1: dup_
    mov  eax, [loadaddr+4+forth0+ecx*4]
    ret
variable: call forthd
    mov dword ptr [loadaddr+forth2-forth0+ecx], offset var1 + loadaddr
    inc dword ptr forths + loadaddr ;# dummy entry for source address
    mov  [loadaddr+4+ecx], edi
    call macrod
    mov dword ptr [loadaddr + forth2-forth0+ecx], offset 0f
    inc dword ptr macros + loadaddr
    mov  [loadaddr+4+ecx], edi
    inc  edi
    ret
0:  call [lit + loadaddr]
    mov  eax, [loadaddr+4+macro0+ecx*4]
    jmp  0f

cnum: call [lit + loadaddr]
    mov  eax, [loadaddr+edi*4]
    inc  edi
    jmp  0f

cshort: call [lit + loadaddr]
    mov  eax, [loadaddr-4+edi*4]
    sar  eax, 5
0:  call literal
    drop
    ret

alit: mov dword ptr lit + loadaddr, offset adup + loadaddr
literal: call qdup
    mov  edx, list + loadaddr
    mov  list + loadaddr + 4, edx
    mov  edx, h + loadaddr
    mov  list + loadaddr, edx
    mov  byte ptr [edx], 0x0b8
    mov  [edx+1], eax
    add dword ptr h + loadaddr, 5
    ret

qcompile: call [lit + loadaddr]
    mov  eax, [loadaddr-4+edi*4]
    and  eax, 0xfffffff0 ;# mask out tag bits
    call mfind ;# locate word in macro dictionary
    jnz  0f ;# if failed, try in Forth dictionary
    drop ;# restore EAX
    jmp  [loadaddr + macro2+ecx*4] ;# jmp to macro code
0:  call find ;# try to find the word in the Forth dictionary
;# load code pointer in case there was a match
    mov  eax, [loadaddr + forth2 + ecx*4]
0:  jnz  abort ;# abort if no match in Forth dictionary
call_:
    mov  edx, h + loadaddr ;# get 'here' pointer, where new compiled code goes
    mov  list + loadaddr, edx
    mov  byte ptr [edx], 0x0e8 ;# x86 "call" instruction
    add  edx, 5
    sub  eax, edx ;# it has to be a 32-bit offset rather than absolute address
    mov  [edx-4], eax ;# store it after the "call" instruction
    mov  h + loadaddr, edx ;# point 'here' to end of just-compiled code
    drop ;# restore EAX from data stack
    ret

compile: call [lit + loadaddr]
    mov  eax, [loadaddr-4+edi*4]
    and  eax, 0xfffffff0 ;# mask out tag bits
    call mfind
    mov  eax, [loadaddr + macro2 + ecx*4]
    jmp  0b

short_: mov dword ptr lit + loadaddr, offset alit + loadaddr
    dup_
    mov  eax, [loadaddr-4+edi*4]
    sar  eax, 5
    ret

num: mov dword ptr lit + loadaddr, offset alit + loadaddr
    dup_
    mov  eax, [loadaddr+edi*4]
    inc  edi
    ret

comma: mov  ecx, 4
0:  mov  edx, h + loadaddr
    mov  [edx], eax
    mov  eax, [esi] ;# drop
    lea  edx, [edx+ecx]
    lea  esi, [esi+4]
    mov  h + loadaddr, edx
    ret

comma1: mov  ecx, 1
    jmp  0b

comma2: mov  ecx, 2
    jmp  0b

comma3: mov  ecx, 3
    jmp  0b

semi: mov  edx, h + loadaddr
    sub  edx, 5
    cmp  list + loadaddr, edx
    jnz  0f
    cmp  byte ptr [edx], 0x0e8
    jnz  0f
    inc  byte ptr [edx] ;# jmp
    ret
0:  mov  byte ptr [5+edx], 0x0c3 ;# ret
    inc  dword ptr h + loadaddr
    ret

then: mov  list + loadaddr, esp
    mov  edx, h + loadaddr
    sub  edx, eax
    mov  [-1+eax], dl
    drop
    ret

begin: mov  list + loadaddr, esp
here: dup_
    mov  eax, h + loadaddr
    ret

qlit: mov  edx, h + loadaddr
    lea  edx, [edx-5]
    cmp  list + loadaddr, edx
    jnz  0f
    cmp  byte ptr [edx], 0x0b8
    jnz  0f
    dup_
    mov  eax, list+loadaddr+4
    mov  list + loadaddr, eax
    mov  eax, [1+edx]
    cmp  dword ptr [edx-5], 0x89fc768d ;# dup
    jz   q1
    mov  h + loadaddr, edx
    jmp  cdrop
q1: add dword ptr h + loadaddr, -10 ;# flag nz
    ret
0:  xor  edx, edx ;# flag z
    ret

less: cmp  [esi], eax
    js   0f ;# flag nz
    xor  ecx, ecx ;# flag z
0:  ret

qignore: test dword ptr [loadaddr-4+edi*4], 0xfffffff0 ;# valid packed word?
    jnz  nul  ;# return if so
    pop  edi  ;# otherwise escape from load loop
    pop  edi
nul: ret

jump: pop  edx
    add  edx, eax
    lea  edx, [5+eax*4+edx]
    add  edx, [-4+edx]
    drop
    jmp  edx

load: shl  eax, 10-2 ;# multiply by 256 longwords, same as 1024 bytes
    push edi ;# save EDI register, we need it for the inner interpreter loop
    mov  edi, eax
    drop ;# block number from data stack
inter: mov  edx, [loadaddr + edi*4] ;# get next longword from block
    inc  edi ;# then point to the following one
    and  edx, 017 ;# get only low 4 bits, the type tag
    call spaces[loadaddr + edx*4] ;# call the routine appropriate to this type
    jmp  inter ;# loop till "nul" reached, which ends the loop

.align 4
spaces: long qignore, execute, num
adefine: ;# where definitions go, either in macrod (dictionary) or forthd
    long macrod ;# default, the macro dictionary
    long qcompile, cnum, cshort, compile
    long short_, nul, nul, nul
    long variable, nul, nul, nul

lit: long adup
mk: .long 0, 0, 0
h: .long 0x100000 ;# start compiling here, beginning of extended memory
last: .long 0
class: .long 0
list: .long 0, 0
macros: .long 0
forths: .long 0

macro0:
    packword ";", dup, ?dup, drop, then, begin
macro1:
    .rept 128 - ((.-macro1)/4) .long 0; .endr ;# room for new macros
forth0:
    packword boot, warm, pause, macro, forth, c, stop, read, write, nc
    packword command, seek, ready, act, show, load, here, ?lit, "3,", "2,"
    packword "1,", ",", less, jump, accept, pad, erase, copy, mark, empt
    packword emit, digit, 2emit, ., h., h.n, cr, space, down, edit
    packword e, lm, rm, graphic, text, keyboard, debug, at, +at, xy
    packword fov, fifo, box, line, color, octant, sp, last, unpack, vframe
forth1:
    .rept 512 - ((.-forth1)/4) .long 0; .endr
macro2:
    long semi, cdup, qdup, cdrop, then, begin
0:
    .rept 128 - ((.-0b)/4) .long 0; .endr
forth2:
    long boot, warm, pause, macro_, forth, c_, stop, readf, writef, nc_
    long cmdf, seekf, readyf, act, show, load, here, qlit, comma3, comma2
    long comma1, comma, less, jump, accept, pad, erase, copy, mark, empty
    long emit, edig, emit2, dot10, hdot, hdotn, cr, space, down, edit
    long e, lms, rms, graphic, text1, keyboard, debug, at, pat, xy_
    long fov_, fifof, box, line, color, octant, sps, last_, unpack, vframe
0:
    .rept 512 - ((.-0b)/4) .long 0; .endr ;# room for new definitions

boot: mov  al, 0x0fe ;# reset
    out  0x64, al
    jmp  .

erase:
    mov  ecx, eax
    shl  ecx, 8
    drop
    push edi
    mov  edi, eax
    shl  edi, 2+8
    xor  eax, eax
    rep stosd
    pop edi
    drop
    ret

;# copy block from blk to block number at top-of-stack (in EAX)
copy: cmp  eax, 12 ;# can't overwrite machine-code blocks...
    jc   abort1 ;# so if we're asked to, abort the operation
    mov  edi, eax ;# get block number into EDI
    shl  edi, 2+8 ;# multiply by 1024 to get physical (byte) address
    push esi  ;# save data stack pointer so we can use it for block move
    mov  esi, blk ;# get current block number from blk
    shl  esi, 2+8 ;# multiply by 1024 to get address
    mov  ecx, 256 ;# 256 longwords = 1024 bytes
    rep  movsd ;# move the block from source (ESI) to destination (EDI)
    pop  esi  ;# restore data stack pointer
;# destination block becomes new current block (blk)
    mov  blk + loadaddr, eax
    drop ;# no longer need the block number
    ret

debug: mov dword ptr xy + loadaddr, offset (3*0x10000+(vc-2)*ih+3)
    dup_
    mov  eax, god + loadaddr
    push [eax]
    call dot
    dup_
    pop  eax
    call dot
    dup_
    mov  eax, main
    call dot
    dup_
    mov  eax, esi
    jmp  dot

.equ iw, 16+6 ;# icon width, including 6 pixels padding
.equ ih, 24+6 ;# icon height, including padding
.equ hc, hp/iw ;# 46 ;# number of horizontal characters on screen
.equ vc, vp/ih ;# 25 ;# number of vertical characters
.align 4 
xy: .long 3*0x10000+3 ;# 3 pixels padding on each side of icons
lm: .long 3
rm: .long hc*iw ;# 1012
xycr: .long 0
fov: .long 10*(2*vp+vp/2)

nc_: dup_
    mov  eax, (offset nc-offset start)/4
    ret

xy_: dup_
    mov  eax, (offset xy-offset start)/4
    ret

fov_: dup_
    mov  eax, (offset fov-offset start)/4
    ret

sps: dup_
    mov  eax, (offset spaces-offset start)/4
    ret

last_: dup_
    mov  eax, (offset last-offset start)/4
    ret

.include "gen.asm" ;# cce.asm pio.asm ati128.asm ati64.asm gen.asm

.equ yellow, 0xffff00 ;# RG0 is yellow
cyan: dup_
    mov  eax, 0x00ffff ;# 0GB is cyan
    jmp  color
magenta: dup_
    mov  eax, 0xff00ff ;# R0B is magenta
    jmp  color
silver: dup_ ;# half-brightness white
    mov  eax, 0xc0c0c0 ;# rgb, 4 bits of each
    jmp  color
blue: dup_
    mov  eax, 0x4040ff ;# a little r and g to make it brighter
    jmp  color
red: dup_
    mov  eax, 0xff0000 ;# pure red
    jmp  color
green: dup_
    mov  eax, 0x8000ff00 ;# what's that 0x80 for?
    jmp  color

history:
    .rept 11 .byte 0; .endr
echo_: push esi
    mov  ecx, 11-1
    lea  edi, history + loadaddr
    lea  esi, [1+edi]
    rep  movsb
    pop  esi
    mov  history + loadaddr +11-1, al
    drop
    ret

right: dup_
    mov  ecx, 11
    lea  edi, history + loadaddr
    xor  eax, eax
    rep  stosb
    drop
    ret

down: dup_
    xor  edx, edx
    mov  ecx, ih
    div  ecx
    mov  eax, edx
    add  edx, 3*0x10000+0x8000-ih+3
    mov  xy + loadaddr, edx
zero: test eax, eax
    mov  eax, 0
    jnz  0f
    inc  eax
0:  ret

blank: dup_
    xor  eax, eax
    mov  xy + loadaddr, eax
    call color
    dup_
    mov  eax, hp
    dup_
    mov  eax, vp
    jmp  box

top: mov  ecx, lm + loadaddr
    shl  ecx, 16
    add  ecx, 3
    mov  xy + loadaddr, ecx
    mov  xycr + loadaddr, ecx
    ret

;# insert a carriage return if at end of line
qcr: mov  cx, word ptr xy+loadaddr+2
    cmp  cx, word ptr rm + loadaddr
    js   0f
;# insert a carriage return (drop to next line)
cr: mov  ecx, lm + loadaddr
    shl  ecx, 16
    mov  cx, word ptr xy + loadaddr
    add  ecx, ih
    mov  xy + loadaddr, ecx
0:  ret

lms: mov  lm + loadaddr, eax
    drop
    ret

rms: mov  rm + loadaddr, eax
    drop
    ret

at: mov  word ptr xy + loadaddr, ax
    drop
    mov  word ptr xy+loadaddr+2, ax
    drop
    ret

pat: add  word ptr xy + loadaddr, ax
    drop
    add  word ptr xy+loadaddr+2, ax
    drop
    ret

octant: dup_
    mov  eax, 0x43 ;# poly -last y+ x+ ;0x23 ; last y+ x+
    mov  edx, [4+esi]
    test edx, edx
    jns  0f
    neg  edx
    mov  [4+esi], edx
    xor  al, 1
0:  cmp  edx, [esi]
    jns  0f
    xor  al, 4
0:  ret

;# keyboard
;# display one line of the onscreen keyboard (eight icons)
;# four chars at addr+12, space, four chars at addr.
;# IN: edi = addr-4
;# OUT: edi = addr
eight: add  edi, 12
    call four
    call space
    sub  edi, 16
four: mov  ecx, 4
;# display ECX chars from EDI+4, incrementing EDI with each char.
four1: push ecx
    dup_
    xor  eax, eax
    mov  al, [4+edi]
    inc  edi
    call emit
    pop  ecx
    next four1
    ret

stack: mov  edi, godd-4
0:  mov  edx, god
    cmp  [edx], edi
    jnc  0f
    dup_
    mov  eax, [edi]
    sub  edi, 4
    call qdot
    jmp  0b
0:  ret

keyboard: call text1
    mov  edi, board + loadaddr
    dup_
    mov  eax, keyc + loadaddr
    call color
    mov dword ptr rm + loadaddr, hc*iw
    mov dword ptr lm + loadaddr, hp-9*iw+3
    mov dword ptr xy + loadaddr, (hp-9*iw+3)*0x10000+vp-4*ih+3
    call eight
    call eight
    call eight
    call cr
    add  dword ptr xy + loadaddr, 4*iw*0x10000
    mov  edi, shift + loadaddr
    add  edi, 4*4-4
    mov  ecx, 3
    call four1
    mov  dword ptr lm + loadaddr, 3
    mov  word ptr xy + loadaddr + 2, 3
    call stack
    mov  word ptr xy + loadaddr +2, hp-(11+9)*iw+3
    lea  edi, history + loadaddr -4
    mov  ecx, 11
    jmp  four1

alpha: .byte 015, 012,  1 , 014
    .byte 024,  2 ,  6 , 010
    .byte 023, 011, 017, 021
    .byte 022, 013, 016,  7
    .byte  5 ,  3 ,  4 , 026
    .byte 027, 044, 025, 020
graphics: .byte 031, 032, 033, 0 ;# 1 2 3
    .byte 034, 035, 036, 030 ;# 4 5 6 0
    .byte 037, 040, 041, 057 ;# 7 8 9 ?
    .byte 051, 050, 052, 054 ;# : ; ! @
    .byte 046, 042, 045, 056 ;# z j . ,
    .byte 055, 047, 053, 043 ;# * / + -
numbers: .byte 031, 032, 033, 0 ;# 1 2 3
    .byte 034, 035, 036, 030 ;# 4 5 6 0
    .byte 037, 040, 041,  0  ;# 7 8 9 ?
    .byte  0,   0 ,  0 ,  0
    .byte  0,   0 ,  0 ,  0
    .byte  0,   0 ,  0 ,  0
octals: .byte 031, 032, 033, 0 ;# 1 2 3
    .byte 034, 035, 036, 030 ;# 4 5 6 0
    .byte 037, 040, 041,  0  ;# 7 8 9
    .byte  0 ,  5 , 023, 012
    .byte  0 , 020,  4 , 016
    .byte  0 ,  0 ,  0 ,  0
letter:
    cmp  al, 4
    js   0f
    mov  edx, board
    mov  al, [edx][eax]
0:  ret

keys: .byte 16, 17, 18, 19,  0,  0,  4,  5 ;# 20
    .byte  6,  7,  0,  0,  0,  0, 20, 21
    .byte 22, 23,  0,  0,  8,  9, 10, 11 ;# 40
    .byte  0,  0,  0,  0, 24, 25, 26, 27
    .byte  0,  1, 12, 13, 14, 15,  0,  0 ;# 60 n
    .byte  3,  2 ;# alt space

key: ;# loop forever, returning keyhits when available
/* the original CM2001 version uses this as the multitasking loop,
/* by calling 'pause' each time through the loop. this is what enables
/* the constant screen refresh, which causes significant delays in
/* keystroke processing under Bochs. */
    dup_             ;# save copy of return stack pointer(?)
    xor  eax, eax    ;# used as index later, so clear it
0:  call pause       ;# give other task a chance to run
    in   al, 0x64    ;# keyboard status port
    test al, 1       ;# see if there is a byte waiting
    jz   0b          ;# if not, loop
    in   al, 0x60    ;# fetch the scancode
    test al, 0xf0    ;# top row of keyboard generates scancodes < 0x10
    jz   0b          ;# we don't use that row (the numbers row), so ignore it
    cmp  al, 58      ;# 57, right shift, is the highest scancode we use
    jnc  0b          ;# so if it's over, ignore that too
    /* since we're ignoring scancodes less than 0x10, we subtract that
    /* before indexing into the table, that way the table doesn't have
    /* to have 16 wasted bytes */
    mov  al, [loadaddr+keys-0x10+eax] ;# index into key table
    ret

.align 4
;# layouts for the thumb (shift) keys
;# these sort of go in pairs:
;# foo0 is for the first character of a word
;# foo1 is used for the rest
graph0: long nul0, nul0, nul0, alph0
    .byte  0 ,  0 ,  5 , 0 ;#     a
graph1: long word0, x, lj, alph
    .byte 025, 045,  5 , 0 ;# x . a
alpha0: long nul0, nul0, number, star0
    .byte  0 , 041, 055, 0 ;#   9 *
alpha1: long word0, x, lj, graph
    .byte 025, 045, 055, 0 ;# x . *
numb0: long nul0, minus, alphn, octal
    .byte 043,  5 , 016, 0 ;# - a f
numb1: long number0, xn, endn, number0
    .byte 025, 045,  0 , 0 ;# x .

board: long alpha-4
shift: long alpha0
base: .long 10
current: long decimal
keyc: .long yellow
chars: .long 1
aword: long ex1
anumber: long nul
words: .long 1

nul0: drop
    jmp  0f
accept:
acceptn: mov dword ptr shift + loadaddr, offset alpha0 + loadaddr
    lea  edi, alpha + loadaddr - 4
accept1: mov board + loadaddr, edi
0:  call key
    cmp  al, 4
    jns  first
    mov  edx, shift + loadaddr
    jmp  dword ptr [edx+eax*4]

bits: ;# number of bits available in word for packing more Huffman codes
   .byte 28
/* for reference, Huffman codes are in groups of 8, the prefixes being:
  0xxx, 10xxx, 1100xxx, 1101xxx, 1110xxx, 1111xxx
  "pack" packs one letter (character code at a time, 
  into a Huffman-coded word at [ESI] (stack item) */
0:  add  eax, 0b01010000 ;# make 0b00010000 into 0b01100000, high 2 bits set
    mov  cl, 7 ;# this is a 7-bit Huffman code
    jmp  0f ;# continue below
pack: cmp  al, 0b00010000 ;# character code greater than 16?
    jnc  0b ;# if so, it's a 7-bitter, see above
    mov  cl, 4 ;# otherwise assume it's a 4-bit code
    test al, 0b00001000 ;# character code more than 7?
    jz   0f ;# if so, it's a 5-bit Huffman code
    inc  ecx ;# make the 4 into a 5
    xor  al, 0b00011000 ;# and change prefix to 10xxx
;# common entry point for 4, 5, and 7-bit Huffman codes
0:  mov  edx, eax ;# copy Huffman code into EDX
    mov  ch, cl ;# copy Huffman-code bitcount into 8-bit CH register
0:  cmp  bits + loadaddr, cl ;# do we have enough bits left in the word?
    jnc  0f  ;# if so, continue on
    shr  al, 1 ;# low bit of character code set?
    jc   full ;# if so, word is full, need to start an extension word instead
    dec  cl  ;# subtract one from bitcount
    jmp  0b ;# keep going; as long as we don't find any set bits, it'll fit
0:  shl  dword ptr [esi], cl ;# shift over just the amount of bits necessary
    xor  [esi], eax ;# 'or' or 'add' would have worked as well (and clearer?)
    sub  bits + loadaddr, cl ;# reduce remaining bitcount by what we just used
    ret

;# left-justification routine packs Huffman codes into the MSBs of the word
lj0: mov  cl, bits + loadaddr ;# bits remaining into CL register
    add  cl, 4 ;# add to that the 4 reserved bits for type tag
    shl  dword ptr [esi], cl ;# shift packed word into MSBs
    ret

;# this is just the high-level entry point to the above routine
lj: call lj0
    drop
    ret

;# the packed word is full, so finish processing
full: call lj0 ;# left-justify the packed word
    inc dword ptr words + loadaddr ;# bump the count
;# reset bit count, still saving 4 bits for tag
    mov byte ptr bits + loadaddr, 32-4
;# we were processing a character when we found the word full, so add it in
    sub  bits + loadaddr, ch ;# subtract saved bitcount of this Huffman code
    mov  eax, edx ;# restore top-of-stack with partial packed word
    dup_
    ret

x:  call right
    mov  eax, words + loadaddr
    lea  esi, [eax*4+esi]
    drop
    jmp  accept

word_: call right
    mov  dword ptr words + loadaddr, 1
    mov  dword ptr chars + loadaddr, 1
    dup_
    mov  dword ptr [esi], 0
    mov  byte ptr bits + loadaddr, 28
word1: call letter
    jns  0f
    mov  edx, shift + loadaddr
    jmp  dword ptr [edx+eax*4]
0:  test al, al
    jz   word0
    dup_
    call echo_
    call pack
    inc dword ptr chars + loadaddr
word0: drop
    call key
    jmp  word1

decimal: mov dword ptr base + loadaddr, 10
    mov dword ptr shift + loadaddr, offset numb0 + loadaddr
    mov dword ptr board + loadaddr, offset numbers + loadaddr - 4
    ret

hex: mov dword ptr base + loadaddr, 16
    mov dword ptr shift + loadaddr, offset numb0 + loadaddr ;# oct0
    mov dword ptr board + loadaddr, offset octals + loadaddr - 4
    ret

octal: xor dword ptr current + loadaddr, (offset decimal-offset start) ^ (offset hex-offset start)
    xor  byte ptr numb0 + loadaddr + 18, 041 ^ 016 ;# f vs 9
    call [current + loadaddr]
    jmp  number0

xn: drop
    drop
    jmp  acceptn

digit: .byte 14, 10,  0,  0
    .byte  0,  0, 12,  0,  0,  0, 15,  0
    .byte 13,  0,  0, 11,  0,  0,  0,  0
    .byte  0,  1,  2,  3,  4,  5,  6,  7
    .byte  8,  9
sign: .byte 0
minus:
    mov  sign + loadaddr, al
    jmp  number2

number0: drop
    jmp  number3
number: call [current + loadaddr]
    mov byte ptr sign + loadaddr, 0
    xor  eax, eax
number3: call key
    call letter
    jns  0f
    mov  edx, shift + loadaddr
    jmp  dword ptr [loadaddr+edx+eax*4]
0:  test al, al
    jz   number0
    mov  al, [loadaddr+digit-4+eax]
    test byte ptr sign + loadaddr, 037
    jz   0f
    neg  eax
0:  mov  edx, [esi]
    imul edx, base + loadaddr
    add  edx, eax
0:  mov  [esi], edx
number2: drop
    mov  dword ptr shift + loadaddr, offset numb1 + loadaddr
    jmp  number3

endn: drop
    call [anumber + loadaddr]
    jmp  acceptn

alphn: drop
alph0: mov dword ptr shift + loadaddr, offset alpha0 + loadaddr
    lea  edi, alpha + loadaddr - 4
    jmp  0f
star0: mov dword ptr shift + loadaddr, offset graph0 + loadaddr
    lea  edi, graphics + loadaddr - 4
0:  drop
    jmp  accept1

alph: mov dword ptr shift + loadaddr, offset alpha1 + loadaddr
    /* variable 'board' holds a pointer to the keyboard currently in use:
    /* alphabetic, numeric, graphic, etc.
    /* since valid key codes start at 1, subtract length of 1 address
    /* (4 bytes) from the start of the table into which we index */
    lea  edi, alpha + loadaddr - 4
    jmp  0f
graph: mov dword ptr shift + loadaddr, offset graph1
    lea  edi, graphics + loadaddr - 4
0:  mov  board + loadaddr, edi
    jmp  word0

first: add dword ptr shift + loadaddr, 4*4+4
    call word_
    call [aword + loadaddr]
    jmp  accept

hicon: .byte 0x18, 0x19, 0x1a, 0x1b, 0x1c, 0x1d, 0x1e, 0x1f
    .byte 0x20, 0x21,  5 , 0x13, 0xa, 0x10,  4 , 0xe
edig1: dup_
edig: push ecx
    mov  al, hicon + loadaddr[eax]
    call emit
    pop  ecx
    ret

odig: rol  eax, 4
    dup_
    and  eax, 0x0f
    ret

hdotn: mov  edx, eax
    neg  eax
    lea  ecx, [32+eax*4]
    drop
    rol  eax, cl
    mov  ecx, edx
    jmp  0f
hdot: mov  ecx, 8
0:  call odig
    call edig
    next 0b
    drop
    ret

/* '.', 'dot' is the original Forth 'word' for
 * displaying a number off the stack */
dot: mov  ecx, 7
0:  call odig
    jnz  @h
    drop
    next 0b
    inc  ecx
0:  call odig
@h1: call edig
    next 0b
    call space
    drop
    ret
@h: inc  ecx
    jmp  @h1

qdot: cmp dword ptr base + loadaddr, 10
    jnz  dot
dot10: mov  edx, eax
    test edx, edx
    jns  0f
    neg  edx
    dup_
    mov  eax, 043
    call emit
0:  mov  ecx, 8
0:  mov  eax, edx
    xor  edx, edx
    div  dword ptr [tens + loadaddr + ecx*4]
    test eax, eax
    jnz  d_1
    dec  ecx
    jns  0b
    jmp  d_2
0:  mov  eax, edx
    xor  edx, edx
    div dword ptr [tens + loadaddr + ecx*4]
d_1: call edig1
    dec  ecx
    jns  0b
d_2: mov  eax, edx
    call edig1
    call space ;# spcr
    drop
    ret

/* unpack the Huffman-coded characters in a 32-bit word */
unpack: dup_
    test eax, eax
    js   0f
    shl  dword ptr [esi], 4
    rol  eax, 4
    and  eax, 7
    ret
0:  shl  eax, 1
    js   0f
    shl  dword ptr [esi], 5
    rol  eax, 4
    and  eax, 7
    xor  al, 0x8
    ret
0:  shl  dword ptr [esi], 7
    rol  eax, 6
    and  eax, 0x3f
    sub  al, 0x10
    ret

qring: dup_
    inc  dword ptr [esi]
    cmp  curs + loadaddr, edi ;# from abort, insert
    jnz  0f
    mov  curs + loadaddr, eax
0:  cmp  eax, curs + loadaddr
    jz   ring
    jns  0f
    mov  pcad + loadaddr, edi
0:  drop
    ret

ring:
    mov  cad + loadaddr, edi
    sub dword ptr xy + loadaddr, iw*0x10000 ;# bksp
    dup_
    mov  eax, 0x0e04000 ;# ochre-colored cursor
    call color
    mov  eax, 060
    mov  cx, word ptr xy + loadaddr +2
    cmp  cx, word ptr rm + loadaddr
    js   0f
    call emit
    sub dword ptr xy + loadaddr, iw*0x10000 ;# bksp
    ret
0:  jmp  emit

rw: mov  cx, word ptr xy + loadaddr +2
    cmp  cx, word ptr lm + loadaddr
    jz   0f
    call cr
0:  call red
    jmp  type_

gw: call green
    jmp  type_
mw: call cyan
    jmp  type_
ww: dup_
    mov  eax, yellow
    call color
    jmp  type_

type0: ;# display continuation of previous word
    sub  dword ptr xy + loadaddr, iw*0x10000 ;# call bspcr
    test dword ptr [loadaddr-4+edi*4], 0xfffffff0 ;# valid packed word?
    jnz  type1
    dec  edi
    mov  lcad + loadaddr, edi
    call space
    call qring
    pop  edx ;# .end of block
    drop
    jmp  keyboard

cap: ;# display a capitalized comment word
    call white
    dup_
    mov  eax, [-4+edi*4]
    and  eax, 0xfffffff0 ;# mask out tag bits
    call unpack
    add  al, 48
    call emit
    jmp  type2

caps: ;# display an all-caps comment word
    call white
    dup_
    mov  eax, [-4+edi*4]
    and  eax, 0xfffffff0 ;# mask out tag bits
0:  call unpack
    jz   0f ;# space if it unpacked to nothing
    add  al, 48
    call emit
    jmp  0b

text: call white
type_:
type1: dup_
    mov  eax, [-4+edi*4]
    and  eax, 0xfffffff0 ;# mask out tag bits
type2: call unpack
    jz   0f
    call emit
    jmp  type2
0:  call space
    drop
    drop
    ret

;# green (compiled) short (27 bits) word
gsw: mov  edx, [-4+edi*4]
    sar  edx, 5 ;# shift into position
    jmp  gnw1

var: ;# within editor, display a variable name
    call magenta
    call type_
;# fall through to next routine to display its value
;# green (compiled) normal (32 bits) word
gnw: mov  edx, [edi*4]
    inc  edi
gnw1: dup_
    mov  eax, 0x0f800 ;# green
    cmp dword ptr bas + loadaddr, offset dot10 + loadaddr ;# is it base 10?
    jz   0f ;# bright green if so
    mov  eax, 0x0c000 ;# else dark green
    jmp  0f

;# short (27 bits) yellow (executable) word
sw: mov  edx, [-4+edi*4]
    sar  edx, 5 ;# shift into position
    jmp  nw1

;# normal (32 bits) yellow (executable) word
nw: mov  edx, [edi*4]
    inc  edi
nw1: dup_
    mov  eax, yellow
    cmp dword ptr bas + loadaddr, offset dot10 + loadaddr ;# is it base 10?
    jz   0f ;# bright yellow if so
    mov  eax, 0x0c0c000 ;# else dark yellow
0:  call color
    dup_
    mov  eax, edx
    jmp  [bas + loadaddr]

refresh: call show
    call blank
    call text1
    dup_            ;# counter
    mov  eax, lcad + loadaddr
    mov  cad + loadaddr, eax ;# for curs beyond .end
    xor  eax, eax
    mov  edi, blk
    shl  edi, 10-2
    mov  pcad + loadaddr, edi ;# for curs=0
ref1: test dword ptr [loadaddr+edi*4], 0x0f
    jz   0f
    call qring
0:  mov  edx, [edi*4]
    inc  edi
    mov dword ptr bas + loadaddr, offset dot10 + loadaddr
    test dl, 020
    jz   0f
    mov dword ptr bas + loadaddr, offset dot + loadaddr
0:  and  edx, 017
    call display[edx*4]
    jmp  ref1

.align 4
display: long type0, ww, nw, rw
    long gw, gnw, gsw, mw
    long sw, text, cap, caps
    long var, nul, nul, nul
tens: .long 10, 100, 1000, 10000, 100000, 1000000
    .long 10000000, 100000000, 1000000000
bas: long dot10
blk: .long 18
curs: .long 0
cad: .long 0
pcad: .long 0
lcad: .long 0
trash: .long buffer

/* the editor keys and their actions */
ekeys:
;# delete (cut), exit editor, insert (paste)
    long nul, del, eout, destack ;# n<space><alt>
;# white (yellow), red, green, to shadow block
    long act1, act3, act4, shadow ;# uiop=yrg*
;# left, up, down, right
    long mcur, mmcur, ppcur, pcur ;# jkl;=ludr
;# previous block, magenta (variable), cyan (macro), next block
    long mblk, actv, act7, pblk ;# m,./=-mc+
;# white (comment) all caps, white (comment) capitalized, white (comment)
    long nul, act11, act10, act9 ;# wer=SCt
    long nul, nul, nul, nul ;# df=fj (find and jump) not in this version
;# these are the huffman encodings of the characters to display
ekbd0: long nul, nul, nul, nul
    .byte 21, 37,  7,  0  ;# x  .  i
ekbd:
    .byte 15,  1, 13, 45  ;# w  r  g  *
    .byte 12, 22, 16,  1  ;# l  u  d  r
    .byte 35,  9, 10, 43  ;# -  m  c  +
    .byte  0, 56, 58,  2  ;#    S  C  t
    .byte  0,  0,  0,  0
    .byte  0,  0,  0,  0
;# 1-based array of colors used for various action modes
actc:
    .long yellow, 0, 0x0ff0000, 0x0c000 ;# 1=yellow, 2=none, 3=red, 4=green
    .long 0, 0, 0x0ffff, 0 ;# 7=cyan
    .long 0x0ffffff, 0x0ffffff, 0x0ffffff, 0x8080ff ;# 9-11=white, 12=magenta
vector: .long 0
action: .byte 1

act1: mov  al, 1 ;# word execute, yellow
    jmp  0f
act3: mov  al, 3 ;# word define, red
    jmp  0f
act4: mov  al, 4 ;# word compile, green
    jmp  0f
act9: mov  al, 9 ;# word comment, white
    jmp  0f
act10: mov  al, 10 ;# word comment, white Capitalized
    jmp  0f
act11: mov  al, 11 ;# word comment, ALL CAPS
    jmp  0f
act7: mov  al, 7 ;# macro compile, cyan
0:  mov  action + loadaddr, al ;# number of action
    mov  eax, [actc + loadaddr -4+eax*4] ;# load color corresponding to action
;# "insert" becomes the active word
    mov dword ptr aword + loadaddr, offset insert + loadaddr
;# action for number
actn: mov  keyc + loadaddr, eax
    pop  eax
    drop
    jmp  accept
;# after 'm' pressed, change color and prepare to store variable name
actv: mov byte ptr action + loadaddr, 12 ;# variable
    mov  eax, 0x0ff00ff ;# magenta
    mov dword ptr aword + loadaddr, offset 0f
    jmp  actn
;# this is the action performed after the variable name is entered
0:  dup_ ;# save EAX (packed word) on stack
    xor  eax, eax ;# zero out EAX
    inc  dword ptr words + loadaddr ;# add one to count of words
    jmp  insert ;# insert new word into dictionary

mcur: dec dword ptr curs + loadaddr ;# minus cursor: move left
    jns  0f  ;# just return if it didn't go negative, otherwise undo it...
pcur: inc dword ptr curs + loadaddr ;# plus cursor: move right
0:  ret

mmcur: sub dword ptr curs + loadaddr, 8 ;# move up one row
    jns  0f  ;# return if it didn't go negative
    mov dword ptr curs + loadaddr, 0  ;# otherwise set to 0
0:  ret
ppcur: add dword ptr curs + loadaddr, 8 ;# move down one row
    ret  ;# guess it's ok to increment beyond end of screen (?)
;# plus one block (+2 since odd are shadows)
pblk: add dword ptr blk + loadaddr, 2
    add  dword ptr [esi], 2
    ret
mblk: cmp dword ptr blk + loadaddr, 20 ;# minus one block unless below 20
    js   0f ;# (18 is first block available for editing)
    sub dword ptr blk + loadaddr, 2
    sub  dword ptr [esi], 2
0:  ret
;# shadow screens in Forth are documentation for corresponding source screens
shadow: xor dword ptr  blk, 1 ;# switch between shadow and source
    xor  dword ptr [esi], 1 ;# change odd to even and vice versa
    ret

e0: drop
    jmp  0f

/* colorForth editor */
;# when invoked with 'edit', the block number is passed on the stack
edit: mov  blk + loadaddr, eax
    drop
;# when invoked with 'e', uses block number in blk, by default 18
e:  dup_
    mov  eax, blk + loadaddr
    mov dword ptr anumber+loadaddr, offset format + loadaddr
    mov  byte ptr alpha0+loadaddr+4*4, 045 ;# .
    mov dword ptr alpha0+loadaddr+4, offset e0 + loadaddr
    call refresh
0:  mov dword ptr shift + loadaddr, offset ekbd0 + loadaddr
    mov dword ptr board + loadaddr, offset ekbd-4 + loadaddr
    mov dword ptr keyc + loadaddr, yellow ;# default key color, yellow
;# this is the main loop
0:  call key
    call [ekeys + loadaddr + eax*4]
    drop
    jmp  0b

/* exit editor */
eout: pop  eax
    drop
    drop
    mov  dword ptr aword + loadaddr, offset ex1 + loadaddr
    mov  dword ptr anumber + loadaddr, offset nul + loadaddr
    mov  byte ptr alpha0+loadaddr+4*4, 0
    mov  dword ptr alpha0+loadaddr+4, offset nul0 + loadaddr
    mov  dword ptr keyc + loadaddr, yellow ;# restore key color to yellow
    jmp  accept ;# revert to command-line processing

/* insert, or paste */
;# grab what was left by last "cut" operation
destack: mov  edx, trash + loadaddr
    cmp  edx, buffer ;# anything in there?
    jnz  0f ;# continue if so...
    ret  ;# otherwise, 'insert' is already the default action so nothing to do
0:  sub  edx, 2*4
    mov  ecx, [edx+1*4]
    mov  words + loadaddr, ecx
0:  dup_
    mov  eax, [edx]
    sub  edx, 1*4
    next 0b
    add  edx, 1*4
    mov  trash + loadaddr, edx

insert0:
    mov  ecx, lcad + loadaddr ;# room available?
    add  ecx, words + loadaddr
    xor  ecx, lcad + loadaddr
    and  ecx, -0x100
    jz   insert1
    mov  ecx, words + loadaddr ;# no
0:  drop
    next 0b
    ret
insert1:
    push esi
    mov  esi, lcad + loadaddr
    mov  ecx, esi
    dec  esi
    mov  edi, esi
    add  edi, words + loadaddr
    shl  edi, 2
    sub  ecx, cad + loadaddr
    js   0f
    shl  esi, 2
    std
    rep  movsd
    cld
0:  pop  esi
    shr  edi, 2
    inc  edi
    mov  curs + loadaddr, edi ;# like abort
    mov  ecx, words + loadaddr
0:  dec  edi
    mov  [loadaddr+edi*4], eax
    drop ;# requires cld
    next 0b
    ret

insert:
    call insert0
    mov  cl, action + loadaddr
    xor  [loadaddr+edi*4], cl
    jmp  accept

format:
    test byte ptr action + loadaddr, 012 ;# ignore 3 and 9
    jz   0f
    drop
    ret
0:  mov  edx, eax
    and  edx, 0x0fc000000
    jz   0f
    cmp  edx, 0x0fc000000
    jnz  format2
0:  shl  eax, 5
    xor  al, 2 ;# 6
    cmp  byte ptr action + loadaddr, 4
    jz   0f
    xor  al, 013 ;# 8
0:  cmp  dword ptr base + loadaddr, 10 ;# base 10?
    jz   0f ;# continue if so...
    xor  al, 0x10 ;# otherwise remove 'hex' bit
0:  mov  dword ptr words + loadaddr, 1
    jmp  insert

format2: dup_
    mov  eax, 1 ;# 5
    cmp  byte ptr action + loadaddr, 4
    jz   0f
    mov  al, 3 ;# 2
0:  cmp  dword ptr base + loadaddr, 10 ;# base 10?
    jz   0f ;# continue if so...
    xor  al, 0x10 ;# otherwise remove 'hex' bit
0:  xchg eax, [esi]
    mov  dword ptr words + loadaddr, 2
    jmp  insert

;# delete, or cut, current word in editor (to the left of pacman cursor)
del: call enstack
    mov  edi, pcad + loadaddr
    mov  ecx, lcad + loadaddr
    sub  ecx, edi
    shl  edi, 2
    push esi
    mov  esi, cad + loadaddr
    shl  esi, 2
    rep  movsd
    pop  esi
    jmp  mcur

enstack: dup_
    mov  eax, cad + loadaddr
    sub  eax, pcad + loadaddr
    jz   ens
    mov  ecx, eax
    xchg eax, edx
    push esi
    mov  esi, cad + loadaddr
    lea  esi, [esi*4-4]
    mov  edi, trash + loadaddr
0:  std
    lodsd
    cld
    stosd
    next 0b
    xchg eax, edx
    stosd
    mov  trash + loadaddr, edi
    pop  esi
ens: drop
    ret

pad: pop  edx  ;# keypad data must immediately follow call...
;# we're popping the "return" address which is really the address of data
    mov  vector + loadaddr, edx
    add  edx, 28*5
    mov  board + loadaddr, edx
    sub  edx, 4*4
    mov  shift + loadaddr, edx
0:  call key
    mov  edx, vector + loadaddr
    add  edx, eax
    lea  edx, [5+eax*4+edx]
    add  edx, [-4+edx]
    drop
    call edx
    jmp  0b

 .include "chars.asm"
.ifdef I_HAVE_AT_LEAST_1GB_RAM
 .incbin "newcode.dat"
.else
 .incbin "color.dat"
.endif
.ifdef MANDELBROT
 .incbin "new_mandelbrot.blk"
.endif
.end start
