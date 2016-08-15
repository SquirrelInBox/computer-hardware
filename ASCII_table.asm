LOCALS
	.model	tiny
	.code
	.386
	org 100h

main:	
	call argparse
	cmp ax, 00h
	je @@next_step
	ret
	
@@next_step:
	
	;старый запомнили, поменяли режим на новый
	call get_old_mode
	call get_old_page
	xor ax, ax
	mov al, [our_vm]
	push ax
	mov al, [our_ap]
	push ax
	call change_vm
	
	;узнали, сколько колонок в строке
	mov ah, 0fh
	int 10h
	mov [col_count], ah
	call get_column
	
	call set_base_addr
	call set_offset_addr
	
	; вывели, какая сейчас страница, какой режим
	call write_header
		
	; начальный символ
	mov dl, 0
	mov temp_column, 0
	
@start:	
	mov al, dl

	call choose_color
	jmp @next

@temp_start:
	jmp @start
	
@next:
	call write_char
	
	inc offset_addr
	inc offset_addr

	inc dl	
	inc temp_column
	
	call write_space
	
	inc offset_addr
	inc offset_addr
	
	
	add color, 11h
	cmp temp_column, 7
	jne @check
	mov color, 10h
@check:	
	cmp temp_column, 14
	jne @next_s
	mov color, 10
	
@next_s:
	test dl, 15
	jne @start
	
	inc cur_str
	inc row

	mov al, [column]
	xor ah, ah
	mov bl, 4
	mul bl
	add offset_addr, ax
	mov temp_column, 0
	
	test dl, dl
	jne @temp_start
	
	mov ah, 00h
	int 16h
	
	xor ax, ax
	mov al, [old_vm]
	push ax
	mov al, [old_ap]
	push ax
	call change_vm
	
@@error:
	ret
	
write_string proc
	; в si ссылка на строку, в cx длина строки
	@@write_page:
	lodsb
	mov ah, 07h
	stosw
	loop @@write_page
	ret
write_string endp


write_number proc
	; в si ссылка на строку, в cx длина строки
	mov ah, 07h
	mov al, 30h
	stosw

	lodsb
	
	cmp al, 0ah
	jge @@more
		
	add al, 30h
	jmp @@write
@@more:
	add al, 37h
	
@@write:
	stosw
	ret
write_number endp

	
write_header proc
	push es
	pusha
	xor ax, ax

	mov ax, [base_addr]
	mov es, ax

	mov ax, [offset_addr]
	mov bl, [col_count]
	xor bh, bh
	sal	bx, 1
	sub ax, bx
	mov di, ax
	mov cx, 6
	mov si, offset page_str
	call write_string
	
	mov si, offset our_ap
	call write_number
	
	mov ax, [offset_addr]
	mov bl, [col_count]
	xor bh, bh
	sal	bx, 2
	sub ax, bx
	mov di, ax
	mov cx, 6
	mov si, offset mode_str
	call write_string
	
	mov si, offset our_vm
	call write_number 
	popa
	pop es
	ret
write_header endp
	
get_old_mode proc
	push	ax
	push	bx
	push 	ds
	
	xor		ax,ax
	mov		ds, ax
	mov 	bh, ds:449h
	
	pop 	ds
	mov 	[old_vm], bh
	pop 	bx	
	pop		ax
	ret
get_old_mode endp


get_old_page proc
	push	ax
	push 	bx
	push 	ds
	
	xor		ax,ax
	mov		ds, ax
	mov 	bh, ds:462h
	
	pop 	ds
	mov		[old_ap], bh
	pop 	bx
	pop		ax	
	ret
get_old_page endp


set_base_addr proc
	push ax
	cmp [our_vm], 7
	jne @@addr0b800
	mov ax, 0b000h
	jmp @@next
	
@@addr0b800:
	mov ax, 0b800h
	jmp @@next
	
@@next:
	mov [base_addr], ax
	pop ax
	ret
set_base_addr endp	
	

set_offset_addr proc
	push	ax
	push	bx

	xor 	ax, ax
	xor 	bx, bx
	
	mov		al, [our_ap]
	mov		bl, [our_vm]
	cmp 	bl, 01h
	jg		@@set_big_offset
	
	mov 	bx, 0800h
	mul 	bx
	jmp 	@@end

@@set_big_offset:
	mov 	bx, 1000h
	mul		bx
	jmp 	@@end

@@end:
	push 	bx
	push 	ax
	mov 	al, [row]
	mov 	bl, [col_count]
	mul 	bl
	add 	ax, word ptr [column]
	sal		ax, 1
	mov 	bx, ax
	pop 	ax
	add 	ax, bx
	
	mov		[offset_addr], ax
	pop 	bx
	
	pop		bx
	pop		ax
	ret
set_offset_addr endp	
	
	
choose_color proc
	cmp cur_str, 0
	je @firstStr
	
	cmp cur_str, 1
	jne @next_str
	cmp blink, 0
	je @secondStr
	mov bl, sec_color_b
	ret

