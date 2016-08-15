locals
.model tiny
.code
org 100h
.386


start:
jmp main

delay		db	12h
cur_teak	db	0h

sounds 		dw 	3225, 3044, 2712, 2416, 3044, 3620, 2416, 2712, 3044, 3255, 3044, 2712, 2416, 3044, 3620, 3620, 40;, 2280, 2712, 1810, 2032, 2280, 2416, 2280, 2416, 2712, 3044, 3225, 3044, 2712, 2416, 3044, 3620, 3620 
sound_times db 	9, 3, 6, 6, 6, 6, 6, 3, 3, 9, 3, 6, 6, 6, 3, 9, 3;, 9, 3, 6, 3, 3, 9, 3, 6, 3, 3, 9, 3, 6, 6, 6, 6, 12 
sound_size 	db 	17
cur_melody	db	?

m08_handler proc
	inc cur_teak	
	iret
m08_handler endp

get_dir_head proc
	mov bl, head_y
	xor bh, bh
	
	mov cl, head_x
	xor ch, ch

	push ds si
	mov ax, 0A000h
	mov ds, ax
	mov ax, 320
	mul bx
	add ax, cx
	mov si, ax
	lodsb
	pop si ds
	ret
get_dir_head endp
	

move_snake proc
	mov cl, head_x
	mov dl, head_y
	xor ch, ch
	xor dh, dh
	mov ah, 0ch
	mov al, direct
	mov bh, 01h
	int 10h

	cmp direct, 4
	jne @@is_up
	sub head_x, 1
	inc found_next_step
	jmp @@end
@@is_up:
	cmp direct, 1
	jne @@is_right
	sub head_y, 1
	inc found_next_step
	jmp @@end

@@is_right:
	cmp direct, 2
	jne @@down
	add head_x, 1
	inc found_next_step
	jmp @@end
@@down:
	add head_y, 1
	inc found_next_step
@@end:

	call get_dir_head
	
	; бетонный пол?
	cmp al, 08h
	je @@set_end
	
	; артефакт с увеличением длины?
	cmp al, 09h
	jne @@next
	inc food_count
	inc found_incr_food
	inc snake_length
	call draw_head
	jmp @@end_t
@@set_end:
	mov ext_flag, 1
	jmp @@end_t
@@next:
	; артефакт, который убил?
	cmp al, 0ch
	jne @@not_kill
	inc food_count
	jmp @@set_end
	
@@not_kill:
	;нашли ли уменьшающий артефакт
	cmp al, 0eh
	jne @@non_art
	inc food_count
	inc found_dec_food
	dec snake_length
	cmp snake_length, 0
	je @@set_end
	
	call draw_head
	call draw_tail
	call move_tail
	jmp @@draw_tail

@@non_art:
	; эластичная стенка?
	cmp al, 0bh
	jne @@non_elastic
	inc found_elastic_wall
	call turn_snake
	call draw_head
	jmp @@end_t
	
@@non_elastic:
	; портал?
	cmp al, 0dh
	jne @@non_portal
	inc found_portal
	call handle_portal
	

@@non_portal:
	cmp al, 04h
	je @@self_inter
	cmp al, 01h
	je @@self_inter
	cmp al, 02h
	je @@self_inter
	cmp al, 03h
	je @@self_inter
	jmp @@next_step
	
@@self_inter:
	cmp for_inter, 00h
	je @@set_end
	cmp for_inter, 01h
	je @@cut_tail
	jmp @@set_end
@@cut_tail:
	call cut_tail
	jmp @@end_t
@@next_step:
	call draw_head

@@draw_tail:
	
	call draw_tail
	call move_tail
	
@@end_t:
	
	ret
move_snake endp

cut_tail proc
	push ax
@@loop:
	dec snake_length
	
	mov al, tail_x
	cmp al, head_x
	jne @@next_step
	mov al, tail_y
	cmp al, head_y
	je @@end
@@next_step:	
	call draw_tail
	call move_tail
	jmp @@loop

@@end:	
	pop ax
	call draw_tail
	call move_tail
	call draw_head
	ret
cut_tail endp

handle_inter proc
	
	ret
handle_inter endp

