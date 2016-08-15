.model tiny
.code
org 100h

@main:
		xor bl, bl
@start:

        mov ah, 02h
        mov dl, bl
        int 21h

        inc bx
        test bl, 15  ; в bl находится что-то кратное 16 => переходим
        jne @start
		
        mov dl, 0ah
        int 21h
        mov dl, 0dh
        int 21h

		test bl, bl  ; в bl должно оказаться 0, в bh что-то > 0
        jne @start

        ret
end @main