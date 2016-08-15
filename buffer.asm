LOCALS
	.model	tiny
	.code
	org 100h

main:
	; max длина буфера = 6
	mov [buff], 7
	
	mov ah, 0ah
	mov dx, offset buff
	int 21h
	
	; или в начало записать 0ah, в конец - "$"
	mov cl, [buff + 1]
	mov al, '$'
	xor ch, ch
	push di
	add cx, 2
	mov di, offset buff
	add di, cx
	stosb
	
	mov di, offset buff
	mov al, 0ah
	stosb
	
	mov di, offset buff + 1
	mov al, 0dh
	stosb
	
	pop di
	
	mov ah, 09h
	lea dx, buff
	int 21h
		
	ret
	
buff	db 9 dup(0)
end main