handle_portal proc
	cmp direct, 04h
	je @@correct_direct
	cmp direct, 02h
	je @@correct_direct
	jmp @@end
	
@@correct_direct:
	mov al, tail_y
	mov ah, tail_x
	call del_old_snake
	call move_map

	mov al, head_y
	mov tail_y, al
	cmp direct, 04h
	jne @@non_left
	mov tail_x, 62
	mov bh, 62
	sub bh, snake_length
	mov head_x, bh
	jmp @@end
@@non_left:
	mov tail_x, 15
	mov bh, 15
	add bh, snake_length
	mov head_x, bh

@@end:
	call draw_new_snake
	ret
handle_portal endp

draw_new_snake proc
	mov al, head_y
	mov ah, head_x
	push ax

	mov bl, tail_x
	mov head_x, bl
	mov bl, tail_y
	mov head_y, bl
@@loop:	
	push ax
	call draw_head
	xor cx, cx
	xor dx, dx
	mov cl, head_x
	mov dl, head_y
	mov ah, 0dh
	mov bh, 01h
	int 10h
	
	cmp al, 04h
	jne @@not_left
	dec head_x
	jmp @@end
@@not_left:
	cmp al, 02h
	jne @@end
	inc head_x
@@end:	
	pop ax
	cmp ah, head_x
	jne @@loop
	cmp al, head_y
	jne @@loop
	
	pop ax
	mov head_y, al
	mov head_x, ah
	ret
draw_new_snake endp

del_old_snake proc
@@loop:
	mov al, tail_x
	cmp al, head_x
	jne @@next_step
	mov al, tail_y
	cmp al, head_y
	je @@end
@@next_step:
	call draw_tail
	call move_tail
	
	jmp @@loop
@@end:
	ret
del_old_snake endp

move_map proc
	mov dl, head_y
	cmp direct, 04h
	je @@left
	cmp direct, 02h
	je @@right
	
@@left:
	mov dh, 62
	jmp @@next
	
@@right:
	mov dh, 15
	jmp @@next
@@next:
	mov cl, snake_length
	xor ch, ch
@@loop:
	push cx dx
	mov cl, dh
	xor dh, dh
	mov al, direct
	mov bh, 01h
	mov ah, 0ch
	int 10h
	pop dx cx
	cmp direct, 04h
	je @@add_left
	inc dh
	jmp @@t_end
@@add_left:
	dec dh
@@t_end:
	loop @@loop
	ret
move_map endp

turn_snake proc
	pusha
	mov cl, tail_x
	xor ch, ch
	mov dl, tail_y
	xor dh, dh
	mov ah, 0dh
	mov bh, 01h
	
	int 10h
	
	mov direct, al
	cmp direct, 04h
	jne @@not_left
	mov direct, 02h
;	inc tail_x
	jmp @@next
	
@@not_left:
	cmp direct, 01h
	jne @@not_up
	mov direct, 03h
;	inc tail_y
	jmp @@next
	
@@not_up:
	cmp direct, 02h
	jne @@not_right
	mov direct, 04h
;	dec tail_x
	jmp @@next
	
@@not_right:
	cmp direct, 03h
	jne @@next
	mov direct, 01h
;	dec tail_y

	mov ah, 0ch
	mov al, direct_tail
	mov cl, tail_x
	xor ch, ch
	mov dl, tail_y
	xor dh, dh
	mov bl, 01h
	int 10h


@@next:
	inc head_x
	mov al, head_x
	mov ah, tail_x
	mov head_x, ah
	mov tail_x, al

	mov al, head_y
	mov ah, tail_y
	mov head_y, ah
	mov tail_y, al
	
	call redraw_path	
	
	popa
	ret
turn_snake endp


redraw_path proc
	; изменить направление в стартовой клетке, начальное направление запомнить
	
	mov cl, head_x
	xor ch, ch
	mov dl, head_y
	xor dh, dh
	call get_dir
	mov bh, head_x
	mov bl, head_y
	call turn_dir1
	
