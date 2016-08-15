model tiny
.code
org 100h
locals
.186

_1:
    jmp     start

buff    db    10 dup (0)
head    dw    offset buff
tail    dw    offset buff

save_buff   proc    near
    ; Пишем в голову, читаем с хвоста
    mov     di, head
    mov     bx, di
    inc     bx
    cmp     bx, offset head           ; случай переполнения, именно так, потому что head
                                      ; сразу за буфером
    jnz      @@1
    mov     bx, offset buff
@@1:
    cmp     bx, tail
    jz      @@2
    stosb
    mov     head, bx
@@2:
    ret
save_buff   endp

int9  proc  far
    push  ax
    push  bx
    push  di
    push  ds
    push  es

    ; чтобы находились в одном сегменте, т.к. значения cs, ds нам не
    ; гарантированы
    push  cs
    pop   ds
    push  cs
    pop   es

    in    al, 60h           ; здесь символ только читаем, но не извлекаем
    call  save_buff
    ; Говорим клавиатурному обработчику, что символ получили и обработали
    in    al, 61h           ; 61 - порт состояния
    mov   ah, al
    or    al, 80h           ; установили флаг обработанности (старший бит в 61 порту)
    out   61h, al           ; выдали снова в 61 порт
    mov   al, ah
    out   61h, al
    ;mov   al, 20h          ; говорим контроллеру прер, что мы закончили обрабатывать
    ;out   20h, al          ; прерываний
                            ; здесь работает и так, тк контроллер клавиатуры
                            ; делает за нас эту работу после группы команд выше
    ; закончили обработку символа

    pop   es
    pop   ds
    pop   di
    pop   bx
    pop   ax
    iret
int9  endp

int9_off      dw        0
int9_seg      dw        0

start:
    xor       ax, ax
    push      ax
    pop       ds
    mov       si, 9*4
    mov       di, offset int9_off
    movsw
    movsw

;   адрес своего обработчика записываем по адресу
    push      ds
    pop       es
    push      cs
    pop       ds

    mov       di, 9*4
    mov       ax, offset int9
    cli
    stosw
    mov       ax, cs
    stosw
    sti
    push      cs
    pop       es
@@1:
    hlt                         ; чтобы не перегревался процессор
    mov       si, tail
    cmp       si, head
    jz        @@1
    lodsb                       ; в al теперь наш символ
    inc       tail
    cmp       tail, offset head     ; если достигли конца, закольцовываем буфер
    jnz       @@2
    mov       tail, offset buff
@@2:
    push      ax
    shr       al,4
    call      tohex
    mov       di, offset bbb
    stosb
    pop       ax
    push      ax
    call      tohex
    stosb
    mov       ah, 9
    mov       dx, offset bbb
    int       21h
    pop       ax
    cmp       al, 81h
    jz       @@3
    cmp       al, 0b9h
    jnz       @@1                   ; не каждое нажатие клавиши = 2 скан кода
    mov       ah, 9
    mov       dx, offset ccc
    int       21h
    jmp       @@1

@@3:
    mov       si, offset   int9_off
    mov       di, 9*4
    xor       ax, ax
    push      ax
    pop       es
    cli
    movsw
    movsw
    sti
    push      cs
    pop       es
    ret

tohex:
    and       al, 0fh
    cmp       al, 10
    sbb       al, 69h
    das
    ret

bbb     db    0,0,0dh,0ah,24h
ccc     db    '==============', 0dh, 0ah, 24h
end     _1
