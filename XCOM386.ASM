;-------------------------------------------------------------------------
; XCOM - This is just a small test with the 386 debugregisters
; ml xcom.asm (no tasm yet)
;-------------------------------------------------------------------------
; 12.07.96 rar - src beautify, keyboard enabeled
; 13.07.96 rar - enhanced PMode handler!
; 28.07.96 rar - virtuell INT table (req. NO emm386 now)
;                now unpacks SYNOPSIS COM Unpacker too :)
;-------------------------------------------------------------------------
; Nach der virt. int. table suckt das Teil, warum?

;; ************************************************************************
;;
;; (C)opyright by
;;
;; ROSE, Ralph Roth                             RalphRoth@gmx.de
;; Finkenweg 24                                 http://come.to/rose_swe
;; D 78658 Zimmern o.R.
;;
;; Jedliche kommerzielle Verwendung untersagt. All Right Reserved!
;;
;; ************************************************************************


.model  tiny

.386p

TRUE    equ     0
FALSE   equ     -1

.code
org     100h
Start:

        mov     ah,4Ah

memory  equ lastbyte + 100h

        mov     bx, memory / 16
        int     21h             ; change malloc

        push    cs
        pop     es

        mov     dx,offset Intro
        Call    WriteText

        mov     si,82h
        xor     cx,cx

        mov     cl,byte ptr ds:[si-2]

        cmp     cl,3
        ja      weiteragain
        mov     dx,offset noparam
        call    WriteText
        int     20h

Weiteragain:
        mov     eax, cr0                ; emm386 there?
        and     eax, 1
        .IF     ax == 1
        mov     dx, offset EMM386
        call    WriteText
        .EXIT -1
        .ENDIF

        sub     cl,1
        mov     di,offset Filename2
        rep     movsb

        xor     al,al
        stosb

        mov     ax,3D00h
        mov     dx,offset Filename2
        int     21h
        mov     cs:Fhandle2,ax

        call    SaveInts

; ---- [ INTS ] ------------------------------------------------------------
        mov     ax,2501h
        mov     dx,offset Newint2
        int     21h

        mov     ax,2503h                ; nsp patch?
        int     21h

        mov     ax,2506h
        mov     dx,offset Critical
        int     21h

        mov     ax,250Dh
        mov     dx,offset Critical
        int     21h

        mov     ax,250Ch
        mov     dx,offset Critical
        int     21h

        mov     ah, 48h
        mov     bx, 1000h               ; 65 kb
        int     21h                     ; malloc
        jnc     mallocOK

        call    RestoreInts             ; no mem!
        int     20h

mallocOK:
        mov     word ptr cs:[Segi],ax

        mov     ds, ax
        mov     es, ax
        cld
        mov     di, 100h
        mov     cx, 0ff00h - 2          ; clean segment
        sub     ax, ax
        rep     stosb

        mov     ax,3F00h
        mov     cx, 0FF00h - 80h        ; room 4 stack
        mov     bx,word ptr cs:[Fhandle2]
        mov     dx,100h
        int     21h                     ; read handle

        push    cs
        pop     ds
        mov     dx,offset Text2
        Call    WriteText

        mov     ax,3E00h                ; close handle
        mov     bx,word ptr cs:[Fhandle2]
        int     21h

        push    segi
        pop     ds
        mov     eax, dword ptr ds:[100h]

;; Check with protector is activ!
        .IF     eax == 5d0000e8h
        mov     dx, offset fSynopsis
        call    WriteText
        .ENDIF

        xor     bx,bx
        xor     cx,cx
        xor     dx,dx
        xor     si,si
        xor     di,di
        mov     ax,word ptr cs:[Segi]
        push    ax
        pop     ds
        push    ax
        pop     es
        push    ax
        pop     ss

        push    ax
        mov     ax,100h                 ; cs:100h - com host
        push    ax
        mov     ax,256                  ; trap on
        push    ax
        popf
        xor     ax,ax
        retf                            ; first traced instruction!
; --------------------------------------------------------------------------
Newint2 proc                            ; INT 1 Handler
        cmp     word ptr cs:[Counter], 2
        jb      @ExitInt12              ; 2 instructions reichen!
        mov     word ptr cs:loc_ds,ds
        mov     word ptr cs:loc_es,es
        mov     word ptr cs:loc_bx,bx
        mov     word ptr cs:loc_dx,Dx

        mov     bx,sp
        mov     word ptr ss:[bx+4],0000h ; Flags

;; ---------------------------------------------------
        push    cs
        pop     ds
        mov     ax,2501h
        mov     dx,offset Newint1       ; set 386 brkpnt routine
        int     21h
;; ---------------------------------------------------
;; Set up new int table!
        push    eax
        push    ebx
        push    di
        push    si

        push    cs
        pop     es
        xor     ax,ax
        mov     ds,ax
        xor     si,si
        mov     di,offset oldinttab
        mov     cx,256
        rep     movsd

        xor     eax,eax
        mov     ax,cs
        shl     eax,4
        xor     ebx,ebx
        add     bx,offset oldinttab
        add     eax,ebx
        mov     dword ptr cs:idt_ptr+2,eax
        lidt    fword ptr cs:idt_ptr            ; move virt. int. tab!

        mov     cs:restoreidt, TRUE
;; ---------------------------------------------------

        mov     dx,offset text3
        Call    WriteText

; --------- 386 Debug Registers ----------------------------------------
        xor     eax,eax
        mov     dr6,eax                 ; reset
        mov     ax,word ptr cs:[Segi]
        shl     eax,4
        add     eax,100h                ; start-adr cs:100
        mov     dr0,eax                 ; use register 1