@@loop:
	xor cx,cx
	xor dx,dx
	mov cl, bh
	mov dl, bl
	call get_next_coords
	
	push ax ; предыдущее направление
	
	xor cx,cx
	xor dx,dx
	mov cl, bh
	mov dl, bl
	call get_dir
	
	mov bh, cl
	mov bl, dl
	
	xchg dx, ax ; временно сохранили текущее направление 
	pop ax ; предыдущее направление
	
	call turn_dir1
	
	mov ax, dx ; вернули текущее направление
	
	cmp bh, tail_x
	jne @@loop
	cmp bl, tail_y
	jne @@loop
 	
	ret
redraw_path endp

get_dir proc
	; (cx, dx) - текущие координаты
	mov ah, 0dh
	mov bh, 01h
	int 10h
	ret
get_dir endp

get_next_coords proc
	; al - текущее направление, (cx, dx) - текущие координаты
	; (bh, bl) - новые координаты
	mov bh, cl
	mov bl, dl
	
	cmp al, 04h
	jne @@not_left
@@left:
	dec bh
	jmp @@end
@@not_left:
	cmp al, 01h
	jne @@not_up
@@up:
	dec bl
	jmp @@end
@@not_up:
	cmp al, 02h
	jne @@not_right
	inc bh
	jmp @@end
@@not_right:
	cmp al, 03h
	jne @@end
	inc bl
	jmp @@end
	
@@end:	
	ret
get_next_coords endp

turn_dir1 proc
	; al - предыдущее направление, (bh, bl) - текущие координаты
	pusha
	
	cmp al, 04h
	jne @@not_left
@@left:
	mov al, 02h
	jmp @@change
@@not_left:
	cmp al, 01h
	jne @@not_up
@@up:
	mov al, 03h
	jmp @@change
@@not_up:
	cmp al, 02h
	jne @@not_right
	mov al, 04h
	jmp @@change
@@not_right:
	cmp al, 03h
	jne @@end
	mov al, 01h
	jmp @@change
	
@@change:
	xor cx, cx
	xor dx, dx
	mov cl, bh
	mov dl, bl
	
	mov ah, 0ch
	mov bh, 01h
	
	int 10h
@@end:
	popa
	ret
turn_dir1 endp


move_tail proc
	mov cl, tail_x
	mov dl, tail_y
	xor ch, ch
	xor dh, dh
	mov ah, 0dh
	mov bh, 01h
	
	push bx cx dx
	
	int 10h
	
	pop dx cx bx
	
	mov direct_tail, al
	
	mov cl, tail_x
	mov dl, tail_y
	xor ch, ch
	xor dh, dh
	mov ah, 0ch
	mov al, 05h
	mov bh, 01h
	int 10h
	
	cmp direct_tail, 4
	jne @@is_up_t
	sub tail_x, 1
	jmp @@end_t
@@is_up_t:
	cmp direct_tail, 1
	jne @@is_right_t
	sub tail_y, 1
	jmp @@end_t

@@is_right_t:
	cmp direct_tail, 2
	jne @@down_t
	add tail_x, 1
	jmp @@end_t
@@down_t:
	add tail_y, 1
@@end_t:
	ret
move_tail endp

draw_head proc
	mov al, head_x
	mov bl, 05h
	mul bl
	mov start_x, ax
	mov al, head_y
	mul bl
	mov start_y, ax
	
	mov ax, snake_point_size
	mov cur_point_size, ax
	
	mov al, snake_color
	mov cur_color, al

	call draw_point
	ret
draw_head endp

draw_tail proc
	mov al, tail_x
	mov bl, 05h
	mul bl
	mov start_x, ax
	mov al, tail_y
	mul bl
	mov start_y, ax
	
	mov ax, snake_point_size
	mov cur_point_size, ax
	
	mov al, 00h
	mov cur_color, al

	call draw_point
	ret
draw_tail endp


m09_handler proc
	pusha
	in al, 60h
	
	cmp al, 1
	jnz non_esc
	mov ext_flag, 1
	jmp interrupt_end
	
non_esc:
	cmp al, 4bh
	je @@left
	
	cmp al, 48h
	je @@up
	
	cmp al, 4dh
	je @@right
	
	cmp al, 50h
	je @@down
	
	cmp al, 0ch
	je @@reduse_speed
	
	cmp al, 0dh
	je @@increase_speed
	
	jmp interrupt_end
	
