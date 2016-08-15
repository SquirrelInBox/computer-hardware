LOCALS
	.model	tiny
	.code
	.386
	org 100h
	
START:

	jmp	main
print_symb proc
	; в dl символ
    pusha
    mov     ah, 02h
    int 21h
    popa
	
	ret
print_symb endp

write_symb proc
	; в al ascii-код
	pusha
	mov 	ah, 0ah
	mov 	cx, 1
	mov 	bh, [cur_page]
	int 10h
	popa
	ret
write_symb endp

write_num proc
	pusha
	push 	-1
	mov 	bx, 10h
	mov 	cx, 0002h
	xor 	dx, dx
	@@loop1:
		div 	bl
		mov 	dx, ax
		xor 	al, al
		xchg	ah, al
		push 	ax
		mov		al, dl
		dec 	cx
		cmp 	cx, 0
		jne 	@@loop1

	mov cx, 0002h
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
	popa
	ret
write_num endp


write_tab proc
	pusha
	
	mov ah, 02h
	mov dl, 09h
	int 21h
	
	popa
	ret
write_tab endp

write_new_line proc
	pusha
	mov 	dl,	0ah
	call 	print_symb
	mov		dl, 0dh
	call	print_symb
	popa
	ret
write_new_line endp

main:

	mov ah, 0fh
    int 10h
    mov [cur_page], al
	
	mov 	ah, 09h
	lea 	dx, header
	int 21h
	
new_iter:

	mov		ah, 10h
	int 16h
	
	; ESC code
	mov 	bx, 011bh
	cmp 	ax, bx
	je 		@@end
	
	call write_new_line	
	call write_tab
	
	mov 	bx, ax
	xchg	ah, al
	xor 	ah, ah
	call 	write_num
	
	call 	write_tab
	call 	write_tab
	
	mov 	ax, bx
	xor 	ah, ah
	call 	write_num
	
	call 	write_tab
	call 	write_tab
	
	
	mov 	dl, al
	call 	print_symb
	
	
@@iter_end:
	jmp		new_iter
	
@@end:
ret

header		db	"    ASCII-code	    SCAN-code	    Symbol$"
spec		db	"Spec symb", 0ah, 0dh, '$'
cur_page	db	?


end START