;                    L3R3L2R2L1R1LeRWxxxxxxBMGLGLGLGL
        mov     eax, 00000000000000000000001100000011y  ; exec
;       mov     eax, 00000000000101010000001100001111y
        mov     dr7,eax                 ; local enable brkpnt 1, write@byte

        pop     si                      ; restore regs
        pop     di
        pop     ebx
        pop     eax

        mov     ds,word ptr cs:[loc_ds]
        mov     es, cs:loc_es
;       mov     word ptr cs:[Counter],0         ; why?
        mov     bx,word ptr cs:[loc_bx]
        mov     dx,word ptr cs:[loc_dx]

        iret
@ExitInt12:
        inc     word ptr cs:[Counter]
        iret
Newint2 endp

WriteText proc
        push    cs
        pop     ds
        mov     ah,09h
        int     21h
        ret
WriteText endp

Critical proc                           ; int 6, 0c, 0d handler
        mov     ax, cx                  ; set new env!
        cli
        mov     ds, ax
        mov     es, ax
        mov     ss, ax
        mov     sp, -2
        sti
        call    RestoreInts
        mov     ah,09h
        mov     dx,offset Warning3
        int     21h
        call    KeyBoard                ; enable keys
        mov     ax,4c00h
        int     21h
Critical Endp

; ---------------------------------------------------------------------------
Newint1 proc                            ; Hardware breakpoint handler!
        xor     eax,eax
        mov     dr7,eax
        mov     dr0,eax
        mov     dr1,eax
        mov     dr2,eax
        mov     dr3,eax
;       mov     dr6,eax

        call    RestoreInts

        mov     dx,offset Text4
        call    WriteText

        mov     dx,offset Text5
        Call    WriteText

        mov     ax,3C00h
        mov     dx,offset Filename
        xor     cx,cx
        int     21h
        mov     word ptr cs:[Fhandle],ax

        mov     ds,word ptr cs:[Segi]
        mov     ax,4000h
        mov     bx,word ptr cs:[Fhandle]
        mov     cx,0f000h-100h          ; Length!

skip:   mov     si, cx
        cmp     word ptr ds:[si+100h], 0
        jnz     no_skip
        loop    skip
no_skip:
        mov     dx,100h
        int     21h

        mov     ax,3E00h
        mov     bx,word ptr cs:[Fhandle]
        int     21h

        mov     dx,offset Text6
        Call    WriteText

        call    KeyBoard                ; enable keys

        mov     ax, 4c00h
        int     21h

Newint1 endp

KeyBoard proc

        in      al,21h
        and     al,0fdh
        out     21h,al
        mov     al, 0aeh
        out     64h, al
        ret

KeyBoard ENDP

; ---=[ Functions ]=---------------------------------------------------
restoreints:
.IF restoreidt == TRUE
        lidt    fword ptr cs:old_idt    ; restore old int tab
.ENDIF
        push    cs
        pop     ds
        push    0
        pop     es
        xor     di,di
        mov     si,offset inttab
        mov     cx,100h
        cld
        rep     movsd
        push    cs
        pop     ds
        push    cs
        pop     es
        ret
; ---=[ Functions ]=---------------------------------------------------
saveints:
pusha
        push    ds
        pop     es
        push    0
        pop     ds
        xor     si,si
        mov     di,offset inttab        ;ES points to DATA
        mov     cx,100h                 ;komplette int-tab
        cld
        rep     movsd
popa
        sti
        push    cs
        pop     ds
        push    cs
        pop     es
        ret

;; ------------------------------- D A T A --------------------------
.data
Counter dw      0
Fhandle dw      ?
Fhandle2 dw     ?
Segi    dw      ?
loc_ds  dw      ?
loc_es dw       ?
loc_bx dw      ?
loc_dx dw      ?
;OldInt1 dd      ?
Filename db     "XCOM_OUT.COM",0
Filename2 db    "            ",0
Intro   db      " -=þ X-C0M GENERiC C0MFiLE UNPACKER BY RANDOM (c) xADI 1996! þ=- ",0dh,0ah,"  ÍÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÍ",0dh,0ah
        db      "    386pm Unpacker - All bugs done by ROSE SWE, Ralph Roth :)",13,10,13,10,"$"
NoParam db      "    þ Syntax: XCOM <filename.com> ",0ah,0dh,7,"$"
Text2   db      "    þ Opening da filez",0ah,0dh,"$"
Text3   db      "    þ Setting 386 break point (tracer is activ)",0ah,0dh,"$"
Text4   db      "    þ 386 break point reached...",0ah,0dh,"$"
Text5   db      "    þ Now saving comfile to disk",0ah,0dh,"$"
Text6   db      "    þ File saved (XCOM_OUT.COM)! Unpacked?",0ah,0dh,"$"

Warning3 db     "    þ ERROR! Reached an invalid instruction! PMode protection fault!",0ah,0dh,7h,"$"
Warning4 db     "    þ ERROR! Can't open this file!",0ah,0dh,"$"
EMM386 db       "    þ ERROR! Requires real mode (reboot WITHOUT EMM386)!", 7, 10, 13, "$"
fSynopsis db    "    þ Found Synopsis COM-Packer!", 10, 13, "$"

restoreidt      dw FALSE
oldinttab  dd 256 dup (0)
idt_ptr dw 3ffh,0,0,0
old_idt dw 3ffh,0,0,0

inttab  dd      100h dup (?)

lastbyte equ    $
End     Start