@@reduse_speed:
	mov al, delay
	cmp al, 06h
	jg @@reduse_end
	shl al, 1
	mov delay, al
@@reduse_end:
	jmp @@end

@@increase_speed:
	mov al, delay
	cmp al, 01h
	jle @@reduse_end
	shr al, 1
	mov delay, al
@@temp_end:
	jmp @@end
	
@@left:
	cmp direct, 02h
	je interrupt_end
	mov direct, 4
	jmp @@end
@@up:
	cmp direct, 03h
	je interrupt_end
	mov direct, 1
	jmp @@end
@@right:
	cmp direct, 04h
	je interrupt_end
	mov direct, 2
	jmp @@end
@@down:
	cmp direct, 01h
	je interrupt_end
	mov direct, 3
	jmp @@end
@@end:

interrupt_end:
	in al, 61h
	mov ah, al
	or al, 80h
	out 61H, al
	xchg ah, al
	out 61H, al

	mov	al, 20h
	out	20h, al
	popa
	iret
m09_handler endp

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
	mov		[old_page], bh
	pop 	bx
	pop		ax	
	ret
get_old_page endp

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

change_mode proc
	call get_old_mode
	call get_old_page

	xor ax, ax
	mov al, our_vm
	push ax
	mov al, our_page
	push ax
   
	call change_vm
	
	ret
change_mode endp

init_snake proc
	
	mov head_x, 30
	mov head_y, 20
	mov al, head_x
	add al, snake_length
	dec al
	mov tail_x, al
	mov tail_y, 20
	
	
	mov al, head_x
	mov bl, 05h
	mul bl
	mov start_x, ax
	mov al, head_y
	mul bl
	mov start_y, ax
	
	mov ax, snake_point_size
	mov cur_point_size, ax
	
	mov al, snake_color
	mov cur_color, al
	call draw_snake
	ret
init_snake endp

draw_snake proc
	mov cl, snake_length
	xor ch, ch
@@loop:
	call draw_point
	cmp is_vertical_snake, 00h
	pusha
	mov ax, start_x
	mov bl, 5
	div bl
	xor ah, ah
	mov cx, ax
	
	mov ax, start_y
	mov bl, 5
	div bl
	xor ah, ah
	mov dx, ax
	mov al, 04h
	call draw_snake_part_map
	popa
	jne @@vert_snake
	add start_x, 5
	jmp @@next
@@vert_snake:
	add start_y, 5

@@next:	
	
	mov ax, 4
	mov cur_point_size, ax
	dec cx
	test cx, cx
	jne @@loop
	ret
draw_snake endp

draw_snake_part_map proc
	; al - цвет, (cx, dx) - координаты
	mov ah, 0ch
	mov bh, 01h
	int 10h
	ret
draw_snake_part_map endp

draw_point proc
	;   устанавливаем размер клетки в cur_point_size,
	;	цвет клетки в cur_color, 
	;	начальную позицию в start_y, start_x
	pusha; ax sp bp si di
	mov ax, cur_point_size
	mov temp_size_x, ax
	mov temp_size_y, ax
	
	mov ax, start_y
	mov temp_line, ax
	mov ax, start_x
	mov temp_column, ax
	
	mov ah, 0ch
	mov al, cur_color
	mov bh, our_page
	
@@loop:
	mov cx, temp_column
	mov dx, temp_line
	int 10h
	
	dec temp_size_x
	inc temp_column
	cmp temp_size_x, 0
	jnz @@loop
	
	dec temp_size_y
	inc temp_line
	mov cx, cur_point_size
	mov temp_size_x, cx
	
	mov cx, start_x
	mov temp_column, cx
	mov temp_column, cx
	
	cmp temp_size_y, 0
	jnz @@loop
	
	popa; di si bp sp ax
	
	ret
draw_point endp

draw_bottom proc
	
	mov cur_color, 08h
	mov start_x, 72
	mov start_y, 190
	
@@loop:
	call draw_point
	pusha
	mov al, 08h
	call draw_art_in_map
	popa
	add start_x, 1
	cmp start_x, 316
	jl @@loop
	
	ret
