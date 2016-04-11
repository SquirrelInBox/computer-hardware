model tiny
.code
org 100h

start:

jmp main					; перепрыгиваем все процедуры

my_handler proc 			; наш обработчик
	cmp ax, 80f0h			; если пришло то, что надо
							; с нужным магическим числом и функцией
	jne @end
	mov ax, error_code_ok  	; выставляем код, что резидент наш
@end:
	iret
my_handler endp


set_int proc  				; ставим свой обработчик my_handler на вектор 2fh
	mov ah, 25h
	mov al, 2fh
	mov dx, offset my_handler
	int 21h
ret
set_int endp

main:  						; здесь все начинается

get_args:  					; надо прочитать ключи
	xor cx, cx
	mov cx, cs:[80h]
	sub cx, 2000h
	dec cx
	
	xor bx, bx
	mov si, 82h  			; адрес первого символа в аргументе
	mov bx, 2fh  			; код слеша
	cmp [si], bl
	jne afail  				; первый символ не наш - все плохо
	dec cx
		
	inc si
	xor bx, bx
	mov bx, 30h 			; код нуля
	cmp [si], bl
	je is_end_r1 			; прочитали строку /0 - первый ключ 
	
	xor bx, bx
	mov bx, 31h  			; код единицы
	cmp[si], bl
	je is_end_r2  			; прочитали строку /0 - первый ключ
	jmp afail 				; плохой аргумент

is_end_r1:
	dec cx
	cmp cx, 0
	je r1
	jmp afail
	
is_end_r2:
	dec cx
	cmp cx, 0
	je r2
	jmp afail
	
	
r1:
	mov ah, magic_num  		; говорим, что это мы
	mov al, magic_func  	; c нашей магической функцией
	int 2fh  				; вызываем обработчик
	cmp ax, error_code_ok  	; если обработчик был наш, то ответы совпадут
	je installed  			; значит уже поставили
	
	call set_int  			; вешаем своего обработчика на int 2fh
	
	mov dx, offset r1 + 1  	; что загрузить 
	int 27h  

r2:
	mov ah, magic_num
	mov al, magic_func
	int 2fh
	cmp ax, error_code_ok
	je installed
	
	call set_int

	mov ah, 31h 			; ставим резидента с помощью 31h функции
	mov al, 01h 			; код возврата 
	mov dx, 1 				; сколько параграфов
	int 21h


afail: 						; если неправильный аргумент
	mov ah, 9h
	lea dx, argmess
	int 21h
	ret	
	
installed:					; если резидент уже загружен
	mov ah, 9h
	lea dx, msg_n_inst
	int 21h
	ret

finish:						; если только загрузили резидента
	mov ah, 9h
	lea dx, msg_inst
	int 21h
	ret	

magic_num		db	80h
magic_func		db	0f0h
error_code_ok	dw	0ffh
argmess			db	"Error: Incorrect args",	24h
msg_n_inst		db	"Allready installed", 		0dh, 0ah, '$'
msg_inst 		db 	"Resident installed", 		0dh, 0ah, '$'
end start

; Через int 21h функцию 31h можно загружать в память exe файлы
; Для int 27h ограничен размер загружаемого резидента - 64кб
; int 31h сразу завершит работу программы и не всю программу в памяти, а сколько параграфов укажешь
