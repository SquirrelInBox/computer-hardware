.model tiny
.code
org 100h
.386

start:
	jmp	main
	
ext_flag db 00
play db 14 dup(0)
notes dw 4559, 4062, 3620, 3417, 3044, 2712, 2416, 2279, 2031, 1810, 1708, 1522, 1356, 1208
sound_on_command db 00  
sound_off_command db 00
sync db 00

sounds dw 3225, 3044, 2712, 2416, 3044, 3620, 2416, 2712, 3044, 3255, 3044, 2712, 2416, 3044, 3620, 3620, 40, 2280, 2712, 1810, 2032, 2280, 2416, 2280, 2416, 2712, 3044, 3225, 3044, 2712, 2416, 3044, 3620, 3620 
sound_times db 9, 3, 6, 6, 6, 6, 6, 3, 3, 9, 3, 6, 6, 6, 3, 9, 3, 9, 3, 6, 3, 3, 9, 3, 6, 3, 3, 9, 3, 6, 6, 6, 6, 12 
sound_size db 34
cur_melody	db	?
	
m08_handler:
	pusha
	
	mov al, sync
	test al, al
	jnz old_08_handler

	mov ax, offset play
	mov si, ax
	mov cx, 14
	xor bx, bx

check_next_note:
	lodsb
	cmp al, 1
	jz after_check
	inc bx
	loop check_next_note

after_check:
	cmp bx, 14
	jnz need_play_sound

	mov   al, sound_off_command
	out   61h, al

	jmp old_08_handler

need_play_sound:
	mov ax, bx
	add ax, bx						; bx * 2 - размер ноты dw

	add ax, offset notes
	mov si, ax
	lodsw

	out 42h, al
	mov al, ah
	out 42h, al

	mov al, sound_on_command
	out 61h, al
	
old_08_handler:
	popa
old_08_code db 0eah, 00, 00, 00, 00


melody_play proc
	in al, 61h                   ;получаем текущий статус
	or al,00000011b              ;разрешаем динамик и таймер 
	out 61h, al               ;заменяем байт  
	mov si, 0                          ;инициализируем указатель 
	mov al, 10110110b              ;установка для канала 2 
	out 43h, al ;посылаем в командный регистр 
	mov cur_melody, 1
	
	
;---смотрим ноту, получаем ее частоту и помещаем в канал 2 
next_note: 
	mov al, cur_melody
	inc cur_melody
	cmp al, sound_size
	je no_more
	cbw                    ;переводим в слово 
;---получение частоты 
	mov bx,offset sounds;смещение таблицы частот 
	dec ax                                      ;начинаем отсчет с 0 
	shl ax,1                                   ;умножаем на 2, т.к. слова 
	mov di,ax                                ;адресуем через DI 
	mov dx,[bx][di]                       ;получаем частоту из таблицы 
;начинаем исполнение ноты    
	mov al, dl                 ;готовим младший байт частоты 
	out 42h, al          ;посылаем его 
	mov al,dh                 ;готовим старший байт частоты 
	out 42h, al          ;посылаем его  
;---создание цикла задержки   
	mov ah,0                          ;номер функции чтения счетчика 
	int 1ah                             ;получаем значение счетчика 
	mov bx,offset sound_times     ;смещение таблицы длин 
	mov cl,[bx][si]               ;берем длину очередной ноты 
	mov ch,0 
	mov bx,dx                      ;берем младшее слово счетчика 
	add bx,cx                       ;определяем момент окончания 
still_sound: 
	int 1ah                          ;берем значение счетчика
	cmp dx,bx                    ;сравниваем с окончанием 
	jne still_sound          ;неравны-продолжаем звук
	inc si                             ;переходим к следующей ноте
	jmp next_note            ;
;---завершение 
no_more: 
	in al, 61h   ;полчаем статус порта В
	and al,	11111100b    ;выключаем динамик
	out 61H,al
	ret
melody_play endp


m09_handler:
	pusha

	mov al, sync
	test al, al
	jnz out_of_keyboard
	mov sync, 1

	in al, 60h
	push ax
	
	in al, 61h
	mov ah, al
	or al, 80h
	out 61H, al
	xchg ah, al
	out 61H, al

	pop ax

	cmp al, 1
	jnz non_esc
	mov ext_flag, 1
	jmp interrupt_end
	
	
non_esc:
	cmp al, 39h
	jnz non_melody
	call melody_play
	jmp interrupt_end
	
non_melody:

	cmp al, 1eh
	jl not_push
	cmp al, 24h
	jg not_push

	

next_step:	
	
	sub al, 1eh
	mov dx, ax
	
	xor ah, ah
	add ax, offset play
	mov si, ax
	lodsb
	
	test al, al

	jnz interrupt_end
	mov ax, dx

	push ax
	mov ax, offset play
	mov si, ax
	mov di, ax
	mov cx, 14
	
inc_all_plays:
	lodsb
	test al, al
	jz temp_1
	inc al

temp_1:
	stosb
	loop inc_all_plays
	pop ax

	;sub al, 1eh
	
	xor ah, ah
	add ax, offset play
	mov di, ax
	mov al, 1
	stosb

	jmp interrupt_end

not_push:
	cmp al, 2ch
	jl not_new_push
	cmp al, 32h
	jg not_new_push
	sub al, 7h
	jmp next_step
	
not_new_push:
	cmp al, 0ach
	jl not_new_non_push
	cmp al, 0b3h
	jg not_new_non_push
	sub al, 7h
	jmp next_non_push
	
not_new_non_push:

	cmp al, 9eh
	jl old_keyboard_handler
	cmp al, 0a4h
	jg old_keyboard_handler
	
next_non_push:
	sub al, 9eh
	xor ah, ah
	add ax, offset play
	mov si, ax
	mov di, ax

	lodsb
	mov dl, al
	xor al, al
	stosb
	
	mov ax, offset play
	mov si, ax
	mov di, ax
	mov cx, 14

dec_all_plays:
	lodsb
	test al, al
	jz temp_2
	cmp al, dl
	jl temp_2

	dec al

temp_2:
	stosb
	loop dec_all_plays

interrupt_end:
	mov	al, 20h
	out	20h, al

	popa
	mov sync, 0
	iret

old_keyboard_handler:	
	mov sync, 0
out_of_keyboard:
	popa
old_09_code db 0eah, 00, 00, 00, 00

main:
	mov al, 10110110b  ; 2 канал, 3 режим
	out 43h, al  ; установили его

	in al, 42h  
	mov sound_off_command, al
	or al, 3
	mov sound_on_command, al
	
	push es
	mov ah, 35h
	mov al, 09h
	int 21h
	mov word ptr old_09_code + 1, bx
	mov word ptr old_09_code + 3, es
	mov dx, offset m09_handler
	mov ah, 25h
	mov al, 09h
	int 21h
	
	mov ah, 35h
	mov al, 08h
	int 21h
	mov word ptr old_08_code + 1, bx
	mov word ptr old_08_code + 3, es
	mov dx, offset m08_handler
	mov ah, 25h
	mov al, 08h
	int 21h
	pop es
	
main_loop:
	mov al, ext_flag
	test al, al
	jz main_loop
	
	push ds
	mov dx, word ptr old_08_code + 1
	mov ds, word ptr old_08_code + 3
	mov ah, 25h
	mov al, 08h
	int 21h
	pop ds

	push ds
	mov dx, word ptr old_09_code + 1
	mov ds, word ptr old_09_code + 3
	mov ah, 25h
	mov al, 09h
	int 21h
	pop ds

	mov   al, sound_off_command
	out   61h, al

	mov ax, 4c00h
	int 21h
end start