draw_bottom endp

draw_concrete_wall proc
	mov cur_color, 08h
	mov start_x, 315
	mov start_y, 3
	
@@loop:
	call draw_point
	pusha
	mov al, 08h
	call draw_art_in_map
	popa
	add start_y, 2
	cmp start_y, 190
	jl @@loop
	
	ret
draw_concrete_wall endp

draw_concrete_ceiling proc
	mov cur_color, 08h
	mov start_x, 72
	mov start_y, 3
	
@@loop:
	call draw_point
	pusha
	mov al, 08h
	call draw_art_in_map
	popa
	add start_x, 2
	cmp start_x, 316
	jl @@loop
	ret
draw_concrete_ceiling endp

draw_elastic_wall proc
	mov cur_color, 0bh
	mov start_x, 72
	mov start_y, 3
@@loop:
	call draw_point
	pusha
	mov al, 0bh
	call draw_art_in_map
	popa
	add start_y, 1
	cmp start_y, 191
	jl @@loop
	ret
draw_elastic_wall endp



draw_portal proc
	mov cur_color, 0dh
	mov start_x, 72
	mov start_y, 90
@@loop:
	call draw_point
	pusha
	mov al, 0dh
	call draw_art_in_map
	popa
	add start_y, 2
	cmp start_y, 110
	jl @@loop
	
	mov start_x, 315
	mov start_y, 90
@@loop1:
	call draw_point
	pusha
	mov al, 0dh
	call draw_art_in_map
	popa
	add start_y, 2
	cmp start_y, 110
	jl @@loop1
	
	ret
draw_portal endp

draw_walls proc
	pusha
	mov cur_point_size, 02h
	
	call draw_bottom
	call draw_concrete_wall
	call draw_concrete_ceiling
	;mov cur_point_size, 02h
	call draw_elastic_wall
	
	call draw_portal
	popa
	ret
draw_walls endp

draw_good_art proc
	mov cur_color, 09h
	pusha
	mov al, 09h
	call draw_art_in_map
	popa
	call draw_point
	ret
draw_good_art endp

draw_dead_art proc
	mov cur_color, 0ch
	pusha
	mov al, 0ch
	call draw_art_in_map
	popa
	call draw_point
	ret
draw_dead_art endp

draw_hurt_art proc
	mov cur_color, 0eh
	pusha
	mov al, 0eh
	call draw_art_in_map
	popa
	call draw_point
	ret
draw_hurt_art endp

draw_art_in_map proc
	; al - цвет
	push ax	
	mov ax, start_x
	mov bl, 5
	div bl
	xor ch, ch
	mov cl, al
	
	mov ax, start_y
	mov bl, 5
	div bl
	xor dh, dh
	mov dl, al
	pop ax
	call draw_in_map
	ret
draw_art_in_map endp

draw_in_map proc
	; al - цвет, cx - горизонт координата, dx - вертикальная координата
	
	push es di ax
	mov ax, 0A000h
	mov es, ax
	mov ax, 320
	mul dx
	add ax, cx
	mov di, ax
	pop ax
	stosb
	pop di es
	
	ret
draw_in_map endp

draw_art proc
	mov cl, art_count
	mov start_x, 90
	mov start_y, 30
	mov cur_point_size, 4
@@loop:
	call draw_good_art
	call inc_start_positions
	dec cl
	cmp cl, 00h
	je @@end
	
	call draw_dead_art
	call inc_start_positions
	dec cl 
	cmp cl, 00h
	je @@end
	
	call draw_hurt_art
	call inc_start_positions
	dec cl 
	cmp cl, 00h
	jne @@loop
@@end:
	ret
draw_art endp

inc_start_positions proc
	add start_x, 30
	cmp start_x, 316
	jl @@next
	sub start_x, 220
	add start_y, 15

@@next:
	ret
inc_start_positions endp

play_sounds proc
	push ax
	
	cmp found_elastic_wall, 1
	jne @@2
	dec found_elastic_wall
	mov ax, elastic_wall_sound
	jmp @@end
	
@@2:
	cmp found_incr_food, 1
	jne @@3
	dec found_incr_food
	mov ax, inc_food_sound
	jmp @@end
	