@next_str:
	cmp cur_str, 0eh
	je @lastStr
	
	cmp cur_str, 0fh
	je @lastStr
	
	mov bl, st_color
	ret

@firstStr:
	mov bl, color
	ret

@secondStr:
	mov bl, sec_color
	ret

@lastStr:
	mov bl, last_color
	ret
choose_color endp
	
write_space proc
	mov bl, prelast_sp
	cmp cur_str, 0eh
	je @@lastStr
	
	mov bl, last_sp_col
	cmp cur_str, 0fh
	je @@lastStr
	mov bl, 00h
	jmp @@end
	
@@lastStr:
	cmp temp_column, 14
	jg @@end
	
@@end:
	mov al, 20h
	call write_char
	ret
write_space endp	

	
write_char proc
	; в bl уже лежит цвет, в al уже лежит код символа
	push cx
	push es
	push di
	
	mov cx, [base_addr]
	mov es, cx
	mov cx, [offset_addr]
	mov di, [offset_addr]
	
	mov ah, bl
	
	stosw	

	pop di
	pop es
	pop ax
	ret
write_char endp

change_vm proc
	push bp
	mov bp, sp
	push ax
	
	; в стеке vm -> ap -> bp -> ax
	mov ah, 00h
	mov al, [bp+6] ;vm
	int 10h
	
	mov ah, 05h
	mov al, [bp+4] ;ap
	int 10h
	
	pop ax
	pop bp
	ret 4
change_vm endp
	
get_column proc
	sar	ah, 1
	sub	ah, 16
	mov	column, ah
	ret
get_column endp


argparse proc
	mov al, cs:[80h]
	cmp al, 6
	jl @@incorrect_args

	mov al, cs:[82h]
	cmp al, 30h
	jne @@error_mode
	mov al, cs:[83h]
	cmp al, 30h
	je @@correct_vm
	cmp al, 31h
	je @@correct_vm
	cmp al, 32h
	je @@correct_vm
	cmp al, 33h
	je @@correct_vm
	cmp al, 37h
	je @@correct_vm
	jmp @@error_mode
	
@@correct_vm:
	sub al, '0'
	mov [our_vm], al
	
	mov al, cs:[85h]
	cmp al, 30h
	jne @@incorrect_args
	
	mov al, cs:[86h]
	mov ah, cs:[83h]
	cmp ah, 37h
	jne @@check_other
	cmp al, 30h
	jne @@incorrect_page
	sub al, '0'
	mov [our_ap], al
	jmp @end
	
@@check_other:
	cmp al, 30h
	jl @@incorrect_page
	cmp al, 37h
	jg @@incorrect_page
	sub al, '0'
	mov [our_ap], al
	jmp @end
	
	@@error_mode:
		mov ah, 9h
		lea dx, incor_mode
		int 21h
		mov ax, 01h
		ret
	
	@@incorrect_args:
		mov ah, 9h
		lea dx, help
		int 21h
		mov ax, 02h
		ret
	
	@@incorrect_page:
		mov ah, 9h
		lea dx, incor_page
		int 21h
		mov ax, 03h
		ret
		
	@end:
		mov al, cs:[80h]
		cmp al, 9
		jne @@withBlink
		mov al, cs:[88h]
		cmp al, 2fh
		jne @@incorrect_args
		mov al, cs:[89h]
		cmp al, 62h
		jne @@incorrect_args
		mov blink, 01h		
		jmp @@finish
	@@withBlink:
		mov blink, 0
	@@finish:
		mov ax, 00h
		
	ret
argparse endp


our_vm		db	?
our_ap		db	?
old_vm 		db 	?
old_ap 		db 	?
column 		db 	?
temp_column	db	?
row			db	4
color		db	10h
st_color	db	07h
sec_color	db	81h
sec_color_b	db	01h
last_color	db	4eh
cur_str		db	00h
last_sp_col	db	11h
prelast_sp	db	22h
page_str	db 	"Page: $"
mode_str	db	"Mode: $"
incor_mode	db	"Incorrect mode", 0dh, 0ah, "You can input 00, 01, 02, 03 or 07 mode", 0dh, 0ah, '$'
incor_args	db	"Incorrect args", 0dh, 0ah, '$'
help		db	"Args: [mode] [page]", 0dh, 0ah, "Mode: 00 | 01 | 02 | 03 | 07", 0dh, 0ah, '$'
incor_page	db	"Incorrect page", 0dh, 0ah, "You can input 00 page for 07 mode or 00-07 page for 00-03 mode", 0dh, 0ah, "$"
blink		db	?
base_addr	dw	?
offset_addr	dw	?
col_count	db	?

end main


; для режимов 00h, 01h размер страницы 800h
; для остальных режимов размер страницы 1000h
; для режима 07h базовый адрес 0b000h
; для остальных режимов базовый адрес 0b800h
