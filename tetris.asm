.model small
.data
	
	flag db 0					; 1 if collision, 2 if dead, 3 if out of bounds, 4 if landed, 5 if times up, 6 if new level
	hold_flag db 0 					; 1 if recently held something
	
	clock db 0
	user_choice db 0				; selected page
	
	stage_level db 1				; current stage
	stage_goal db 5					; lines left at current stage
	stage_time db 180				; current clock at current stage
	stage_speed db 18				; current speed at current stage
	
	tet_color db 09h 				; also its type (I, J, L, O, S, Z, T)
	tet_rotate db 0					; 0 = normal, 1 = 90 deg cw, 2 = 180 deg, 3 = 90 deg ccw
	tet_length db 0
	
	tet_now db 0			
	tet_next db 0					; 0 to 6
	tet_hold db 9					; 0 to 6	
	tet_current db 10 dup(0)

	str_name db 4 dup(0)
	str_level db 3 dup(0)
	str_goal db 4 dup(0)
	str_time db 6 dup(0)
	
	x db 0
	y db 0
	temp_x db 0
	temp_y db 0
	ghost_x db 0
	ghost_y db 0
	
	grid db 250 dup(0)
	
	high_rank db 5
	high_level db 0
	high_goal db 0
	
	high_path db "highscores.dat", 0
	high_buffer db 41 dup(0)
	high_handle dw 0
	
	tet_o db "CDLUCDLUCDLUCDLU", 0
	tet_i db "CRCLLCDCUUCRRCLCDDCU", 0
	tet_j db "CRDCLCDLCUCRCLUCDCUR", 0
	tet_l db "CRCLDCDCULCRUCLCDRCU", 0
	tet_s db "CRCDLCDCLUCRCDLCDCLU", 0
	tet_z db "CDRCLCLDCUCDRCLCLDCU", 0
	tet_t db "CRCDCLCDCLCUCLCUCRCUCRCD", 0
	
	msg_gameover1 db "  G A M E  O V E R  ", '$'
	msg_gameover2 db " PRESS ENTER KEY TO ", '$'
	msg_gameover3 db "GO BACK TO MAIN MENU", '$'
	
	msg_highscore1 db "   NEW HIGHSCORE!   ", '$'
	msg_highscore2 db "  ENTER YOUR NAME:  ", '$'
	msg_highscore3 db "                    ", '$'
	
	msg_main1 db "    Tetris BETA!    ", '$'
	msg_main2 db "        PLAY        ", '$'
	msg_main3 db "      CONTROLS      ", '$'
	msg_main4 db "     HIGH SCORE     ", '$'
	msg_main5 db "        ABOUT       ", '$'
	msg_main6 db "        QUIT        ", '$'
	
	msg_hold db "   HOLD   ", '$'
	msg_next db "   NEXT   ", '$'
	msg_level db "  LEVEL   ", '$'
	msg_goal db "   GOAL   ", '$'
	msg_time db "   TIME   ", '$'
	
	msg_head_control db "     Controls!      ", '$'
	msg_head_scores db "    High scores!    ", '$'
	msg_head_table db "Name   Level   Lines", '$'
	
	msg_control_key1 db "LEFT ARROW", '$'
	msg_control_key2 db "RIGHT ARROW", '$'
	msg_control_key3 db "DOWN ARROW", '$'
	msg_control_key4 db "SPACE BAR", '$'
	msg_control_key5 db "Z", '$'
	msg_control_key6 db "X", '$'
	msg_control_key7 db "C", '$'

	msg_control_def1 db "Move to the left.", '$'
	msg_control_def2 db "Move to the right.", '$'
	msg_control_def3 db "Soft drop.", '$'
	msg_control_def4 db "Hard drop.", '$'
	msg_control_def5 db "Rotate counter-clockwise.", '$'
	msg_control_def6 db "Rotate clockwise.", '$'
	msg_control_def7 db "Hold tetrimino.", '$'
	
	msg_about1 db "In partial fulfillment", '$'
	msg_about2 db "        of the        ", '$'
	msg_about3 db "   requirements in    ", '$'
	msg_about4 db "       CMSC 131       ", '$'	
	msg_about5 db "     Damian Fadri     ", '$'
	msg_about6 db "     Janssen Sison    ", '$'	
	msg_about7 db "     Presented to:    ", '$'
	msg_about8 db "  Marvin John Ignacio ", '$'
	