@@3:
	cmp found_dec_food, 1
	jne @@4
	dec found_dec_food
	mov ax, dec_food_sound
	jmp @@end
	
@@4:
	cmp found_portal, 1
	jne @@5
	dec found_portal
	mov ax, portal_sound
	jmp @@end
	
@@5:
	jmp @@exit
	
@@end:
	in al, 61h                   ;получаем текущий статус
	or al,00000011b              ;разрешаем динамик и таймер 
	out 61h, al               	;заменяем байт  
	mov al, 10110110b              ;установка для канала 2 
	out 43h, al
	mov cx, 5000
@@loop:	
	out 42h, al
	mov al, ah
	out 42h, al

	in al,61h
	or al,0
	out 61h,al
	loop @@loop
	
	in al, 61h   ;полчаем статус порта В
	and al,	11111100b    ;выключаем динамик
	out 61H,al
@@exit:
	pop ax
	ret
play_sounds endp

final_music proc
	
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
final_music endp

parse_args proc
	
	mov cx, cs:[80h]
	xor ch, ch
	
	cmp cx, 0
	je @@end
	
	dec cx
	
	mov si, 82h
	
@@start:
	xor al, al
	call pass_spaces
	
	
@@next_step:
	mov bl, 2fh  ; код /
	cmp al, bl
	jne @@temp_error

	inc si
	dec cx
	
	cmp cx, 0
	je @@temp_error; прочитали только /, а строка закончилась
	
	
@@is_help:
	mov al, cs:[si] 	
	mov bl, 68h  ; код h
	cmp al, bl
	jne @@is_length
	inc si
	dec cx
	
	mov ax, [setting_flags]
	cmp ax, 0000h
	jne @@error
	or ax, 1000h
	mov [setting_flags], ax
	
	cmp cx, 0000h
	je @@temp_end

	jmp @@temp_error  ; если ключ /h, то больше ничего не может там быть
	

@@is_length:
	mov bl, 6ch  ; код l
	cmp al, bl
	jne @@is_artef
	inc si
	dec cx
	cmp cx, 0000h
	je @@temp_error ; прочитали только /l, длины нет
	
	mov al, cs:[si]
	mov bl, 20h
	cmp al, bl
	jne @@temp_error  ; не разделены пробелом /l и длина
	call pass_spaces
	
	call get_num
	cmp bx, 0000h  ; возникла ошибка в получении числа(0000h - все хорошо, 0100h - некорректное число)
	jne @@temp_error
	
	cmp dx, 0001h ; длина змейки не меньше 2
	je @@temp_error
	
	cmp dx, 15h 	; длина змейки не больше 16
	jg @@temp_error
	
	mov di, offset snake_length
	mov ax, dx
	stosb  ; записали начальную длину змейки
	
	mov bx, [setting_flags]
	or bx, 0100h
	mov [setting_flags], bx
	
	cmp cx, 0000h
	je @@temp_end
	
	jmp @@start
	
@@temp_error:
	jmp @@error
@@temp_end:
	jmp @@end
	
@@is_artef:	
	call pass_spaces
	mov bl, 61h
	cmp al, bl
	jne @@is_intersect
	
	inc si
	dec cx
	cmp cx, 0000h
	je @@error ; прочитали только /a, количества нет
	
	mov al, cs:[si]
	mov bl, 20h
	cmp al, bl
	jne @@error  ; не разделены пробелом /a и количество
	call pass_spaces
		
	call get_num
	cmp bx, 0000h
	jne @@error
	
	mov di, offset art_count
	mov ax, dx
	stosb
	
	mov bx, [setting_flags]
	or bx, 0010h
	mov [setting_flags], bx
	
	cmp cx, 0000h
	je @@temp_end
	
	jmp @@start

