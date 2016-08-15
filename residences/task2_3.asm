; защита при повторной установке (2х этапная проверка, что это мы)
; резидент говорит, что его можно выгружать. Выгружает основная программа
; 49h функция вызывается дважды
; цепочка обработчика прерываний (в векторе прерываний сидит наш адрес - тогда можно удалять)
; записать адрес в нижнюю часть ОП, чтобы никто не вклинился, используем CLI
; STI разрешение командных прерываний

LOCALS

model tiny
.code
org 100h

start:

jmp main					; перепрыгиваем все процедуры
					dw	2145h	; сказали в памяти, что это мы
	oldVec2f		dd	0

	
my_handler proc 			; наш обработчик
	cmp ax, 88f8h			; если пришло то, что надо
							; с нужным магическим числом и функцией
	jne @@end
	
	cmp dx, 88ffh
	jne @@end
	
	mov ax, error_code_ok  	; выставляем код, что резидент наш
	xchg dh, dl
@@end:
	iret
my_handler endp


get_old_2f proc
	push ax
	mov ax, 352fh				
	int 21h
	pop ax
ret
get_old_2f endp


set_int proc  					; ставим свой обработчик my_handler на вектор 2fh
	call get_old_2f				; узнали старый вектор 2fh
	mov	word ptr [oldVec2f], bx
	mov	word ptr [oldVec2f+2], es	; записали вектор в переменную
	mov ah, 25h
	mov al, 2fh
	mov dx, offset my_handler
	int 21h
ret
set_int endp

del_int proc
	mov ax, 352fh
	int 21h
	cmp word ptr es:[bx-6], 2145h
	jne @@end

	push ds
	mov dx, word ptr es:[bx-4]
	mov ax, word ptr es:[bx-2]
	mov ds, ax	
	mov ax, 252fh
	int 21h
	pop ds
	
	push es
	mov ax, es:[2ch]
	mov es, ax
	mov ah, 49h
	int 21h
	pop es

	mov ah, 49h
	int 21h
	mov ax, 0h
	ret
@@end:
	mov ax, 0ffffh
ret
del_int endp


main:  						; здесь все начинается
jmp new_start

get_nums proc
	push -1
	mov bx, 10h
	@@loop1:
		xor dx, dx
		div bx
		push dx	
		cmp ax, 0
		jne @@loop1

	xor cx, cx
	mov cx, 4
	xor dx, dx
	@@loop:
		pop dx
		cmp dx, -1
		je @@end
		
		cmp dl, 0ah
		jge @@more
		
		add dl, 30h
		jmp @@write
	@@more:
		add dl, 37h
		
	@@write:
		mov ah, 02h
		int 21h
	jmp @@loop
@@end:
ret
get_nums endp

next_line proc
	mov ah, 09h
	lea dx, nl
	int 21h
ret
next_line endp

colon proc
	mov ah, 02h
	mov dl, 3ah
	int 21h
ret
colon endp

write_current_addr proc
	mov ax, 352fh
	int 21h
	
	mov ax, es
	;mov ax, offset my_handler
	call get_nums
	
	call colon
	
	mov ax, bx
	;mov ax, ds
	call get_nums
ret
write_current_addr endp

finish proc
	push ds
	mov dx, word ptr[oldVec2f]
	mov ds, word ptr [oldVec2f + 2]
	
	mov ax, ds	
	call get_nums
	
	call colon

	mov ax, dx
	call get_nums
	pop ds
	
	call next_line
	
	call write_current_addr
	
ret
finish endp


new_start:
get_args:  					; надо прочитать ключи
	xor cx, cx
	mov cx, cs:[80h]
	sub cx, 2000h
	dec cx
	
	xor bx, bx
	mov si, 82h  			; адрес первого символа в аргументе
	mov bx, 2fh  			; код слеша
	cmp [si], bl
	jne bad  				; первый символ не наш - все плохо
	dec cx
	jmp ok
	
bad:
	jmp afail
ok:
	inc si
	
	xor bx, bx
	mov bx, 31h  			; код единицы
	cmp[si], bl
	je is_end_r2  			; прочитали строку /1 - первый ключ
	
	xor bx, bx
	mov bx, 64h  			; код единицы
	cmp[si], bl
	je is_end_del
	
	jmp afail 				; плохой аргумент
	
is_end_r2:
	dec cx
	cmp cx, 0
	je r2
	jmp afail

is_end_del:
	dec cx
	cmp cx, 0
	je del
	jmp afail
	
r2:
	mov ah, magic_num
	mov al, magic_func
	mov dx, magic_num_dx 
	int 2fh
	cmp ax, error_code_ok
	jne set
	
	cmp dx, 0ff88h
	je installed
	
set:
	call set_int
	
	call finish
	mov ah, 31h 			; ставим резидента с помощью 31h функции
	mov al, 00h 			; код возврата 
	mov bx, offset main
	sub bx, offset start
	add bx, 0fh
	sar bx, 4
	add bx, 10h
	
	mov dx, bx ;(offset r2 - offset start + 15)/16 + 1	; сколько параграфов поделить сдвигом вправо
	int 21h

del:
	call del_int
	cmp ax, 0ffffh
	je del_not
	mov ah, 9h
	lea dx, msg_del
	int 21h
	ret
del_not:
	mov ah, 9h
	lea dx, msg_del_not
	int 21h
	ret


afail: 						; если неправильный аргумент
	mov ah, 9h
	lea dx, argmess
	int 21h
	ret	


	
installed:					; если резидент уже загружен
	call write_current_addr
	ret


	magic_num		db	88h	
	magic_func		db	0f8h
	magic_num_dx	dw	88ffh
	error_code_ok	dw	0ffh
	argmess			db	"Error: Incorrect args",	0dh, 0ah, '$'
	msg_del 		db 	"Deleted", 					0dh, 0ah, '$'
	msg_del_not 	db 	"Can't delete", 			0dh, 0ah, '$'
	nl				db								0dh, 0ah, '$'
end start

; почему если в write_current_addr выводить закомментированное, то ответ на повтор будет отличаться