.stack 100h
.code
	clear_screen proc
		; Set video mode
		mov ax, 0003h
		int 10h
		
		; Hide cursor
		mov cx, 3200h
		mov ah, 01h
		int 10h
		
		ret
	clear_screen endp
	
	; Generate a delay in between lines of code 
	delay proc
		mov ah, 00
		int 1Ah
		mov bx, dx

		d1:
		int 1Ah
		sub dx, bx
		cmp dl, 1
		jl d1
		
		call update_clock
		ret
	delay endp
	
	; Update current time 
	update_clock proc
		inc clock
		
		xor ah, ah
		mov al, clock
		mov cl, stage_speed
		div cl
		
		cmp ah, 0
		jne p0	
		inc y					; bring tetrimino 1 row down
			
		p0:
		cmp clock, 18
		jne p1
		mov clock, 0				; reset clock counter
		dec stage_time
			
		p1:
		ret
	update_clock endp
	
	; Find position of tetrimino for a hard drop
	hard_drop proc
		; Set position of ghost tetrimino as the tetrimino's coords
		inc ghost_y
		mov cl, ghost_y
		mov y, cl
		
		mov flag, 4
		ret	
	hard_drop endp
	
	; Find position of tetrimino for a counter-clockwise rotate
	rotate_ccw proc
		dec tet_rotate				; change rotate value
		cmp tet_rotate, 255			; check if rotate value is 255 
		je p0					; loop back to 3
		jmp p1
			
		p0:
		mov tet_rotate, 3		
		
		p1:
			call adjust_tetrimino
			call check_tetrimino		; check if there are collisions	
		
			cmp flag, 1
			je p2				; revert changes if so
			cmp flag, 3			; if out of bounds, move to rotate
			je p5
			
			ret				; if no collision, end
			
		p5:
			mov cl, x
			mov ch, y
			mov ghost_x, cl			; store current x-coord
			mov ghost_y, ch			; store current y-coord
			
			cmp y, 2
			jge p10
		
		p9:
			inc y
			call check_tetrimino
			
			cmp flag, 1			; revert y-coord and rotate value
			je p8
			cmp flag, 3
			je p9
			
			jmp p5
		
		p10:
			cmp x, 40
			jle p6				; left side out of bounds
			jg p7				; right side out of bounds
			
		
		p6:
			add x, 2
			call check_tetrimino
			
			cmp flag, 1			; if there's a collision
			je p8				; revert x-coord and rotate value
			cmp flag, 3			; if still out of bounds
			je p6				; move some more
			
			ret						
			
		p7:
			sub x, 2
			call check_tetrimino
			
			cmp flag, 1			; if there's a collision
			je p8				; revert x-coord and rotate value
			cmp flag, 3			; if still out of bounds
			je p7				; move some more
			
			ret						
			
		p8:
			mov cl, ghost_x
			mov ch, ghost_y
			mov x, cl
			mov y, ch
			jmp p2
		
		p2:
			mov cl, 1				
			inc tet_rotate			; revert to original rotate value
			cmp tet_rotate, cl		; check if rotate value is 255
			je p3				; loop back to 3
			
			jmp p4
			
		p3:
			mov tet_rotate, 0			
		
		p4:
			call adjust_tetrimino
			ret
				
	rotate_ccw endp
	
	; Find position of tetrimino for a clockwise rotate
	rotate_cw proc
		mov cl, 4
		inc tet_rotate				; change rotate value
		cmp tet_rotate, cl			; check if rotate value is 4 
		je p0					; loop back to 0
		jmp p1
			
		p0:
			mov tet_rotate, 0		
		
		p1:
			call adjust_tetrimino
			call check_tetrimino		; check if there are collisions	
			
			cmp flag, 1
			je p2				; revert changes if so
			cmp flag, 3			; if out of bounds, move to rotate
			je p5
			
			ret				; if no collision, end
		
		p5:
			mov cl, x
			mov ch, y
			mov ghost_x, cl			; store current x-coord
			mov ghost_y, ch			; store current y-coord
			
			cmp y, 1
			jge p10
		
		p9:
			inc y
			call check_tetrimino
			
			cmp flag, 1			; revert y-coord and rotate value
			je p8
			cmp flag, 3
			je p9
			
			ret
		
		p10:
			cmp x, 40
			jle p6				; left side out of bounds
			jg p7				; right side out of bounds
			
		
		p6:
			add x, 2
			call check_tetrimino
			
			cmp flag, 1			; if there's a collision
			je p8				; revert x-coord and rotate value
			cmp flag, 3			; if still out of bounds
			je p6				; move some more
			
			ret						
			
		p7:
			sub x, 2
			call check_tetrimino
			
			cmp flag, 1			; if there's a collision
			je p8				; revert x-coord and rotate value
			cmp flag, 3			; if still out of bounds
			je p7				; move some more
			
			ret						
			
		p8:
			mov cl, ghost_x
			mov ch, ghost_y
			mov x, cl
			mov y, ch
			jmp p2
		
		p2:
			mov cl, 255				
			dec tet_rotate			; revert to original rotate value
			cmp tet_rotate, cl		; check if rotate value is 255
			je p3				; loop back to 3
			
			jmp p4
		
		p3:
			mov tet_rotate, 3	

		p4:
			call adjust_tetrimino
			ret
	rotate_cw endp
	
	; Holds the current tetrimino for later use
	hold_tetrimino proc
		cmp hold_flag, 1			; if recently held something
		jne p0
		ret
		
		p0:
		mov cl, tet_now
		mov ch, tet_hold
		
		cmp ch, 9				; if user's first hold
		je p1
		
		mov tet_now, ch
		mov tet_hold, cl
		
		jmp p2
		
		p1:
		mov ch, tet_next
		
		mov tet_hold, cl
		mov tet_now, ch	
		
		p2:
		mov x, 41
		mov y, 0
		call get_tetrimino
		mov hold_flag, 1
		
		call print_hold
		
		ret
	hold_tetrimino endp
	
	; Generate the next tetrimino
	random_tetrimino proc
		; Generate a random tetrimino
		p0:		
		mov ah, 00h     	
		int 1Ah         	

		mov ax, dx
		xor dx, dx
		mov cx, 7				; 7 different tetriminos
		div cx					; contains the type of the generated tetrimino
		
		cmp dl, tet_now
		je p0
		
		mov tet_next, dl
		call print_preview
		
		ret
	random_tetrimino endp
	
	; Generates the current tetrimino object
	get_tetrimino proc
		mov dl, tet_now
	
		cmp dl, 0
		je p0
		cmp dl, 1
		je p1
		cmp dl, 2
		je p2
		cmp dl, 3
		je p3
		cmp dl, 4
		je p4
		cmp dl, 5
		je p5
		cmp dl, 6
		je p6
		
		p7:
			call adjust_tetrimino
			ret
		
		p0:					; O tetrimino
			mov tet_rotate, 0		; normal state
			mov tet_length, 4		; substring of length 4
			mov tet_color, 07h		; gray
			
			jmp p7
		
		p1:					; I tetrimino
			mov tet_rotate, 0		; normal state
			mov tet_length, 5		; substring of length 5
			mov tet_color, 03h		; cyan
			
			jmp p7
		
		p2:					; J tetrimino
			mov tet_rotate, 0		; normal state
			mov tet_length, 5		; substring of length 5
			mov tet_color, 09h		; blue

			jmp p7
			
		p3:					; L tetrimino
			mov tet_rotate, 0		; normal state
			mov tet_length, 5		; substring of length 5
			mov tet_color, 0Eh		; yellow
			
			jmp p7
			
		p4:					; S tetrimino
			mov tet_rotate, 0		; normal state
			mov tet_length, 5		; substring of length 5
			mov tet_color, 0Ah		; light green
			
			jmp p7
			
		p5:					; Z tetrimino
			mov tet_rotate, 0		; normal state
			mov tet_length, 5		; substring of length 5
			mov tet_color, 0Ch		; light red
			
			jmp p7
			
		p6:					; T tetrimino
			mov tet_rotate, 0		; normal state
			mov tet_length, 6		; substring of length 6
			mov tet_color, 0Dh		; light magenta
			
			jmp p7		
	get_tetrimino endp
	
	; Sets the value of tet_current according to the tetrimino's type and rotation
	adjust_tetrimino proc
		; Find main tetrimino string
		call search_tetrimino
	
		; Move pointer in main tetrimino string to current rotation
		xor ah, ah
		mov al, tet_length
		mov di, ax				; contains the length of the tetrimino substring
		
		mov cl, tet_rotate
		mul cl
		
		add bx, ax				; pointer in main string currently in proper location
		
		xor si, si		
		p1:
			mov cl, [bx]
			mov [tet_current+si], cl
			
			inc si
			inc bx
			
			cmp si, di
			jne p1
			
		xor cl, cl
		mov [tet_current+si], cl
		
		ret
	adjust_tetrimino endp
	
	search_tetrimino proc
		mov cl, tet_color		
		
		cmp cl, 07h				; O tetrimino
		je p0
		cmp cl, 03h				; I tetrimino
		je p1
		cmp cl, 09h				; J tetrimino
		je p2
		cmp cl, 0Eh				; L tetrimino
		je p3
		cmp cl, 0Ah				; S tetrimino
		je p4
		cmp cl, 0Ch				; Z tetrimino
		je p5
		cmp cl, 0Dh				; T tetrimino
		je p6
		
		p7:
			ret
			
		p0:
			lea bx, tet_o
			jmp p7
		p1:
			lea bx, tet_i
			jmp p7
		p2:
			lea bx, tet_j
			jmp p7
		p3:
			lea bx, tet_l
			jmp p7
		p4:
			lea bx, tet_s
			jmp p7
		p5:
			lea bx, tet_z
			jmp p7
		p6:
			lea bx, tet_t
			jmp p7
	
	search_tetrimino endp
	
	get_input proc
		; Get input from keyboard
		mov ah, 01h
		int 16h
		
		jnz m0
		jmp m8
		
		m0:
			mov ah, 00h
			int 16h
			
			; Check if left arrow key
			cmp ah, 75				
			je m1
			
			; Check if right arrow key
			cmp ah, 77				
			je m2
					
			; Check if hold
			cmp al, 'c'
			je m3
			cmp al, 'C'
			je m3
			
			; Check if rotate counter-clockwise
			cmp al, 'z'
			je m4
			cmp al, 'Z'
			je m4
			
			; Check if rotate clockwise
			cmp al, 'x'
			je m5
			cmp al, 'X'
			je m5
			
			; Check if hard drop
			cmp al, ' '
			je m6

			; Check if down arrow key (soft drop)
			cmp ah, 80
			je m7
			
		m8:
			mov flag, 0
			ret		

		m1:					; Move tetrimino to the left
			sub x, 2			; translate x-coord 2 units to the left
			
			call check_tetrimino		; check if there are collisions
							; 0, 1, 3
			cmp flag, 0
			jne m1a				; revert changes if so
			jmp m8
			
			m1a:
			add x, 2			; translate x-coord 2 units to the right
			jmp m8
				
		m2:					; Move tetrimino to the right
			add x, 2			; translate x-coord 2 units to the right
			call check_tetrimino		; check if there are collisions
							; 0, 1, 3
			cmp flag, 0
			jne m2a				; revert changes if so
			jmp m8

			m2a:
			sub x, 2			; translate x-coord 2 units to the left
			jmp m8
			
		m3:					; Hold current tetrimino
			call hold_tetrimino
			jmp m8
		
		m4:					; Rotate counter-clockwise
			call rotate_ccw
			jmp m8
			
		m5:					; Rotate clockwise
			call rotate_cw
			jmp m8
			
		m6:
			call hard_drop
			ret
			
		m7:
			inc y				; bring tetrimino 1 row down
			call check_tetrimino		
			ret
			
	get_input endp
	
	; Check if current tetrimino collides with another
	; Returns with 
	check_tetrimino proc
		mov flag, 0
		mov al, tet_length
		xor ah, ah
		
		mov di, ax				; length of tet_current
		xor si, si				; counter
		
		p0:
			mov al, [tet_current+si]
			
			cmp al, 'C'
			je p1
			cmp al, 'U'
			je p2
			cmp al, 'R'
			je p3
			cmp al, 'D'
			je p4
			cmp al, 'L'
			je p5
			ret
		
		p6:							
			; Check if block collides with another
			xor ah, ah
			mov al, temp_x
			
			mov cl, 2
			div cl
			
			xor ah, ah				
			mov bx, ax			; bx contains the grid index at (temp_x, 0)
			
			xor ah, ah
			mov al, temp_y
			
			mov cl, 10
			mul cl					
			
			add bx, ax			; i = y*10 + x/2
			
			xor cl, cl
			cmp [grid+bx], cl		; check if a block already exists at the given coords
			jne p8				; if yes, theres a collision
			
			; Check if block is out of bounds
			mov al, temp_x
			mov ah, temp_y
			
			cmp al, 0
			jl p9
			cmp al, 19
			jg p9
			cmp ah, 0
			jl p9
			cmp ah, 24			; landed
			jg p7
			
			inc si
			
			cmp si, di
			jne p0				; if not equal, there's still a tetrimino block to be checked
			ret
		
		p7:
			mov flag, 4			; landed	
			ret
			
		p8:
			cmp y, 0			; if current coordinate is NOT at the top
			jne p10				; ordinary collision
			
			mov flag, 2			; dead
			ret
		
		p9:
			mov flag, 3			; out of bounds
			ret
			
		p10:
			mov flag, 1			; ordinary collision
			ret
	
		p1:	
			mov cl, x
			mov ch, y
			
			mov temp_x, cl			; x-coord [31, 50]
			mov temp_y, ch			; y-coord [0, 24]
			
			; Translate temp_x to [0, 19]
			sub temp_x, 31
			jmp p6
			
		p2:		; U
			dec temp_y
			jmp p6
			
		p3:		; R
			add temp_x, 2
			jmp p6
			
		p4:		; D
			inc temp_y
			jmp p6
			
		p5:		; L
			sub temp_x, 2
			jmp p6
			
	check_tetrimino endp
	
	; Print the next tetrimino
	print_preview proc	
		xor bh, bh				; page
		mov al, 219				; full ASCII block
		
		; Top-right preview screen coordinates
		mov dl, 54
		mov dh, 2
		
		p7:						
		mov ah, 02h
		int 10h
		
		xor bl, bl
		mov cx, 10
		mov ah, 09h
		int 10h
		
		inc dh
		cmp dh, 7
		jne p7
		
		; Print preview
		mov cl, tet_next
		
		cmp cl, 0
		je p0
		cmp cl, 1
		je p1
		cmp cl, 2
		je p2
		cmp cl, 3
		je p3
		cmp cl, 4
		je p4
		cmp cl, 5
		je p5
		cmp cl, 6
		je p6
		
		p0:					; O tetrimino
			mov bl, 07h
			mov cx, 4

			mov dl, 57
			mov dh, 4
			
		p0a:
			mov ah, 02h
			int 10h
			
			mov ah, 09h
			int 10h
							
			inc dh
			cmp dh, 6
			jne p0a
			ret
			
		p1:					; I tetrimino
			mov bl, 03h
			mov cx, 2
			
			mov dl, 58
			mov dh, 3
			
		p1a:					
			mov ah, 02h
			int 10h
			
			mov ah, 09h
			int 10h
			
			inc dh
			cmp dh, 7
			jne p1a
			ret
			
		p2:					; J
			mov bl, 09h
			mov cx, 6
			
			mov dl, 56
			mov dh, 4
			
		p2a:
			mov ah, 02h
			int 10h
			
			mov ah, 09h
			int 10h
			
			inc dh
			sub cx, 4
			add dl, 4
			
			cmp dh, 6
			jne p2a
			ret
			
		p3:					; L
			mov bl, 0Eh
			mov cx, 6
			
			mov dl, 56
			mov dh, 4
			
		p3a:
			mov ah, 02h
			int 10h
			
			mov ah, 09h
			int 10h
			
			inc dh
			sub cx, 4
			
			cmp dh, 6
			jne p3a
			ret
			
		p4:					; S
			mov bl, 0Ah
			mov cx, 4
			
			mov dl, 58
			mov dh, 4
		
		p4a:
			mov ah, 02h
			int 10h
			
			mov ah, 09h
			int 10h
			
			inc dh
			sub dl, 2
			
			cmp dh, 6
			jne p4a
			ret
			
		p5:					; Z
			mov bl, 0Ch
			mov cx, 4
			
			mov dl, 56
			mov dh, 4
		
		p5a:
			mov ah, 02h
			int 10h
			
			mov ah, 09h
			int 10h
			
			inc dh
			add dl, 2
			
			cmp dh, 6
			jne p5a
			ret
			
		p6:					; T
			mov bl, 0Dh
			mov cx, 6
			
			mov dl, 56
			mov dh, 4
			
		p6a:
			mov ah, 02h
			int 10h
			
			mov ah, 09h
			int 10h
			
			inc dh
			add dl, 2
			sub cx, 4
			
			cmp dh, 6
			jne p6a
			ret
		
	print_preview endp
	
	; Print the held tetrimino
	print_hold proc	
		xor bh, bh				; page
		mov al, 219				; full ASCII block
		
		; Top-right preview screen coordinates
		mov dl, 18
		mov dh, 2
		
		; Clear preview screen
		p7:						
		mov ah, 02h
		int 10h
		
		xor bl, bl
		mov cx, 10
		mov ah, 09h
		int 10h
		
		inc dh
		cmp dh, 7
		jne p7
		
		; Print preview
		mov cl, tet_hold
		
		cmp cl, 0
		je p0
		cmp cl, 1
		je p1
		cmp cl, 2
		je p2
		cmp cl, 3
		je p3
		cmp cl, 4
		je p4
		cmp cl, 5
		je p5
		cmp cl, 6
		je p6
		ret
		
		p0:					; O tetrimino
			mov bl, 07h
			mov cx, 4

			mov dl, 21
			mov dh, 4
			
		p0a:
			mov ah, 02h
			int 10h
			
			mov ah, 09h
			int 10h
							
			inc dh
			cmp dh, 6
			jne p0a
			ret
			
		p1:					; I tetrimino
			mov bl, 03h
			mov cx, 2
			
			mov dl, 22
			mov dh, 3
			
		p1a:					
			mov ah, 02h
			int 10h
			
			mov ah, 09h
			int 10h
			
			inc dh
			cmp dh, 7
			jne p1a
			ret
			
		p2:					; J
			mov bl, 09h
			mov cx, 6
			
			mov dl, 20
			mov dh, 4
			
		p2a:
			mov ah, 02h
			int 10h
			
			mov ah, 09h
			int 10h
			
			inc dh
			sub cx, 4
			add dl, 4
			
			cmp dh, 6
			jne p2a
			ret
			
		p3:					; L
			mov bl, 0Eh
			mov cx, 6
			
			mov dl, 20
			mov dh, 4
			
		p3a:
			mov ah, 02h
			int 10h
			
			mov ah, 09h
			int 10h
			
			inc dh
			sub cx, 4
			
			cmp dh, 6
			jne p3a
			ret
			
		p4:					; S
			mov bl, 0Ah
			mov cx, 4
			
			mov dl, 22
			mov dh, 4
		
		p4a:
			mov ah, 02h
			int 10h
			
			mov ah, 09h
			int 10h
			
			inc dh
			sub dl, 2
			
			cmp dh, 6
			jne p4a
			ret
			
		p5:					; Z
			mov bl, 0Ch
			mov cx, 4
			
			mov dl, 20
			mov dh, 4
		
		p5a:
			mov ah, 02h
			int 10h
			
			mov ah, 09h
			int 10h
			
			inc dh
			add dl, 2
			
			cmp dh, 6
			jne p5a
			ret
			
		p6:					; T
			mov bl, 0Dh
			mov cx, 6
			
			mov dl, 20
			mov dh, 4
			
		p6a:
			mov ah, 02h
			int 10h
			
			mov ah, 09h
			int 10h
			
			inc dh
			add dl, 2
			sub cx, 4
			
			cmp dh, 6
			jne p6a
			ret
		
	print_hold endp
	
	; Prints the current tetrimino
	print_tetrimino proc
		mov al, tet_length
		xor ah, ah
		
		mov di, ax				; length of tet_current
		xor si, si				; counter
		p0:
			mov al, [tet_current+si]
			
			cmp al, 'C'
			je p1
			cmp al, 'U'
			je p2
			cmp al, 'R'
			je p3
			cmp al, 'D'
			je p4
			cmp al, 'L'
			je p5
			ret
		
		p6:
			; Move cursor to its proper place
			mov dl, temp_x
			mov dh, temp_y
			xor bh, bh
			mov ah, 02h
			int 10h
			
			; Print block
			mov al, 219			; full ASCII block
			xor bh, bh
			mov bl, tet_color		; color
			mov cx, 2
			mov ah, 09h
			int 10h
			
			inc si
			
			cmp si, di
			jne p0
			ret
			
		p1:					; Restart coord to the primary coord
			mov dl, x
			mov dh, y
			mov temp_x, dl		
			mov temp_y, dh	
			jmp p6
			
		p2:					; Up relative to the current coord
			dec temp_y			
			jmp p6
			
		p3:					; Right relative to the current coord
			mov dl, 2
			add temp_x, dl
			jmp p6
			
		p4:					; Down relative to the current coord
			inc temp_y
			jmp p6
			
		p5:					; Left relative to the current coord
			mov dl, 2
			sub temp_x, dl
			jmp p6
	print_tetrimino endp
	
	print_ghost proc
		call check_ghost			; at this point, ghost_x and ghost_y is set
		dec ghost_y				; fix y-coord
		
		mov al, tet_length
		xor ah, ah
		
		mov di, ax				; length of tet_current
		xor si, si				; counter
		p0:
			mov al, [tet_current+si]
			
			cmp al, 'C'
			je p1
			cmp al, 'U'
			je p2
			cmp al, 'R'
			je p3
			cmp al, 'D'
			je p4
			cmp al, 'L'
			je p5
			ret
		
		p6:
			; Move cursor to its proper place
			mov dl, temp_x
			mov dh, temp_y
			xor bh, bh
			mov ah, 02h
			int 10h
			
			; Print block
			mov al, 176			; dotted ASCII block
			xor bh, bh
			mov bl, 07h			; white
			mov cx, 2
			mov ah, 09h
			int 10h
			
			inc si
			
			cmp si, di
			jne p0
			ret
			
		p1:					; Restart coord to the primary coord
			mov dl, ghost_x
			mov dh, ghost_y
			mov temp_x, dl		
			mov temp_y, dh	
			jmp p6
			
		p2:					; Up relative to the current coord
			dec temp_y			
			jmp p6
			
		p3:					; Right relative to the current coord
			mov dl, 2
			add temp_x, dl
			jmp p6
			
		p4:					; Down relative to the current coord
			inc temp_y
			jmp p6
			
		p5:					; Left relative to the current coord
			mov dl, 2
			sub temp_x, dl
			jmp p6
		
	print_ghost endp
	
	check_ghost proc
		mov cl, x
		mov ghost_x, cl				; store current x-coord
		mov cl, y					
		mov ghost_y, cl				; store current y-coord
		
		p0:
			call check_tetrimino	; 0, 1, 4
			
			; Check if there's no collision at current position
			cmp flag, 0
			je p1				; if no collision, check next row down
			
			; Swap values of y and ghost_y
			mov ch, y			; at this point, either the tetrimino
			mov cl, ghost_y			; has collided or is at the ground
					
			mov ghost_y, ch			
			mov y, cl
			
			ret
			
		p1:
			inc y
			jmp p0
			
	check_ghost endp
	
	; Checks if line/s have been completed
	; Turns completed lines to white
	check_grid proc
		mov si, 240				; counter
		mov di, 250				; row upper limit
		
		p0:
			xor cl, cl			; black color/space in grid
			cmp [grid+si], cl	
			je p3				; if a blank exists, it is NOT a complete line
			
			inc si				; check next element
			
			cmp si, di			; if counter has reached row upper limit
			je p1				; also implies it is a complete line
			
			jmp p0
			
		p1:					; color a whole line white (si = di)
			sub si, 10			; start of row
			mov cl, 0Fh			; change color to white
			
		p2:
			mov [grid+si], cl		; change grid value to white
			
			inc si				; go to next element
			cmp si, di			; if counter has reached row upper limit
			jne p2
			
		p3:					; adjust counter and row upper limit
			sub di, 10			; set row upper limit for one row up
			
			cmp di, 0			; check if reached end of grid
			jne p4
			ret
		
		p4:
			mov si, di
			sub si, 10			; set counter for one row up
			
			jmp p0
	check_grid endp
	
	; Clears white lines in the grid
	clear_grid proc
		p6:
			mov si, 240			; counter
			xor di, di			; counter
		
		p0:
			mov cl, 0Fh			; white
			cmp [grid+si], cl		; check if first elt is NOT white
			jne p1				; proceed to next row
			
			add di, 10			; offset for succeeding rows
			
			cmp stage_goal, 0
			je p4
			
			dec stage_goal
			jmp p4
			
		p1:
			cmp di, 0			; check if there are no white rows found
			je p4				; proceed to next row if none
			
			xor ax, ax			; counter
			
		p2:						
			mov bx, si
			add bx, di			; row to be transferred to
			
			mov cl, [grid+si]		; get current elt
			mov [grid+bx], cl		; transfer current elt
			
			inc si
			add ax, 2
			
			cmp ax, 20
			jne p2
			
			cmp si, 10			; check if last row
			je p3				; fill up the top part with blacks
			
			sub si, ax			; next row
			xor ax, ax
			jmp p2
			
		p3:	
			xor si, si			; counter
			xor cl, cl			; black
			
		p5:
			mov [grid+si], cl
			
			inc si
			
			cmp si, di
			jne p5
			jmp p6
		
		p4:
			sub si, 10
			
			cmp si, 0			; check if reached end of grid
			jne p0
			ret
	clear_grid endp
	
	; Writes the current tetrimino to the grid
	write_grid proc
		dec y					; write last position of tetrimino
		mov al, tet_length
		xor ah, ah
		
		mov di, ax				; length of tet_current
		xor si, si				; counter		
		p0:
			mov al, [tet_current+si]
			
			cmp al, 'C'
			je p1
			cmp al, 'U'
			je p2
			cmp al, 'R'
			je p3
			cmp al, 'D'
			je p4
			cmp al, 'L'
			je p5
			ret
		
		p6:
			; Translate coordinates to grid index
			xor ah, ah
			mov al, temp_y
			mov cl, 20
			
			mul cl
			mov bx, ax
			
			xor ah, ah
			mov al, temp_x
			
			add bx, ax
			
			mov ax, bx
			mov cl, 2
			div cl

			; Set value for bx
			xor ah, ah			
			mov bx, ax
			
			mov cl, tet_color
			mov [grid+bx], cl
			
			inc si
			
			cmp si, di
			je p7			
			jmp p0
		
		p7:
			;mov x, start_x
			;mov y, start_y
			ret
		
		p1:	
			mov dl, x
			mov dh, y
			mov cl, 31
			mov temp_x, dl			; x-coord [31, 50]
			mov temp_y, dh			; y-coord [0, 24]
			
			; Translate temp_x to [0, 19]
			sub temp_x, cl
			jmp p6
			
		p2:		; U
			dec temp_y
			jmp p6
			
		p3:		; R
			mov dl, 2
			add temp_x, dl
			jmp p6
			
		p4:		; D
			inc temp_y
			jmp p6
			
		p5:		; L
			mov dl, 2
			sub temp_x, dl
			jmp p6
			
	write_grid endp
	
	; Prints the current grid
	print_grid proc
		xor si, si
		xor bh, bh
		
		p0:			
			; Convert grid index to coordinates						
			mov ax, si
			mov cl, 10	
			
			div cl
			mov dh, al			; y = i / 10
			
			mov al, ah			
			mov cl, 2
			mul cl
			
			mov dl, 31		
			add dl, al			; Translate x-coord in screen
			
			; Move cursor to corresponding position in grid
			mov ah, 02h
			int 10h
		
			mov al, 219
			xor bh, bh
			mov bl, [grid+si]
			mov cx, 2
			
			; Print block at current position
			mov ah, 09h
			int 10h
			
			inc si
			
			cmp si, 250
			jne p0
			
			ret
	print_grid endp
	
	print_game_over proc
		xor bh, bh				; page number		
		mov bl, 0Fh				; white
		mov cx, 20				; one whole row
		mov al, ' '				; blank character
		
		mov dl, 31				; x-coord
		mov dh, 11				; y-coord
		mov ah, 02h
		int 10h
		
		; Make font color at current row to white
		mov ah, 09h
		int 10h
				
		lea dx, msg_gameover1
		mov ah, 09h
		int 21h
		
		mov dl, 31				; x-coord
		mov dh, 13				; y-coord
		mov ah, 02h
		int 10h
		
		; Make font color at current row to white
		mov ah, 09h
		int 10h
				
		lea dx, msg_gameover2
		mov ah, 09h
		int 21h
		
		mov dl, 31				; x-coord
		mov dh, 14				; y-coord
		mov ah, 02h
		int 10h
		
		; Make font color at current row to white
		mov ah, 09h
		int 10h
				
		lea dx, msg_gameover3
		mov ah, 09h
		int 21h
		
		p0:
		mov ah, 00h
		int 16h
		
		cmp al, 13
		jne p0
		
		ret
	print_game_over endp
	
	print_header proc
		xor bh, bh				; page number		
		mov bl, 0Eh				; white
		mov cx, 10				; one whole row
		mov al, ' '				; blank character
		
		; Print HOLD
		mov dl, 18				; x-coord
		mov dh, 1				; y-coord
		mov ah, 02h
		int 10h
		
		; Make font color at current row to white
		mov ah, 09h
		int 10h
				
		lea dx, msg_hold
		mov ah, 09h
		int 21h
		
		; Print NEXT
		mov dl, 54				; x-coord
		mov dh, 1				; y-coord
		mov ah, 02h
		int 10h
		
		; Make font color at current row to white
		mov ah, 09h
		int 10h
				
		lea dx, msg_next
		mov ah, 09h
		int 21h
		
		; Print LEVEL
		mov dl, 18				; x-coord
		mov dh, 10				; y-coord
		mov ah, 02h
		int 10h
		
		; Make font color at current row to white
		mov ah, 09h
		int 10h
				
		lea dx, msg_level
		mov ah, 09h
		int 21h
		
		; Print GOAL
		mov dl, 18				; x-coord
		mov dh, 13				; y-coord
		mov ah, 02h
		int 10h
		
		; Make font color at current row to white
		mov ah, 09h
		int 10h
				
		lea dx, msg_goal
		mov ah, 09h
		int 21h
		
		; Print TIME
		mov dl, 18				; x-coord
		mov dh, 16				; y-coord
		mov ah, 02h
		int 10h
		
		; Make font color at current row to white
		mov ah, 09h
		int 10h
				
		lea dx, msg_time
		mov ah, 09h
		int 21h	
		
		
		xor bh, bh				; page number		
		mov bl, 0Fh				; white
		mov cx, 1				; one whole row
		mov al, 219				; blank character
		
		mov dl, 30				; x-coord
		mov dh, 0				; y-coord
		
		p1:
			mov ah, 02h
			int 10h
			
			mov ah, 09h
			int 10h
					
			mov dl, 51
			
			mov ah, 02h
			int 10h
			
			mov ah, 09h
			int 10h
			
			mov dl, 30
			inc dh
			
			cmp dh, 25
			jne p1
		
		ret
	print_header endp
	
	print_goal proc
		; Print current goal
		xor ah, ah
		mov al, stage_goal
		lea bx, str_goal
		mov cx, 3
		call itos
		
		mov al, '$'
		mov [str_time+4], al 
		
		xor bh, bh				; page number		
		mov bl, 0Fh				; white
		mov cx, 10				; one whole row
		mov al, ' '				; blank character
		
		mov dl, 18				; x-coord
		mov dh, 14				; y-coord
		mov ah, 02h
		int 10h
		
		; Make font color at current row to white
		mov ah, 09h
		int 10h
				
		lea dx, str_goal
		mov ah, 09h
		int 21h
		
		ret
	print_goal endp
	
	print_level proc
		; Print current level
		xor ah, ah
		mov al, stage_level
		lea bx, str_level
		mov cx, 2
		call itos
		
		mov al, '$'
		mov [str_time+3], al 
		
		xor bh, bh				; page number		
		mov bl, 0Fh				; white
		mov cx, 10				; one whole row
		mov al, ' '				; blank character
		
		mov dl, 18				; x-coord
		mov dh, 11				; y-coord
		mov ah, 02h
		int 10h
		
		; Make font color at current row to white
		mov ah, 09h
		int 10h
				
		lea dx, str_level
		mov ah, 09h
		int 21h
			
		ret
	print_level endp
	
	print_clock proc
		; Print current time		
		xor ah, ah
		mov al, stage_time
		mov cl, 60
		div cl
		mov [str_time+3], ah
		
		; Minute mark
		xor ah, ah
		lea bx, str_time
		mov cx, 2
		call itos
			
		mov al, ':'
		mov [str_time+2], al
		
		xor ah, ah
		mov al, [str_time+3]
		mov bx, offset str_time+3
		mov cx, 2
		call itos
		
		mov al, '$'
		mov [str_time+5], al 
		
		xor bh, bh				; page number		
		mov bl, 0Fh				; white
		mov cx, 10				; one whole row
		mov al, ' '				; blank character
		
		mov dl, 18				; x-coord
		mov dh, 17				; y-coord
		mov ah, 02h
		int 10h
		
		; Make font color at current row to white
		mov ah, 09h
		int 10h
		
		lea dx, str_time
		mov ah, 09h
		int 21h
		
		ret
	print_clock endp
	
	check_stage proc
		cmp stage_time, 0
		jne p1		
		mov flag, 5
		ret
		
		p1:
		cmp stage_goal, 0
		je p2
		ret
		
		p2:
		inc stage_level
		dec stage_speed
		mov stage_time, 150		
		cmp stage_level, 20			; constant 100
		jl p3
		
		mov ax, 100
		jmp p4
		
		p3:
		mov cl, stage_level
		mov ax, 5
		mul cl
		
		p4:		
		mov stage_goal, al
		mov flag, 6
		
		ret
	check_stage endp
	
	print_options proc		
		xor bh, bh				; page number
		mov bl, 0Fh				; white
		mov cx, 20				; one whole row
		mov al, ' '				; blank character
		
		mov dl, 31				; x-coord
		mov dh, 9				; y-coord
		
		p0:
			mov ah, 02h
			int 10h
			
			mov ah, 09h
			int 10h
			
			inc dh
			cmp dh, 16
			jne p0
	
		mov bl, 0Eh
		
		mov dl, 31				; x-coord
		mov dh, 9				; y-coord
		mov ah, 02h
		int 10h
		mov ah, 09h
		int 10h
		lea dx, msg_main1
		mov ah, 09h
		int 21h	
		
		mov dl, 31				; x-coord
		mov dh, 11				; y-coord
		mov ah, 02h
		int 10h
		lea dx, msg_main2
		mov ah, 09h
		int 21h	
		
		mov dl, 31				; x-coord
		mov dh, 12				; y-coord
		mov ah, 02h
		int 10h
		lea dx, msg_main3
		mov ah, 09h
		int 21h	
		
		mov dl, 31				; x-coord
		mov dh, 13				; y-coord
		mov ah, 02h
		int 10h
		lea dx, msg_main4
		mov ah, 09h
		int 21h	
		
		mov dl, 31				; x-coord
		mov dh, 14				; y-coord
		mov ah, 02h
		int 10h
		lea dx, msg_main5
		mov ah, 09h
		int 21h	
		
		mov dl, 31				; x-coord
		mov dh, 15				; y-coord
		mov ah, 02h
		int 10h
		lea dx, msg_main6
		mov ah, 09h
		int 21h	
		
		ret
	print_options endp
	
	select_options proc
		
		
		p5:		
		; Print new selected option
		mov dl, 33				; x-coord
		mov dh, 11				; y-coord
		add dh, user_choice
		mov ah, 02h
		int 10h
		
		mov bx, 000Eh
		mov cx, 1
		mov al, '>'
		mov ah, 09h
		int 10h
			
		p0:
		mov ah, 00h
		int 16h
		
		mov cx, ax
		
		; Clear current selected option
		mov dl, 33				; x-coord
		mov dh, 11				; y-coord
		add dh, user_choice
		
		mov ah, 02h
		int 10h
		
		mov dl, ' '
		mov ah, 02h
		int 21h

		mov ax, cx
			
		cmp ah, 72				; up arrow key
		je p1
		cmp ah, 80				; down arrow key
		je p2
		cmp al, 13				; enter key
		jne p5
		
		ret
		
		p1:
			
			cmp user_choice, 0
			jne p3
			mov user_choice, 5
			
			p3:
			dec user_choice
			jmp p5
			
		p2:			
			cmp user_choice, 4
			jne p4
			mov user_choice, 255
			
			p4:
			inc user_choice
			jmp p5
	select_options endp
	
	init_tetris proc
		; Set initial coordinates of new tetrimino
		mov x, 41
		mov y, 0
		
		call random_tetrimino
		call get_tetrimino
		call random_tetrimino
		
		mov flag, 6
		mov hold_flag, 0
		mov clock, 0
		mov stage_level, 1			; current stage
		mov stage_goal, 5			; lines left at current stage
		mov stage_time, 180			; current clock at current stage
		mov stage_speed, 18			; current speed at current stage
	
		; Clear grid
		xor si, si
		xor cl, cl
		p0:
			mov [grid+si], cl
			inc si
			
			cmp si, 250
			jne p0
		
		ret
	init_tetris endp
	
	init_scores proc
		; Open high score file
		
		xor al, al				; read only
		lea dx, high_path
		mov ah, 3Dh					
		int 21h
		
		mov high_handle, ax
		jnc p0					; file exists

		; Create high score file
		lea dx, high_path
		xor cx, cx				; ordinary file
		mov ah, 3Ch
		int 21h
		
		mov high_handle, ax
		ret

		p0:		
			; Get contents of high score file
			mov bx, high_handle
			mov cx, 40
			lea dx, high_buffer
			mov ah, 3Fh
			int 21h
			
			; Close high score file
			mov bx, high_handle
			mov ah, 3Eh
			int 21h
		
			ret
	init_scores endp
	
	init_record proc
		xor di, di
		
		; Get name from buffer
		p1:
			mov cl, [high_buffer+si]
			mov [str_name+di], cl
			
			inc si
			inc di
			
			cmp di, 3
			jne p1
			
			mov cl, '$'
			mov [str_name+di], cl
			xor di, di
			
		; Get level from buffer
		p2:
			mov cl, [high_buffer+si]
			mov [str_level+di], cl
			
			inc si
			inc di
			
			cmp di, 2
			jne p2
			
			mov cl, '$'
			mov [str_level+di], cl
			xor di, di
			
		; Get remaining goal from buffer
		p3:
			mov cl, [high_buffer+si]
			mov [str_goal+di], cl
			
			inc si
			inc di
			
			cmp di, 3
			jne p3
			
			mov cl, '$'
			mov [str_goal+di], cl
			xor di, di
			
		ret
	init_record endp
	
	; Prints all ranked scores
	print_scores proc
		mov al, ' '
		mov bx, 000Eh
		mov cx, 20
		
		mov dl, 31
		mov dh, 9
		mov ah, 02h
		int 10h

		mov ah, 09h
		int 10h
		
		lea dx, msg_head_scores
		mov ah, 09h
		int 21h
		
		mov al, ' '
		mov bx, 000Fh
		mov cx, 20
		
		mov dl, 31
		mov dh, 11
		mov ah, 02h
		int 10h

		mov ah, 09h
		int 10h
		
		lea dx, msg_head_table
		mov ah, 09h
		int 21h
		
		mov al, ' '
		
		xor bh, bh
		mov dl, 31
		mov dh, 12
		
		xor si, si				; counter		
		p0:
			xor cl, cl
			cmp [high_buffer+si], cl
			jne p1
			
			ret
			
		p1:
			call init_record
			
			mov ah, 02h
			int 10h
			
			cmp dh, 12
			je p1g
			cmp dh, 13
			je p1s
			
			mov bl, 0Fh
			jmp p2
		
		p1g:
			mov bl, 0Eh
			jmp p2
		p1s:
			mov bl, 07h
			jmp p2
		
		p2:	
			mov cx, 20			
			mov ah, 09h
			int 10h
			
			; Print NAME
			lea dx, str_name
			mov ah, 09h
			int 21h
			
			; Print LEVELS
			mov ah, 03h
			int 10h
			
			mov dl, 38
			mov ah, 02h
			int 10h			
			
			lea dx, str_level
			mov ah, 09h
			int 21h
			
			; Print GOALS
			mov ah, 03h
			int 10h
			
			mov dl, 46
			mov ah, 02h
			int 10h			
			
			lea dx, str_goal
			mov ah, 09h
			int 21h
			
			mov ah, 03h
			int 10h
			
			mov dl, 31
			inc dh
		
			jmp p0
	print_scores endp
	
	print_new_score proc
		xor bh, bh				; page number		
		mov bl, 0Fh				; white
		mov cx, 20				; one whole row
		mov al, ' '				; blank character
		
		; Print NEW HIGHSCORE
		mov dl, 31				; x-coord
		mov dh, 13				; y-coord
		mov ah, 02h
		int 10h
		
		mov ah, 09h
		int 10h
		
		lea dx, msg_highscore1
		mov ah, 09h
		int 21h
		
		; Print ENTER YOUR NAME
		mov dl, 31				; x-coord
		mov dh, 14				; y-coord
		mov ah, 02h
		int 10h
		
		mov ah, 09h
		int 10h
		
		lea dx, msg_highscore2
		mov ah, 09h
		int 21h
		
		; Print BLANK
		mov dl, 31				; x-coord
		mov dh, 16				; y-coord
		mov ah, 02h
		int 10h
		
		mov ah, 09h
		int 10h
		
		lea dx, msg_highscore3
		mov ah, 09h
		int 21h
		
		; Print BLANK
		mov dl, 31				; x-coord
		mov dh, 17				; y-coord
		mov ah, 02h
		int 10h
		
		mov ah, 09h
		int 10h
		
		lea dx, msg_highscore3
		mov ah, 09h
		int 21h
		
		ret		
	print_new_score endp
	
	get_name proc
		; Show cursor
		mov cx, 0607h
		mov ah, 01h
		int 10h
		
		; Print default chars
		xor bh, bh
		mov bl, 0Fh
		mov cx, 1
		
		mov dl, 42
		mov dh, 17
		
		xor si, si
		p0:
			mov ah, 02h
			int 10h
			
			mov al, 'A'
			mov [str_name+si], al
			
			mov ah, 09h
			int 10h
			
			sub dl, 2
			inc si
			
			cmp si, 3
			jne p0
		
		; Highlight first character in name
		xor bh, bh
		mov dl, 38
		mov dh, 17
		
		mov ah, 02h
		int 10h
		
		xor si, si
		p1:
			mov ah, 00h
			int 16h
			
			; Check if left arrow key
			cmp ah, 75				
			je p2
			
			; Check if right arrow key
			cmp ah, 77				
			je p3

			; Check if down arrow key
			cmp ah, 80
			je p4
			
			; Check if up arrow key
			cmp ah, 72
			je p5
			
			cmp al, 13
			je p8
			jmp p1
		
		p6:			
			mov [str_name+si], al			
			mov ah, 09h
			int 10h
			
			jmp p1
			
		p7:
			
			mov ah, 02h
			int 10h
			
			jmp p1
			
		p2:					; go to previous index
			cmp dl, 38
			jne p2a
			mov dl, 44
			mov si, 3
			
			p2a:
			sub dl, 2
			dec si
			jmp p7
			
		p3:
			cmp dl, 42
			jne p3a
			mov dl, 36
			mov si, 255
			
			p3a:
			add dl, 2
			inc si
			jmp p7
			
		p4:
			mov al, [str_name+si]
			cmp al, 'Z'
			jne p4a
			mov al, '@'
			
			
			p4a:
			inc al
			jmp p6
		
		p5:
			mov al, [str_name+si]
			cmp al, 'A'
			jne p5a
			mov al, '['
			
			p5a:
			dec al
			jmp p6
			
		p8:
			ret
	get_name endp
	
	check_scores proc
		mov high_rank, 5			; current rank (5 is unranked)		
		mov dx, 32				; counter
		
		p0:
			mov si, dx
			
			call init_record
			cmp str_name, 0			; if uninitialized, check next record
			je p2
			
			; Compare results
			lea bx, str_level
			call stoi			
			
			cmp stage_level, al
			jg p2
			cmp stage_level, al
			jl p4				; end comparing of scores
			
			; If equal
			lea bx, str_goal
			call stoi
			
			cmp stage_goal, al
			jle p2
			jg p4
			
			p2:
				dec high_rank				
				cmp dx, 0
				je p4
				
				sub dx, 8
				jmp p0
		
		; Sort highscores
		p4:
			cmp high_rank, 5
			jl p10
			ret
		
		p10:
			
			call print_new_score
			call get_name
			
			xor ah, ah
			mov al, 8					
			mov cl, high_rank			
			mul cl				; ax contains index of new entry		
				
			mov si, 31
		
		p5:
			cmp ax, si
			jg p6
			
			mov cl, [high_buffer+si]
			mov [high_buffer+si+8], cl
			
			cmp si, 0
			je p6
			
			dec si
			jmp p5
			
		p6:					; Write current entry to buffer
		
			; Convert entry's level reached to string
			xor ah, ah
			mov al, stage_level
			lea bx, str_level
			mov cx, 2
			call itos
			
			; Convert entry's goal lines remaining to string
			xor ah, ah
			mov al, stage_goal
			lea bx, str_goal
			mov cx, 3
			call itos
		
			xor ah, ah
			mov al, 8					
			mov cl, high_rank			
			mul cl				; ax contains index of new entry
		
			mov si, ax			; index of current entry
			xor di, di
			
		; Write name
		p7:
			mov cl, [str_name+di]
			mov [high_buffer+si], cl
			
			inc si
			inc di
			
			cmp di, 3
			jne p7
			
			xor di, di
			
		p8:
			mov cl, [str_level+di]
			mov [high_buffer+si], cl
			
			inc si
			inc di
			
			cmp di, 2
			jne p8
			
			xor di, di
			
		p9:
			mov cl, [str_goal+di]
			mov [high_buffer+si], cl
			
			inc si
			inc di
			
			cmp di, 3
			jne p9
		
			; Write updated highs cores to file
			; Open high score file
			lea dx, high_path
			mov al, 1			; write
			mov ah, 3Dh
			int 21h
			
			mov high_handle, ax
			
			mov bx, high_handle
			mov cx, 40
			lea dx, high_buffer
			mov ah, 40h
			int 21h
			
			mov bx, high_handle
			mov ah, 3Eh
			int 21h
		
		ret		
	check_scores endp
	
	print_controls proc
		xor bh, bh				; page number
		mov bl, 0Eh				; white
		mov cx, 11				; one whole row
		mov al, ' '				; blank character
		
		mov dl, 25				; x-coord
		mov dh, 11				; y-coord
		
		p0:
			mov ah, 02h
			int 10h
			
			mov ah, 09h
			int 10h
			
			inc dh
			cmp dh, 18
			jne p0
			
			
		mov bl, 0Fh				; white
		mov cx, 25				; one whole row
		
		mov dl, 40				; x-coord
		mov dh, 11				; y-coord
		
		p1:
			mov ah, 02h
			int 10h
			
			mov ah, 09h
			int 10h
			
			inc dh
			cmp dh, 18
			jne p1
		
		mov bl, 0Eh
		mov cx, 20
		
		mov dl, 31
		mov dh, 9
		mov ah, 02h
		int 10h
		mov ah, 09h
		int 10h
		lea dx, msg_head_control
		mov ah, 09h
		int 21h
		
		mov dl, 25				; x-coord
		mov dh, 11				; y-coord
		mov ah, 02h
		int 10h			
		lea dx, msg_control_key1
		mov ah, 09h
		int 21h
		
		mov dl, 25				; x-coord
		mov dh, 12				; y-coord
		mov ah, 02h
		int 10h
		lea dx, msg_control_key2
		mov ah, 09h
		int 21h
		
		mov dl, 25				; x-coord
		mov dh, 13				; y-coord
		mov ah, 02h
		int 10h
		lea dx, msg_control_key3
		mov ah, 09h
		int 21h
		
		mov dl, 25				; x-coord
		mov dh, 14				; y-coord
		mov ah, 02h
		int 10h
		lea dx, msg_control_key4
		mov ah, 09h
		int 21h
		
		mov dl, 25				; x-coord
		mov dh, 15				; y-coord
		mov ah, 02h
		int 10h
		lea dx, msg_control_key5
		mov ah, 09h
		int 21h
		
		mov dl, 25				; x-coord
		mov dh, 16				; y-coord
		mov ah, 02h
		int 10h
		lea dx, msg_control_key6
		mov ah, 09h
		int 21h
		
		mov dl, 25				; x-coord
		mov dh, 17				; y-coord
		mov ah, 02h
		int 10h
		lea dx, msg_control_key7
		mov ah, 09h
		int 21h
		
		mov dl, 40				; x-coord
		mov dh, 11				; y-coord
		mov ah, 02h
		int 10h
		lea dx, msg_control_def1
		mov ah, 09h
		int 21h
		
		mov dl, 40				; x-coord
		mov dh, 12				; y-coord
		mov ah, 02h
		int 10h
		lea dx, msg_control_def2
		mov ah, 09h
		int 21h
		
		mov dl, 40				; x-coord
		mov dh, 13				; y-coord
		mov ah, 02h
		int 10h
		lea dx, msg_control_def3
		mov ah, 09h
		int 21h
		
		mov dl, 40				; x-coord
		mov dh, 14				; y-coord
		mov ah, 02h
		int 10h
		lea dx, msg_control_def4
		mov ah, 09h
		int 21h
		
		mov dl, 40				; x-coord
		mov dh, 15				; y-coord
		mov ah, 02h
		int 10h
		lea dx, msg_control_def5
		mov ah, 09h
		int 21h
		
		mov dl, 40				; x-coord
		mov dh, 16				; y-coord
		mov ah, 02h
		int 10h
		lea dx, msg_control_def6
		mov ah, 09h
		int 21h
		
		mov dl, 40				; x-coord
		mov dh, 17				; y-coord
		mov ah, 02h
		int 10h
		lea dx, msg_control_def7
		mov ah, 09h
		int 21h
		
		ret
	print_controls endp
	
	print_about proc
		xor bh, bh				; page number
		mov bl, 0Fh				; white
		mov cx, 22				; one whole row
		mov al, ' '				; blank character
		
		mov dl, 30				; x-coord
		mov dh, 9				; y-coord
		
		p0:
			mov ah, 02h
			int 10h
			
			mov ah, 09h
			int 10h
			
			inc dh
			cmp dh, 22
			jne p0
			
		mov bl, 0Eh
		
		mov dl, 31				; x-coord
		mov dh, 9				; y-coord
		mov ah, 02h
		int 10h
		mov ah, 09h
		int 10h
		lea dx, msg_main1
		mov ah, 09h
		int 21h	
		
		mov dl, 30				; x-coord
		mov dh, 11				; y-coord
		mov ah, 02h
		int 10h
		lea dx, msg_about1
		mov ah, 09h
		int 21h
		
		mov dl, 30				; x-coord
		mov dh, 12				; y-coord
		mov ah, 02h
		int 10h
		lea dx, msg_about2
		mov ah, 09h
		int 21h	
		
		mov dl, 30				; x-coord
		mov dh, 13				; y-coord
		mov ah, 02h
		int 10h
		lea dx, msg_about3
		mov ah, 09h
		int 21h
		
		mov dl, 30				; x-coord
		mov dh, 14				; y-coord
		mov ah, 02h
		int 10h
		mov ah, 09h
		int 10h
		lea dx, msg_about4
		mov ah, 09h
		int 21h	
		
		mov dl, 30				; x-coord
		mov dh, 15				; y-coord
		mov ah, 02h
		int 10h
		lea dx, msg_about5
		mov ah, 09h
		int 21h
		
		mov dl, 30				; x-coord
		mov dh, 16				; y-coord
		mov ah, 02h
		int 10h
		lea dx, msg_about6
		mov ah, 09h
		int 21h	
		
		mov dl, 30				; x-coord
		mov dh, 18				; y-coord
		mov ah, 02h
		int 10h
		mov ah, 09h
		int 10h
		lea dx, msg_about7
		mov ah, 09h
		int 21h
		
		mov dl, 30				; x-coord
		mov dh, 19				; y-coord
		mov ah, 02h
		int 10h
		lea dx, msg_about8
		mov ah, 09h
		int 21h	
		
		
		ret
	print_about endp
	
	; Converts an integer loaded in ax
	; into a string loaded in bx
	; and the number of characters on cx
	itos proc
		mov si, bx
		mov dl, 10
			
		p0:					; convert number to ascii
			div dl
			
			add ah, '0'		
			mov [bx], ah
			
			xor ah, ah
			inc bx
			dec cx
			
			cmp cx, 0
			jne p0
		
			mov di, bx			; string length
			dec di
		
			mov dl, '$'
			mov [bx], dl
		
		p2:					; reverse string
			mov dl, [si]
			mov dh, [di]
			mov [si], dh
			mov [di], dl
			
			inc si
			dec di
			
			cmp si, di
			jl p2
			
			xor bx, bx
		ret				
	itos endp
	
	; Converts a string loaded on bx (not an empty string)
	; into an integer loaded in ax
	stoi proc
		xor ax, ax
		
		p0:
			mov cl, 10
			mul cl				; multiply current sum by 10
			
			xor ch, ch
			mov cl, [bx]
			sub cl, '0'			; convert to integer
			
			add ax, cx			; add current integer
			inc bx
			
			mov cl, '$'
			cmp [bx], cl
			jne p0
		
		ret
	stoi endp
	
	main proc
		; start
		mov ax, @data
		mov ds, ax
		
		; Set video mode
		mov ax, 0003h
		int 10h
		
		; Hide cursor
		mov cx, 3200h
		mov ah, 01h
		int 10h
		
		
		call init_scores
		
		options_menu:
			mov user_choice, 0
			call clear_screen
			
			call print_options
			call select_options
				
			cmp user_choice, 0
			je start_tetris
			cmp user_choice, 1
			je controls
			cmp user_choice, 2
			je high_scores
			cmp user_choice, 3
			je about
			cmp user_choice, 4
			je fin
			
			jmp options_menu
		
		about:
			call clear_screen
			call print_about
			
			mov ah, 01h
			int 21h
			jmp options_menu
			
		controls:
			call clear_screen
			call print_controls
			
			mov ah, 01h
			int 21h
			
			jmp options_menu
			
		high_scores:
			call clear_screen
			call print_scores
			
			mov ah, 01h
			int 21h
			
			jmp options_menu
			
		start_tetris:
			call clear_screen
			call print_header
			call init_tetris
		
		tetris:	
			call delay
			call print_clock
			
			call check_stage
			cmp flag, 5
			je game_over
			cmp flag, 6
			jne pre_action
			
			call print_level
			call print_goal
			
		pre_action:	
			call print_grid
			call check_tetrimino
				
			cmp flag, 0
			je not_landed
			cmp flag, 2
			je game_over
			jmp landed
		
		not_landed:
			call print_ghost
			call get_input
		
			cmp flag, 0
			jne landed
			

			call print_tetrimino
			jmp tetris
			
		game_over:
			call check_scores
			call print_game_over
			
			
			jmp options_menu
				
		landed:
			call write_grid
			call check_grid
			call clear_grid
			
			call print_goal
			
			; Set initial coordinates of new tetrimino
			mov x, 41
			mov y, 0
		
			; Get next tetrimino
			mov cl, tet_next
			mov tet_now, cl
		
		prep:
			call get_tetrimino			
			call random_tetrimino		; generate next tetrimino
			mov hold_flag, 0
			
			jmp tetris
			
		fin:
		call clear_screen
		
		mov ax, 4c00h
		int 21h
	main endp
end main