@@is_intersect:
	call pass_spaces
	mov bl, 69h
	cmp al, bl
	jne @@error
	
	inc si
	dec cx
	cmp cx, 0000h
	je @@error
	
	mov al, cs:[si]
	mov bl, 20h
	cmp al, bl
	jne @@error
	call pass_spaces
	
	cmp al, 30h
	jl @@error
	cmp al, 32h
	jg @@error
	
	sub ax, 30h
	mov di, offset for_inter
	stosb
	
	mov bx, [setting_flags]
	or bx, 0001h
	mov [setting_flags], bx
	
	inc si
	dec cx
	cmp cx, 0000h
	je @@temp_end
	
	jmp @@start
	
@@error:
	mov ax, 0100h
	jmp @@all_end	
@@end:
	mov ax, 0000h
	jmp @@all_end
	
@@all_end:

ret
parse_args endp

pass_spaces proc
@@start:
	xor al, al
	mov al, cs:[si]
	
	mov bl, 20h ; пропускаем все пробелы
	cmp al, bl  ;
	jne @@end  ; 
	inc si
	dec cx
	jmp @@start

@@end:

	ret
pass_spaces endp


get_num proc
	; возвращает в bx код ошибки(0100h - некорректное число), в dx - само число
	xor dx, dx
@@read_dec:
	mov al, cs:[si]
	mov bl, 39h
	cmp al, bl
	jg @@t_error
	mov bl, 30h
	cmp al, bl
	jl @@t_error
	jmp @@next_step
@@t_error:
	cmp al, 20h
	jne @@error
	jmp @@next_dec
	
@@next_step:	
	sub al, 30h
	push ax bx
	mov ax, dx
	mov bl, 0ah
	mul bl
	mov dx, ax
	pop bx ax
	
	add dx, ax
	inc si
	dec cx
	cmp cx, 0000h
	je @@next_dec
	jmp @@read_dec
	
@@next_dec:
	cmp dx, 30
	jg @@error  ; длина змейки не больше 30
	
	cmp dx, 0
	jle @@error
	jmp @@correct_num

@@error:
	mov bx, 0100h
	jmp @@end
	
@@correct_num:
	mov bx, 0000h
	jmp @@end
	
@@end:

	ret
get_num endp

cls proc 
    push ax cx di es
    mov ax,0A000h
    mov es,ax

    xor ax, ax
    mov cx, 64000	; 64000 = 320*200
    mov di, ax

    rep stosb
    pop es di cx ax
    ret 
cls endp

write_number proc

  	push ax bx dx si di
		xor ax, ax
  	lodsb

    push -1
		mov bx, 10
		@@stacknumber:
		xor dx,dx
		div bx
		push dx
		cmp ax,0
		jne @@stacknumber

		pop dx
		@@addnumber:
		add dx,'0'
		mov ah, 02h
		int 21h
		pop dx
		cmp dx,-1
		jne @@addnumber

  	pop di si dx bx ax

  	ret
write_number endp

draw_enter proc
	push ax dx
	mov dl, 0dh
	mov ah, 02h
	int 21h
	
	mov dl, 0ah
	mov ah, 02h
	int 21h
	pop dx ax
	ret
draw_enter endp

draw_tab proc
	push ax dx
	mov dl, 09h
	mov ah, 02h
	int 21h
	pop dx ax
	ret
draw_tab endp

statistics proc
	call cls
	
	call draw_enter
	call draw_enter
	call draw_tab
	lea dx, results_msg
	mov ah, 09h
	int 21h
	
	call draw_enter
	call draw_enter
	call draw_enter
	
	push si cx
	
	xor si, si
	xor cx, cx
	
	call draw_tab
	lea dx, length_msg
	mov ah, 09h
	int 21h
	
	mov si, offset snake_length
	call write_number
	
	call draw_enter
	call draw_enter
	call draw_tab
	
	lea dx, art_msg
	mov ah, 09h
	int 21h
	
	mov si, offset food_count
	call write_number
	
	pop cx si
	ret
statistics endp


main:
	call parse_args
	
	cmp ax, 0000h
	je @@next_step
	lea dx, error_msg
	mov ah, 09h
	int 21h
	jmp exit
		
@@next_step:
	mov bx, [setting_flags]
	cmp bx, 1000h
	jne @@draw_picture
	
	lea dx, help
	mov ah, 09h
	int 21h
	jmp exit
	

@@draw_picture:
	pusha
	call change_mode
	
	call init_snake
	
	call draw_walls
	
	call draw_art
	
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
	pop es
	
	push es
	mov ah, 35h
	mov al, 1ch
	int 21h
	mov word ptr old_08_code + 1, bx
	mov word ptr old_08_code + 3, es
	mov dx, offset m08_handler
	mov ah, 25h
	mov al, 1ch
	int 21h
	pop es
	
main_loop:
	mov al, cur_teak
	cmp al, delay
	jge @@move
	jmp @@end
	
@@move:
	call move_snake
	call play_sounds
	mov cur_teak, 0h
@@end:
	
	mov al, ext_flag
	test al, al
	jz main_loop
	popa
	
	call final_music	
	
	call statistics
	
	
	
	push ds
	mov dx, word ptr old_08_code + 1
	mov ds, word ptr old_08_code + 3
	mov ah, 25h
	mov al, 1ch
	int 21h
	pop ds
	
	push ds
	mov dx, word ptr old_09_code + 1
	mov ds, word ptr old_09_code + 3
	mov ah, 25h
	mov al, 09h
	int 21h
	pop ds	
	
	mov ah, 00h
	int 16h
	
	xor ax, ax
	mov al, [old_vm]
	push ax
	mov al, [old_page]
	push ax
	call change_vm
exit:
	
ret


setting_flags 		dw	0000h
art_count			db	0ah

food_count			db	00h
snake_length		db	04h
snake_color			db	07h
snake_point_size	dw	0004h
cur_point_size		dw	?
cur_color			db	?
temp_size_x			dw	?
temp_size_y			dw 	?
temp_point			db	?
start_x				dw	?
start_y				dw	?
is_vertical_snake	db	00h
temp_line			dw	?
temp_column			dw	?

found_portal		db	0
found_elastic_wall	db	0
found_incr_food		db	0
found_dec_food		db	0		
found_next_step		db	0

portal_sound		dw  4559
elastic_wall_sound	dw	3620
inc_food_sound		dw	3044
dec_food_sound		dw	2416
next_step_sound		dw 	3225
 

direct				db	4	; 4  <-
							; 1 up
							; 2 ->
							; 3 down
direct_tail			db	0
head_x				db	?
head_y				db	?
tail_x				db  ?
tail_y				db	?

ext_flag			db  0

old_vm				db	?
old_page			db	?
old_08_code 		db  0eah, 00, 00, 00, 00
old_09_code 		db 	0eah, 00, 00, 00, 00
our_vm				db	13h
our_page			db	02h

for_inter			db	1	; 0 - умерла
							; 1 - обрезала хвост
							; 2 - ничего не произошло
							
help				db	"Snake", 0ah, 0dh,"Keys: /h | /l [length] | /a [artefacts count] | /i [0|1].", 0ah, 0dh, "Length get values from 2 to 15.", 0ah, 0dh, "Artefacts count get values from 1 to 30.", 0ah, 0dh, "/i 0 - when snake intersect itself she die.",0ah, 0dh, "/i 1 - when snake intersect itself she cut tail.", 0ah, 0dh, "Gray walls are corcrete walls, where snake die.", 0ah, 0dh, "Blue wall is elastic wall.", 0ah, 0dh, "Pink wall is portal.", 0ah, 0dh, "Red artefact kill snake.", 0ah, 0dh, "Yellow artefact decrease snake length.", 0ah, 0dh, "Blue artefact increase snake length.", 0ah, 0dh, "For increase speed pass +.", 0ah, 0dh, "For decrease speed pass -.", 0ah, 0dh, "$"
error_msg			db	"Incorrect keys!$"
	
length_msg			db	"Lenght: $"
art_msg				db	"Artefacts: $"
msg					db	?
results_msg			db	"Results $"

;размер экрана - 320*200
;размер карты - 40*64
; colors:	08h - бетонный пол
;			0bh - упругая стена
;           0dh - портал
;			09h - артефакт. Увеличивает длину	
;			0ch	- артефакт. Убивает
;			0eh - артефакт. Уменьшает длину
;		  	04h - движение влево
;		  	01h - движение вверх
;			02h - движение вправо
;			03h - движение вниз
;			05h - пустая клетка


end start
