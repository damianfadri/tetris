.model small
.data

    flag db 0                       ; 1 if collision, 2 if dead, 3 if out of bounds, 4 if landed, 5 if times up, 6 if new level
    hold_flag db 0                  ; 1 if recently held something

    clock db 0
    user_choice db 0                ; selected page

    stage_level db 1                ; current stage
    stage_goal db 5                 ; lines left at current stage
    stage_time db 180               ; current clock at current stage
    stage_speed db 18               ; current speed at current stage

    tet_color db 09h                ; also its type (I, J, L, O, S, Z, T)
    tet_rotate db 0                 ; 0 = normal, 1 = 90 deg cw, 2 = 180 deg, 3 = 90 deg ccw
    tet_length db 0

    tet_now db 0
    tet_next db 0                   ; 0 to 6
    tet_hold db 9                   ; 0 to 6
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
    print_flag proc
        mov dl, 0
        mov dh, 0
        xor bh, bh


        mov ah, 02h
        int 10h

        mov al, flag
        add al, '0'

        mov cx, 1

        mov ah, 09h
        int 10h
        ret
    print_flag endp

    clear_screen proc
        mov ax, 0003h               ; Set video mode
        int 10h

        mov cx, 3200h
        mov ah, 01h
        int 10h

        ret
    clear_screen endp

    ; Generate a delay in between lines of code 
    delay proc
        mov ah, 00                  ; Hide cursor
        int 1Ah
        mov bx, dx

        delay_loop:
            int 1Ah
            sub dx, bx
            cmp dl, 1
            jl delay_loop

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
        jne update_clock_start
        inc y                       ; bring tetrimino 1 row down

        update_clock_start:
            cmp clock, 18
            jne update_clock_end
            mov clock, 0            ; reset clock counter
            dec stage_time

        update_clock_end:
            ret
    update_clock endp

    ; Find position of tetrimino for a hard drop
    hard_drop proc
        inc ghost_y                 ; Set position of ghost tetrimino as the tetrimino's coords
        mov cl, ghost_y
        mov y, cl

        mov flag, 4
        ret 
    hard_drop endp

    ; Find position of tetrimino for a counter-clockwise rotate
    rotate_ccw proc
        dec tet_rotate              ; change rotate value
        cmp tet_rotate, 255         ; check if rotate value is 255 
        je rotate_ccw_initial       ; loop back to 3
        jmp try_rotate_ccw

        rotate_ccw_initial:
            mov tet_rotate, 3

        try_rotate_ccw:
            call adjust_tetrimino
            call check_tetrimino    ; check if there are collisions

            cmp flag, 1
            je revert_rotate_ccw    ; revert changes if so
            cmp flag, 3             ; if out of bounds, move to rotate
            je try_move_to_rotate_ccw
            ret                     ; if no collision, end

        try_move_to_rotate_ccw:
            mov cl, x
            mov ch, y
            mov ghost_x, cl         ; store current x-coord
            mov ghost_y, ch         ; store current y-coord

            cmp y, 2
            jge check_side_out_of_bounds_ccw

        try_move_up_rotate_ccw:
            inc y
            call check_tetrimino

            cmp flag, 1             ; revert y-coord and rotate value
            je revert_rotate_ccw_start
            cmp flag, 3
            je try_move_up_rotate_ccw

            ret

        check_side_out_of_bounds_ccw:
            cmp x, 40
            jle try_move_right_rotate_ccw
            jg try_move_left_rotate_ccw

        try_move_right_rotate_ccw:
            add x, 2
            call check_tetrimino

            cmp flag, 1             ; if there's a collision
            je revert_rotate_ccw_start
            cmp flag, 3             ; if still out of bounds
            je try_move_right_rotate_ccw

            ret

        try_move_left_rotate_ccw:
            sub x, 2
            call check_tetrimino

            cmp flag, 1             ; if there's a collision
            je revert_rotate_ccw_start
            cmp flag, 3             ; if still out of bounds
            je try_move_left_rotate_ccw

            ret

        revert_rotate_ccw_start:
            mov cl, ghost_x
            mov ch, ghost_y
            mov x, cl
            mov y, ch
            jmp revert_rotate_ccw

        revert_rotate_ccw:
            mov cl, 1
            inc tet_rotate          ; revert to original rotate value
            cmp tet_rotate, cl      ; check if rotate value is 255
            je revert_rotate_ccw_initial 

            jmp rotate_ccw_update

        revert_rotate_ccw_initial:
            mov tet_rotate, 0

        rotate_ccw_update:
            call adjust_tetrimino
            ret

    rotate_ccw endp

    ; Find position of tetrimino for a clockwise rotate
    rotate_cw proc
        mov cl, 4
        inc tet_rotate              ; change rotate value
        cmp tet_rotate, cl          ; check if rotate value is 4 
        je rotate_cw_initial        ; loop back to 0
        jmp try_rotate_cw

        rotate_cw_initial:
            mov tet_rotate, 0

        try_rotate_cw:
            call adjust_tetrimino
            call check_tetrimino    ; check if there are collisions
            
            cmp flag, 1
            je revert_rotate_cw     ; revert changes if so
            cmp flag, 3             ; if out of bounds, move to rotate
            je try_move_to_rotate_cw

            ret                     ; if no collision, end

        try_move_to_rotate_cw:
            mov cl, x
            mov ch, y
            mov ghost_x, cl         ; store current x-coord
            mov ghost_y, ch         ; store current y-coord

            cmp y, 1
            jge check_side_out_of_bounds_cw

        try_move_up_rotate_cw:
            inc y
            call check_tetrimino

            cmp flag, 1             ; revert y-coord and rotate value
            je revert_rotate_cw_start
            cmp flag, 3
            je try_move_up_rotate_cw

            ret

        check_side_out_of_bounds_cw: ;p10
            cmp x, 40
            jle try_move_right_rotate_cw
            jg try_move_left_rotate_cw

        try_move_right_rotate_cw: ;p6
            add x, 2
            call check_tetrimino

            cmp flag, 1             ; if there's a collision
            je revert_rotate_cw_start
            cmp flag, 3             ; if still out of bounds
            je try_move_right_rotate_cw

            ret

        try_move_left_rotate_cw: ;p7
            sub x, 2
            call check_tetrimino

            cmp flag, 1             ; if there's a collision
            je revert_rotate_cw_start
            cmp flag, 3             ; if still out of bounds
            je try_move_left_rotate_cw

            ret

        revert_rotate_cw_start: ;p8
            mov cl, ghost_x
            mov ch, ghost_y
            mov x, cl
            mov y, ch
            jmp revert_rotate_cw

        revert_rotate_cw: ;p2
            mov cl, 255
            dec tet_rotate          ; revert to original rotate value
            cmp tet_rotate, cl      ; check if rotate value is 255
            je revert_rotate_cw_initial

            jmp rotate_cw_update

        revert_rotate_cw_initial: ;p3
            mov tet_rotate, 3

        rotate_cw_update: ;p4
            call adjust_tetrimino
            ret
    rotate_cw endp

    ; Holds the current tetrimino for later use
    hold_tetrimino proc
        cmp hold_flag, 1            ; if user just held a tetrimino, ignore hold input
        jne process_hold_tetrimino
        ret

        process_hold_tetrimino:
            mov cl, tet_now
            mov ch, tet_hold

            cmp ch, 9               ; if user's first hold
            je set_held_tetrimino

            mov tet_now, ch
            mov tet_hold, cl

            jmp print_held_tetrimino

        set_held_tetrimino:
            mov ch, tet_next

            mov tet_hold, cl
            mov tet_now, ch

        print_held_tetrimino:
            mov x, 41
            mov y, 0
            call get_tetrimino
            mov hold_flag, 1

            call print_hold

            ret
    hold_tetrimino endp

    ; Generate a random tetrimino
    random_tetrimino proc
        random_tetrimino_loop:
            mov ah, 00h
            int 1Ah

            mov ax, dx
            xor dx, dx
            mov cx, 7               ; 7 different tetriminos
            div cx                  ; contains the type of the generated tetrimino

            cmp dl, tet_now
            je random_tetrimino_loop

        mov tet_next, dl
        call print_preview

        ret
    random_tetrimino endp

    ; Generates the current tetrimino object
    get_tetrimino proc
        mov dl, tet_now

        cmp dl, 0
        je get_tetrimino_o
        cmp dl, 1
        je get_tetrimino_i
        cmp dl, 2
        je get_tetrimino_j
        cmp dl, 3
        je get_tetrimino_l
        cmp dl, 4
        je get_tetrimino_s
        cmp dl, 5
        je get_tetrimino_z
        cmp dl, 6
        je get_tetrimino_t

        perform_tetrimino_adjustments:
            call adjust_tetrimino
            ret

        get_tetrimino_o:
            mov tet_rotate, 0       ; normal state
            mov tet_length, 4       ; substring of length 4
            mov tet_color, 07h      ; gray

            jmp perform_tetrimino_adjustments

        get_tetrimino_i:
            mov tet_rotate, 0       ; normal state
            mov tet_length, 5       ; substring of length 5
            mov tet_color, 03h      ; cyan

            jmp perform_tetrimino_adjustments

        get_tetrimino_j:
            mov tet_rotate, 0       ; normal state
            mov tet_length, 5       ; substring of length 5
            mov tet_color, 09h      ; blue

            jmp perform_tetrimino_adjustments

        get_tetrimino_l:
            mov tet_rotate, 0       ; normal state
            mov tet_length, 5       ; substring of length 5
            mov tet_color, 0Eh      ; yellow

            jmp perform_tetrimino_adjustments

        get_tetrimino_s:
            mov tet_rotate, 0       ; normal state
            mov tet_length, 5       ; substring of length 5
            mov tet_color, 0Ah      ; light green

            jmp perform_tetrimino_adjustments

        get_tetrimino_z:
            mov tet_rotate, 0       ; normal state
            mov tet_length, 5       ; substring of length 5
            mov tet_color, 0Ch      ; light red

            jmp perform_tetrimino_adjustments

        get_tetrimino_t:
            mov tet_rotate, 0       ; normal state
            mov tet_length, 6       ; substring of length 6
            mov tet_color, 0Dh      ; light magenta

            jmp perform_tetrimino_adjustments
    get_tetrimino endp
    
    ; Sets the value of tet_current according to the tetrimino's type and rotation
    adjust_tetrimino proc
        call search_tetrimino

        xor ah, ah                  ; Move pointer in main tetrimino string to current rotation
        mov al, tet_length
        mov di, ax                  ; contains the length of the tetrimino substring

        mov cl, tet_rotate
        mul cl

        add bx, ax                  ; pointer in main string currently in proper location

        xor si, si
        rotate_tetrimino_loop:
            mov cl, [bx]
            mov [tet_current+si], cl

            inc si
            inc bx

            cmp si, di
            jne rotate_tetrimino_loop

        xor cl, cl
        mov [tet_current+si], cl
        
        ret
    adjust_tetrimino endp
    
    ; Get the tetrimino sequence string based from a tetrimino color
    search_tetrimino proc
        mov cl, tet_color

        cmp cl, 07h                 ; O tetrimino
        je search_tetrimino_o
        cmp cl, 03h                 ; I tetrimino
        je search_tetrimino_i
        cmp cl, 09h                 ; J tetrimino
        je search_tetrimino_j
        cmp cl, 0Eh                 ; L tetrimino
        je search_tetrimino_l
        cmp cl, 0Ah                 ; S tetrimino
        je search_tetrimino_s
        cmp cl, 0Ch                 ; Z tetrimino
        je search_tetrimino_z
        cmp cl, 0Dh                 ; T tetrimino
        je search_tetrimino_t

        search_tetrimino_end:
            ret
            
        search_tetrimino_o:
            lea bx, tet_o
            jmp search_tetrimino_end
        search_tetrimino_i:
            lea bx, tet_i
            jmp search_tetrimino_end
        search_tetrimino_j:
            lea bx, tet_j
            jmp search_tetrimino_end
        search_tetrimino_l:
            lea bx, tet_l
            jmp search_tetrimino_end
        search_tetrimino_s:
            lea bx, tet_s
            jmp search_tetrimino_end
        search_tetrimino_z:
            lea bx, tet_z
            jmp search_tetrimino_end
        search_tetrimino_t:
            lea bx, tet_t
            jmp search_tetrimino_end
    search_tetrimino endp

    ; Process the keyboard input of a user during gameplay
    get_input proc
        mov ah, 01h                 ; Get input from keyboard
        int 16h

        jnz process_user_input
        jmp reset_input_flag

        process_user_input:
            mov ah, 00h
            int 16h

            cmp ah, 75              ; Check if left arrow key 
            je process_user_input_left

            cmp ah, 77              ; Check if right arrow key
            je process_user_input_right

            cmp al, 'c'             ; Check if hold
            je process_user_input_hold
            cmp al, 'C'
            je process_user_input_hold

            cmp al, 'z'             ; Check if rotate counter-clockwise
            je process_user_input_rotate_ccw
            cmp al, 'Z'
            je process_user_input_rotate_ccw

            cmp al, 'x'             ; Check if rotate clockwise
            je process_user_input_rotate_cw
            cmp al, 'X'
            je process_user_input_rotate_cw

            cmp al, ' '             ; Check if hard drop
            je process_user_input_hard_drop

            cmp ah, 80              ; Check if down arrow key (soft drop)
            je process_user_input_soft_drop

        reset_input_flag:
            mov flag, 0
            ret

        process_user_input_left:
            sub x, 2                ; translate x-coord 2 units to the left
            call check_tetrimino    ; check if there are collisions (0, 1, 3)

            cmp flag, 0
            jne revert_user_input_left
            jmp reset_input_flag

        revert_user_input_left:
            add x, 2                ; translate x-coord 2 units to the right
            jmp reset_input_flag

        process_user_input_right:
            add x, 2                ; translate x-coord 2 units to the right
            call check_tetrimino    ; check if there are collisions (0, 1, 3)

            cmp flag, 0
            jne revert_user_input_right
            jmp reset_input_flag

        revert_user_input_right:
            sub x, 2                ; translate x-coord 2 units to the left
            jmp reset_input_flag

        process_user_input_hold:
            call hold_tetrimino
            jmp reset_input_flag

        process_user_input_rotate_ccw:
            call rotate_ccw
            jmp reset_input_flag

        process_user_input_rotate_cw:
            call rotate_cw
            jmp reset_input_flag

        process_user_input_hard_drop:
            call hard_drop
            ret

        process_user_input_soft_drop:
            inc y                   ; bring tetrimino 1 row down
            call check_tetrimino
            ret
    get_input endp

    ; Check if current tetrimino collides with another
    ; Returns through flag variable
    check_tetrimino proc
        mov flag, 0
        mov al, tet_length
        xor ah, ah

        mov di, ax                  ; length of tet_current
        xor si, si                  ; counter

        check_tetrimino_loop:
            mov al, [tet_current+si]

            cmp al, 'C'
            je check_tetrimino_center
            cmp al, 'U'
            je check_tetrimino_up
            cmp al, 'R'
            je check_tetrimino_right
            cmp al, 'D'
            je check_tetrimino_down
            cmp al, 'L'
            je check_tetrimino_left
            ret

        check_tetrimino_center:
            mov cl, x
            mov ch, y

            mov temp_x, cl          ; x-coord [31, 50]
            mov temp_y, ch          ; y-coord [0, 24]

            sub temp_x, 31          ; Translate temp_x to [0, 19]
            jmp check_tetrimino_collision

        check_tetrimino_up:
            dec temp_y
            jmp check_tetrimino_collision

        check_tetrimino_right:
            add temp_x, 2
            jmp check_tetrimino_collision

        check_tetrimino_down:
            inc temp_y
            jmp check_tetrimino_collision

        check_tetrimino_left:
            sub temp_x, 2
            jmp check_tetrimino_collision

        check_tetrimino_loop_tmp:
            jmp check_tetrimino_loop

        check_tetrimino_collision:
            xor ah, ah
            mov al, temp_x

            mov cl, 2
            div cl

            xor ah, ah
            mov bx, ax              ; bx contains the grid index at (temp_x, 0)

            xor ah, ah
            mov al, temp_y

            mov cl, 10
            mul cl

            add bx, ax              ; i = y*10 + x/2

            xor cl, cl
            cmp [grid+bx], cl       ; check if a block already exists at the given coords
            jne collision_detected  ; if yes, theres a collision

            mov al, temp_x          ; Check if block is out of bounds
            mov ah, temp_y

            cmp al, 0
            jl set_out_of_bounds_flag
            cmp al, 19
            jg set_out_of_bounds_flag
            cmp ah, 0
            jl set_out_of_bounds_flag
            cmp ah, 24
            jg set_landed_flag

            inc si

            cmp si, di
            jne check_tetrimino_loop_tmp
            ret

        set_landed_flag:
            mov flag, 4             ; landed
            ret

        collision_detected:
            cmp y, 0                ; if current coordinate is NOT at the top
            jne set_collision_flag  ; ordinary collision

            mov flag, 2             ; dead
            ret

        set_out_of_bounds_flag:
            mov flag, 3             ; out of bounds
            ret

        set_collision_flag:
            mov flag, 1             ; ordinary collision
            ret
    check_tetrimino endp

    ; Print the next tetrimino
    print_preview proc
        xor bh, bh                  ; page
        mov al, 219                 ; full ASCII block

        mov dl, 54                  ; Top-right preview screen coordinates
        mov dh, 2

        clear_preview_screen:
            mov ah, 02h
            int 10h

            xor bl, bl
            mov cx, 10
            mov ah, 09h
            int 10h

            inc dh
            cmp dh, 7
            jne clear_preview_screen

        mov cl, tet_next            ; Print preview

        cmp cl, 0
        je print_preview_o
        cmp cl, 1
        je print_preview_i
        cmp cl, 2
        je print_preview_j
        cmp cl, 3
        je print_preview_l
        cmp cl, 4
        je print_preview_s
        cmp cl, 5
        je print_preview_z_temp
        cmp cl, 6
        je print_preview_t_temp

        print_preview_o:
            mov bl, 07h
            mov cx, 4

            mov dl, 57
            mov dh, 4

        print_preview_o_loop:
            mov ah, 02h
            int 10h

            mov ah, 09h
            int 10h

            inc dh
            cmp dh, 6
            jne print_preview_o_loop
            ret

        print_preview_i:
            mov bl, 03h
            mov cx, 2

            mov dl, 58
            mov dh, 3

        print_preview_i_loop:
            mov ah, 02h
            int 10h

            mov ah, 09h
            int 10h

            inc dh
            cmp dh, 7
            jne print_preview_i_loop
            ret

        print_preview_z_temp:
            jmp print_preview_z

        print_preview_t_temp:
            jmp print_preview_t

        print_preview_j:
            mov bl, 09h
            mov cx, 6

            mov dl, 56
            mov dh, 4

        print_preview_j_loop:
            mov ah, 02h
            int 10h

            mov ah, 09h
            int 10h

            inc dh
            sub cx, 4
            add dl, 4

            cmp dh, 6
            jne print_preview_j_loop
            ret

        print_preview_l:
            mov bl, 0Eh
            mov cx, 6

            mov dl, 56
            mov dh, 4

        print_preview_l_loop:
            mov ah, 02h
            int 10h

            mov ah, 09h
            int 10h

            inc dh
            sub cx, 4

            cmp dh, 6
            jne print_preview_l_loop
            ret

        print_preview_s:
            mov bl, 0Ah
            mov cx, 4

            mov dl, 58
            mov dh, 4

        print_preview_s_loop:
            mov ah, 02h
            int 10h

            mov ah, 09h
            int 10h

            inc dh
            sub dl, 2

            cmp dh, 6
            jne print_preview_s_loop
            ret

        print_preview_z:
            mov bl, 0Ch
            mov cx, 4
            
            mov dl, 56
            mov dh, 4
        
        print_preview_z_loop:
            mov ah, 02h
            int 10h

            mov ah, 09h
            int 10h

            inc dh
            add dl, 2

            cmp dh, 6
            jne print_preview_z_loop
            ret

        print_preview_t:
            mov bl, 0Dh
            mov cx, 6

            mov dl, 56
            mov dh, 4

        print_preview_t_loop:
            mov ah, 02h
            int 10h

            mov ah, 09h
            int 10h

            inc dh
            add dl, 2
            sub cx, 4

            cmp dh, 6
            jne print_preview_t_loop
            ret
    print_preview endp

    ; Print the held tetrimino
    print_hold proc
        xor bh, bh                  ; page
        mov al, 219                 ; full ASCII block

        mov dl, 18                  ; Top-right preview screen coordinates
        mov dh, 2

        clear_hold_screen:
            mov ah, 02h
            int 10h

            xor bl, bl
            mov cx, 10
            mov ah, 09h
            int 10h

            inc dh
            cmp dh, 7
            jne clear_hold_screen

        mov cl, tet_hold            ; Print hold

        cmp cl, 0
        je print_hold_o
        cmp cl, 1
        je print_hold_i
        cmp cl, 2
        je print_hold_j
        cmp cl, 3
        je print_hold_l
        cmp cl, 4
        je print_hold_s
        cmp cl, 5
        je print_hold_z_temp
        cmp cl, 6
        je print_hold_t_temp
        ret

        print_hold_o:
            mov bl, 07h
            mov cx, 4

            mov dl, 21
            mov dh, 4

        print_hold_o_loop:
            mov ah, 02h
            int 10h

            mov ah, 09h
            int 10h

            inc dh
            cmp dh, 6
            jne print_hold_o_loop
            ret

        print_hold_i:
            mov bl, 03h
            mov cx, 2

            mov dl, 22
            mov dh, 3

        print_hold_i_loop:
            mov ah, 02h
            int 10h

            mov ah, 09h
            int 10h

            inc dh
            cmp dh, 7
            jne print_hold_i_loop
            ret

        print_hold_z_temp:
            jmp print_hold_z

        print_hold_t_temp:
            jmp print_hold_t

        print_hold_j:
            mov bl, 09h
            mov cx, 6

            mov dl, 20
            mov dh, 4

        print_hold_j_loop:
            mov ah, 02h
            int 10h

            mov ah, 09h
            int 10h

            inc dh
            sub cx, 4
            add dl, 4

            cmp dh, 6
            jne print_hold_j_loop
            ret

        print_hold_l:
            mov bl, 0Eh
            mov cx, 6

            mov dl, 20
            mov dh, 4

        print_hold_l_loop:
            mov ah, 02h
            int 10h

            mov ah, 09h
            int 10h

            inc dh
            sub cx, 4

            cmp dh, 6
            jne print_hold_l_loop
            ret

        print_hold_s:
            mov bl, 0Ah
            mov cx, 4

            mov dl, 22
            mov dh, 4

        print_hold_s_loop:
            mov ah, 02h
            int 10h

            mov ah, 09h
            int 10h

            inc dh
            sub dl, 2

            cmp dh, 6
            jne print_hold_s_loop
            ret

        print_hold_z:
            mov bl, 0Ch
            mov cx, 4

            mov dl, 20
            mov dh, 4

        print_hold_z_loop:
            mov ah, 02h
            int 10h

            mov ah, 09h
            int 10h

            inc dh
            add dl, 2

            cmp dh, 6
            jne print_hold_z_loop
            ret

        print_hold_t:
            mov bl, 0Dh
            mov cx, 6

            mov dl, 20
            mov dh, 4

        print_hold_t_loop:
            mov ah, 02h
            int 10h

            mov ah, 09h
            int 10h

            inc dh
            add dl, 2
            sub cx, 4

            cmp dh, 6
            jne print_hold_t_loop
            ret
    print_hold endp

    ; Prints the current tetrimino
    print_tetrimino proc
        mov al, tet_length
        xor ah, ah

        mov di, ax                  ; length of tet_current
        xor si, si                  ; counter
        print_tetrimino_loop:
            mov al, [tet_current+si]

            cmp al, 'C'
            je move_to_tetrimino_center
            cmp al, 'U'
            je move_to_tetrimino_up
            cmp al, 'R'
            je move_to_tetrimino_right
            cmp al, 'D'
            je move_to_tetrimino_down
            cmp al, 'L'
            je move_to_tetrimino_left
            ret

        print_tetrimino_block:
            mov dl, temp_x          ; Move cursor to its proper place
            mov dh, temp_y
            xor bh, bh
            mov ah, 02h
            int 10h

            mov al, 219             ; full ASCII block
            xor bh, bh
            mov bl, tet_color       ; color
            mov cx, 2
            mov ah, 09h
            int 10h

            inc si

            cmp si, di
            jne print_tetrimino_loop
            ret

        move_to_tetrimino_center:
            mov dl, x
            mov dh, y
            mov temp_x, dl
            mov temp_y, dh
            jmp print_tetrimino_block

        move_to_tetrimino_up:
            dec temp_y
            jmp print_tetrimino_block

        move_to_tetrimino_right:
            mov dl, 2
            add temp_x, dl
            jmp print_tetrimino_block
            
        move_to_tetrimino_down:
            inc temp_y
            jmp print_tetrimino_block

        move_to_tetrimino_left:
            mov dl, 2
            sub temp_x, dl
            jmp print_tetrimino_block
    print_tetrimino endp

    print_ghost proc
        call check_ghost            ; at this point, ghost_x and ghost_y is set
        dec ghost_y                 ; fix y-coord

        mov al, tet_length
        xor ah, ah

        mov di, ax                  ; length of tet_current
        xor si, si                  ; counter
        print_ghost_loop:
            mov al, [tet_current+si]

            cmp al, 'C'
            je move_to_ghost_center
            cmp al, 'U'
            je move_to_ghost_up
            cmp al, 'R'
            je move_to_ghost_right
            cmp al, 'D'
            je move_to_ghost_down
            cmp al, 'L'
            je move_to_ghost_left
            ret

        print_ghost_block:
            mov dl, temp_x          ; Move cursor to its proper place
            mov dh, temp_y
            xor bh, bh
            mov ah, 02h
            int 10h

            mov al, 176             ; dotted ASCII block
            xor bh, bh
            mov bl, 07h             ; white
            mov cx, 2
            mov ah, 09h
            int 10h

            inc si

            cmp si, di
            jne print_ghost_loop
            ret

        move_to_ghost_center:       ; Restart coord to the primary coord
            mov dl, ghost_x
            mov dh, ghost_y
            mov temp_x, dl
            mov temp_y, dh
            jmp print_ghost_block

        move_to_ghost_up:           ; Up relative to the current coord
            dec temp_y
            jmp print_ghost_block

        move_to_ghost_right:        ; Right relative to the current coord
            mov dl, 2
            add temp_x, dl
            jmp print_ghost_block

        move_to_ghost_down:         ; Down relative to the current coord
            inc temp_y
            jmp print_ghost_block

        move_to_ghost_left:         ; Left relative to the current coord
            mov dl, 2
            sub temp_x, dl
            jmp print_ghost_block
    print_ghost endp

    check_ghost proc
        mov cl, x
        mov ghost_x, cl             ; store current x-coord
        mov cl, y
        mov ghost_y, cl             ; store current y-coord

        check_ghost_loop:
            call check_tetrimino    ; 0, 1, 4

            cmp flag, 0             ; Check if there's no collision at current position
            je check_ghost_next_row ; if no collision, check next row down

            mov ch, y               ; at this point, either the tetrimino has collided or is at the ground
            mov cl, ghost_y         ; Swap values of y and ghost_y

            mov ghost_y, ch
            mov y, cl
            ret

        check_ghost_next_row:
            inc y
            jmp check_ghost_loop
    check_ghost endp

    ; Checks if line/s have been completed
    ; Turns completed lines to white
    check_grid proc
        mov si, 240                 ; counter
        mov di, 250                 ; row upper limit

        check_complete_lines:
            xor cl, cl              ; black color/space in grid
            cmp [grid+si], cl
            je adjust_upper_limit   ; if a blank exists, it is NOT a complete line
            inc si                  ; check next element

            cmp si, di              ; if counter has reached row upper limit
            je set_row_to_white     ; also implies it is a complete line

            jmp check_complete_lines

        set_row_to_white:           ; color a whole line white (si = di)
            sub si, 10              ; start of row
            mov cl, 0Fh             ; change color to white

        set_row_to_white_loop:
            mov [grid+si], cl       ; change grid value to white

            inc si                  ; go to next element
            cmp si, di              ; if counter has reached row upper limit
            jne set_row_to_white_loop

        adjust_upper_limit:         ; adjust counter and row upper limit
            sub di, 10              ; set row upper limit for one row up

            cmp di, 0               ; check if reached end of grid
            jne move_one_row_up
            ret

        move_one_row_up:
            mov si, di
            sub si, 10              ; set counter for one row up

            jmp check_complete_lines
    check_grid endp

    ; Clears white lines in the grid
    clear_grid proc
        set_counters:
            mov si, 240             ; counter
            xor di, di              ; counter
        
        clear_grid_loop:
            mov cl, 0Fh             ; white
            cmp [grid+si], cl       ; check if first elt is NOT white
            jne process_row         ; proceed to next row
            
            add di, 10              ; offset for succeeding rows
            
            cmp stage_goal, 0
            je proceed_to_next_row
            
            dec stage_goal
            jmp proceed_to_next_row
            
        process_row:
            cmp di, 0               ; check if there are no white rows found
            je proceed_to_next_row  ; proceed to next row if none

            xor ax, ax              ; counter

        move_row_to_lower:
            mov bx, si
            add bx, di              ; row to be transferred to

            mov cl, [grid+si]       ; get current elt
            mov [grid+bx], cl       ; transfer current elt

            inc si
            add ax, 2

            cmp ax, 20
            jne move_row_to_lower

            cmp si, 10              ; check if last row
            je fill_row_with_blacks

            sub si, ax              ; next row
            xor ax, ax
            jmp move_row_to_lower
            
        fill_row_with_blacks:    
            xor si, si              ; counter
            xor cl, cl              ; black
            
        fill_row_with_blacks_loop:
            mov [grid+si], cl

            inc si

            cmp si, di
            jne fill_row_with_blacks_loop
            jmp set_counters

        proceed_to_next_row:
            sub si, 10

            cmp si, 0               ; check if reached end of grid
            jne clear_grid_loop
            ret
    clear_grid endp

    ; Writes the current tetrimino to the grid
    write_grid proc
        dec y                       ; write last position of tetrimino
        mov al, tet_length
        xor ah, ah

        mov di, ax                  ; length of tet_current
        xor si, si                  ; counter
        write_grid_loop:
            mov al, [tet_current+si]

            cmp al, 'C'
            je move_to_curr_center
            cmp al, 'U'
            je move_to_curr_up
            cmp al, 'R'
            je move_to_curr_right
            cmp al, 'D'
            je move_to_curr_down
            cmp al, 'L'
            je move_to_curr_left
            ret

        write_color_to_grid:
            xor ah, ah              ; Translate coordinates to grid index
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

            xor ah, ah              ; Set value for bx
            mov bx, ax

            mov cl, tet_color
            mov [grid+bx], cl

            inc si

            cmp si, di
            je write_grid_end
            jmp write_grid_loop

        write_grid_end:
            ret

        move_to_curr_center:
            mov dl, x
            mov dh, y
            mov cl, 31
            mov temp_x, dl          ; x-coord [31, 50]
            mov temp_y, dh          ; y-coord [0, 24]

            sub temp_x, cl          ; Translate temp_x to [0, 19]
            jmp write_color_to_grid

        move_to_curr_up:
            dec temp_y
            jmp write_color_to_grid

        move_to_curr_right:
            mov dl, 2
            add temp_x, dl
            jmp write_color_to_grid

        move_to_curr_down:
            inc temp_y
            jmp write_color_to_grid

        move_to_curr_left:
            mov dl, 2
            sub temp_x, dl
            jmp write_color_to_grid
    write_grid endp

    ; Prints the current grid
    print_grid proc
        xor si, si
        xor bh, bh

        print_grid_loop:
            mov ax, si              ; Convert grid index to coordinates
            mov cl, 10

            div cl
            mov dh, al              ; y = i / 10

            mov al, ah
            mov cl, 2
            mul cl

            mov dl, 31
            add dl, al              ; Translate x-coord in screen

            mov ah, 02h             ; Move cursor to corresponding position in grid
            int 10h

            mov al, 219
            xor bh, bh
            mov bl, [grid+si]
            mov cx, 2

            mov ah, 09h             ; Print block at current position
            int 10h

            inc si

            cmp si, 250
            jne print_grid_loop

            ret
    print_grid endp
    
    print_game_over proc
        xor bh, bh                  ; page number
        mov bl, 0Fh                 ; white
        mov cx, 20                  ; one whole row
        mov al, ' '                 ; blank character

        mov dl, 31                  ; x-coord
        mov dh, 11                  ; y-coord
        mov ah, 02h
        int 10h

        mov ah, 09h                 ; Make font color at current row to white
        int 10h

        lea dx, msg_gameover1
        mov ah, 09h
        int 21h

        mov dl, 31                  ; x-coord
        mov dh, 13                  ; y-coord
        mov ah, 02h
        int 10h

        mov ah, 09h                 ; Make font color at current row to white
        int 10h

        lea dx, msg_gameover2
        mov ah, 09h
        int 21h

        mov dl, 31                  ; x-coord
        mov dh, 14                  ; y-coord
        mov ah, 02h
        int 10h

        mov ah, 09h                 ; Make font color at current row to white
        int 10h

        lea dx, msg_gameover3
        mov ah, 09h
        int 21h

        wait_user_enter_key:
            mov ah, 00h
            int 16h

            cmp al, 13
            jne wait_user_enter_key

        ret
    print_game_over endp

    print_header proc
        xor bh, bh                  ; page number
        mov bl, 0Eh                 ; white
        mov cx, 10                  ; one whole row
        mov al, ' '                 ; blank character

        mov dl, 18                  ; x-coord
        mov dh, 1                   ; y-coord
        mov ah, 02h
        int 10h

        mov ah, 09h                 ; Make font color at current row to white
        int 10h

        lea dx, msg_hold
        mov ah, 09h
        int 21h

        mov dl, 54                  ; x-coord
        mov dh, 1                   ; y-coord
        mov ah, 02h
        int 10h

        mov ah, 09h                 ; Make font color at current row to white
        int 10h

        lea dx, msg_next
        mov ah, 09h
        int 21h

        mov dl, 18                  ; x-coord
        mov dh, 10                  ; y-coord
        mov ah, 02h
        int 10h

        mov ah, 09h                 ; Make font color at current row to white
        int 10h

        lea dx, msg_level
        mov ah, 09h
        int 21h

        mov dl, 18                  ; x-coord
        mov dh, 13                  ; y-coord
        mov ah, 02h
        int 10h

        mov ah, 09h                 ; Make font color at current row to white
        int 10h

        lea dx, msg_goal
        mov ah, 09h
        int 21h

        mov dl, 18                  ; x-coord
        mov dh, 16                  ; y-coord
        mov ah, 02h
        int 10h

        mov ah, 09h                 ; Make font color at current row to white
        int 10h

        lea dx, msg_time
        mov ah, 09h
        int 21h

        xor bh, bh                  ; page number
        mov bl, 0Fh                 ; white
        mov cx, 1                   ; one whole row
        mov al, 219                 ; blank character

        mov dl, 30                  ; x-coord
        mov dh, 0                   ; y-coord

        print_header_clear:
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
            jne print_header_clear
        ret
    print_header endp
    
    print_goal proc
        xor ah, ah
        mov al, stage_goal
        lea bx, str_goal
        mov cx, 3
        call itos

        mov al, '$'
        mov [str_time+4], al 

        xor bh, bh                  ; page number
        mov bl, 0Fh                 ; white
        mov cx, 10                  ; one whole row
        mov al, ' '                 ; blank character

        mov dl, 18                  ; x-coord
        mov dh, 14                  ; y-coord
        mov ah, 02h
        int 10h

        mov ah, 09h                 ; Make font color at current row to white
        int 10h

        lea dx, str_goal
        mov ah, 09h
        int 21h

        ret
    print_goal endp
    
    print_level proc
        xor ah, ah
        mov al, stage_level
        lea bx, str_level
        mov cx, 2
        call itos

        mov al, '$'
        mov [str_time+3], al 

        xor bh, bh                  ; page number
        mov bl, 0Fh                 ; white
        mov cx, 10                  ; one whole row
        mov al, ' '                 ; blank character

        mov dl, 18                  ; x-coord
        mov dh, 11                  ; y-coord
        mov ah, 02h
        int 10h

        mov ah, 09h                 ; Make font color at current row to white
        int 10h

        lea dx, str_level
        mov ah, 09h
        int 21h

        ret
    print_level endp
    
    print_clock proc
        xor ah, ah
        mov al, stage_time
        mov cl, 60
        div cl
        mov [str_time+3], ah

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

        xor bh, bh                  ; page number
        mov bl, 0Fh                 ; white
        mov cx, 10                  ; one whole row
        mov al, ' '                 ; blank character

        mov dl, 18                  ; x-coord
        mov dh, 17                  ; y-coord
        mov ah, 02h
        int 10h

        mov ah, 09h                 ; Make font color at current row to white
        int 10h

        lea dx, str_time
        mov ah, 09h
        int 21h

        ret
    print_clock endp

    check_stage proc
        cmp stage_time, 0
        jne check_if_goal_reached
        mov flag, 5
        ret

        check_if_goal_reached:
            cmp stage_goal, 0
            je proceed_to_next_stage
            ret

        proceed_to_next_stage:
            inc stage_level
            dec stage_speed
            mov stage_time, 150
            cmp stage_level, 20
            jl calculate_next_goal

            mov ax, 100             ; beyond stage 20, goal is constant 100
            jmp set_next_goal

        calculate_next_goal:
            mov cl, stage_level
            mov ax, 5
            mul cl

        set_next_goal:
            mov stage_goal, al
            mov flag, 6

        ret
    check_stage endp
    
    print_options proc
        xor bh, bh                  ; page number
        mov bl, 0Fh                 ; white
        mov cx, 20                  ; one whole row
        mov al, ' '                 ; blank character

        mov dl, 31                  ; x-coord
        mov dh, 9                   ; y-coord

        print_options_clear:
            mov ah, 02h
            int 10h

            mov ah, 09h
            int 10h

            inc dh
            cmp dh, 16
            jne print_options_clear

        mov bl, 0Eh

        mov dl, 31                  ; x-coord
        mov dh, 9                   ; y-coord
        mov ah, 02h
        int 10h
        mov ah, 09h
        int 10h
        lea dx, msg_main1
        mov ah, 09h
        int 21h

        mov dl, 31                  ; x-coord
        mov dh, 11                  ; y-coord
        mov ah, 02h
        int 10h
        lea dx, msg_main2
        mov ah, 09h
        int 21h

        mov dl, 31                  ; x-coord
        mov dh, 12                  ; y-coord
        mov ah, 02h
        int 10h
        lea dx, msg_main3
        mov ah, 09h
        int 21h

        mov dl, 31                   ; x-coord
        mov dh, 13                  ; y-coord
        mov ah, 02h
        int 10h
        lea dx, msg_main4
        mov ah, 09h
        int 21h

        mov dl, 31                  ; x-coord
        mov dh, 14                  ; y-coord
        mov ah, 02h
        int 10h
        lea dx, msg_main5
        mov ah, 09h
        int 21h

        mov dl, 31                  ; x-coord
        mov dh, 15                  ; y-coord
        mov ah, 02h
        int 10h
        lea dx, msg_main6
        mov ah, 09h
        int 21h

        ret
    print_options endp

    select_options proc
        highlight_selected_option:
            mov dl, 33              ; x-coord
            mov dh, 11              ; y-coord
            add dh, user_choice
            mov ah, 02h
            int 10h

            mov bx, 000Eh
            mov cx, 1
            mov al, '>'
            mov ah, 09h
            int 10h

        mov ah, 00h
        int 16h

        mov cx, ax

        mov dl, 33                  ; x-coord
        mov dh, 11                  ; y-coord
        add dh, user_choice

        mov ah, 02h
        int 10h

        mov dl, ' '
        mov ah, 02h
        int 21h

        mov ax, cx

        cmp ah, 72                  ; up arrow key
        je try_select_prev_option
        cmp ah, 80                  ; down arrow key
        je try_select_next_option
        cmp al, 13                  ; enter key
        jne highlight_selected_option

        ret

        try_select_prev_option:
            cmp user_choice, 0
            jne select_prev_option
            mov user_choice, 5

        select_prev_option:
            dec user_choice
            jmp highlight_selected_option

        try_select_next_option:
            cmp user_choice, 4
            jne select_next_option
            mov user_choice, 255

        select_next_option:
            inc user_choice
            jmp highlight_selected_option
    select_options endp

    init_tetris proc
        mov x, 41                   ; Set initial coordinates of new tetrimino
        mov y, 0

        call random_tetrimino
        call get_tetrimino
        call random_tetrimino

        mov flag, 6
        mov hold_flag, 0
        mov clock, 0
        mov stage_level, 1          ; current stage
        mov stage_goal, 5           ; lines left at current stage
        mov stage_time, 180         ; current clock at current stage
        mov stage_speed, 18         ; current speed at current stage

        xor si, si
        xor cl, cl
        clear_tetris_grid:
            mov [grid+si], cl
            inc si

            cmp si, 250
            jne clear_tetris_grid
        ret
    init_tetris endp

    init_scores proc
        xor al, al                  ; Try to open high score file
        lea dx, high_path
        mov ah, 3Dh
        int 21h

        mov high_handle, ax
        jnc open_records_file

        lea dx, high_path           ; Create high score file
        xor cx, cx
        mov ah, 3Ch
        int 21h

        mov high_handle, ax
        ret

        open_records_file:
            mov bx, high_handle     ; Get contents of high score file
            mov cx, 40
            lea dx, high_buffer
            mov ah, 3Fh
            int 21h

            mov bx, high_handle     ; Close high score file
            mov ah, 3Eh
            int 21h
            ret
    init_scores endp
 
    init_record proc
        xor di, di

        init_record_name:
            mov cl, [high_buffer+si]
            mov [str_name+di], cl

            inc si
            inc di

            cmp di, 3
            jne init_record_name

            mov cl, '$'
            mov [str_name+di], cl
            xor di, di

        init_record_level:
            mov cl, [high_buffer+si]
            mov [str_level+di], cl

            inc si
            inc di

            cmp di, 2
            jne init_record_level

            mov cl, '$'
            mov [str_level+di], cl
            xor di, di

        init_record_goal:
            mov cl, [high_buffer+si]
            mov [str_goal+di], cl
            
            inc si
            inc di
            
            cmp di, 3
            jne init_record_goal
            
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

        xor si, si
        print_scores_loop:
            xor cl, cl
            cmp [high_buffer+si], cl
            jne print_curr_record

            ret

        print_curr_record:
            call init_record

            mov ah, 02h
            int 10h

            cmp dh, 12
            je set_color_gold
            cmp dh, 13
            je set_color_silver
            mov bl, 0Fh
            jmp print_curr_record_details

        set_color_gold:
            mov bl, 0Eh
            jmp print_curr_record_details

        set_color_silver:
            mov bl, 07h
            jmp print_curr_record_details

        print_curr_record_details:
            mov cx, 20
            mov ah, 09h
            int 10h

            lea dx, str_name
            mov ah, 09h
            int 21h

            mov ah, 03h
            int 10h

            mov dl, 38
            mov ah, 02h
            int 10h

            lea dx, str_level
            mov ah, 09h
            int 21h

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

            jmp print_scores_loop
    print_scores endp
    
    print_new_score proc
        xor bh, bh                  ; page number
        mov bl, 0Fh                 ; white
        mov cx, 20                  ; one whole row
        mov al, ' '                 ; blank character

        mov dl, 31                  ; x-coord
        mov dh, 13                  ; y-coord
        mov ah, 02h
        int 10h

        mov ah, 09h
        int 10h

        lea dx, msg_highscore1
        mov ah, 09h
        int 21h

        mov dl, 31                  ; x-coord
        mov dh, 14                  ; y-coord
        mov ah, 02h
        int 10h

        mov ah, 09h
        int 10h

        lea dx, msg_highscore2
        mov ah, 09h
        int 21h

        mov dl, 31                  ; x-coord
        mov dh, 16                  ; y-coord
        mov ah, 02h
        int 10h

        mov ah, 09h
        int 10h

        lea dx, msg_highscore3
        mov ah, 09h
        int 21h

        mov dl, 31                  ; x-coord
        mov dh, 17                  ; y-coord
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
        mov cx, 0607h               ; Show cursor
        mov ah, 01h
        int 10h

        xor bh, bh
        mov bl, 0Fh
        mov cx, 1

        mov dl, 42
        mov dh, 17

        xor si, si
        print_default_name:
            mov ah, 02h
            int 10h

            mov al, 'A'
            mov [str_name+si], al

            mov ah, 09h
            int 10h

            sub dl, 2
            inc si

            cmp si, 3
            jne print_default_name

        xor bh, bh                  ; Highlight first character in name
        mov dl, 38
        mov dh, 17

        mov ah, 02h
        int 10h

        xor si, si
        get_user_input: ;p1
            mov ah, 00h
            int 16h

            cmp ah, 75              ; Check if left arrow key
            je try_go_prev_index

            cmp ah, 77              ; Check if right arrow key
            je try_go_next_index

            cmp ah, 80              ; Check if down arrow key
            je try_get_next_letter

            cmp ah, 72              ; Check if up arrow key
            je try_get_prev_letter

            cmp al, 13
            je confirm_name
            jmp get_user_input

        write_in_curr_index: ;p6
            mov [str_name+si], al
            mov ah, 09h
            int 10h

            jmp get_user_input

        highlight_curr_index: ;p7
            mov ah, 02h
            int 10h
            jmp get_user_input

        try_go_prev_index:
            cmp dl, 38
            jne go_prev_index
            mov dl, 44
            mov si, 3

        go_prev_index:
            sub dl, 2
            dec si
            jmp highlight_curr_index

        try_go_next_index: ;p3
            cmp dl, 42
            jne go_next_index
            mov dl, 36
            mov si, 255

        go_next_index:
            add dl, 2
            inc si
            jmp highlight_curr_index

        try_get_next_letter: ;p4
            mov al, [str_name+si]
            cmp al, 'Z'
            jne get_next_letter
            mov al, '@'

        get_next_letter:
            inc al
            jmp write_in_curr_index

        try_get_prev_letter: ;p5
            mov al, [str_name+si]
            cmp al, 'A'
            jne get_prev_letter
            mov al, '['

        get_prev_letter:
            dec al
            jmp write_in_curr_index

        confirm_name:
            ret
    get_name endp

    check_scores proc
        mov high_rank, 5            ; current rank (5 is unranked)
        mov dx, 32                  ; counter

        compare_scores:
            mov si, dx

            call init_record
            cmp str_name, 0         ; if uninitialized, check next record
            je go_next_rank

            lea bx, str_level       ; convert level to int
            call stoi

            cmp stage_level, al 
            jg go_next_rank
            cmp stage_level, al
            jl check_new_highscore

            lea bx, str_goal        ; if levels are equal, convert goal to int
            call stoi

            cmp stage_goal, al
            jle go_next_rank
            jg check_new_highscore

        go_next_rank:
            dec high_rank
            cmp dx, 0
            je check_new_highscore

            sub dx, 8
            jmp compare_scores

        check_new_highscore:
            cmp high_rank, 5
            jl record_new_highscore
            ret

        record_new_highscore:
            call print_new_score
            call get_name

            xor ah, ah
            mov al, 8
            mov cl, high_rank
            mul cl                  ; ax contains index of new entry

            mov si, 31

        find_buffer_coords:
            cmp ax, si
            jg write_to_buffer

            mov cl, [high_buffer+si]
            mov [high_buffer+si+8], cl

            cmp si, 0
            je write_to_buffer

            dec si
            jmp find_buffer_coords

        write_to_buffer:
            xor ah, ah
            mov al, stage_level     ; Convert level reached to string
            lea bx, str_level
            mov cx, 2
            call itos

            xor ah, ah
            mov al, stage_goal      ; Convert goal lines remaining to string
            lea bx, str_goal
            mov cx, 3
            call itos

            xor ah, ah
            mov al, 8
            mov cl, high_rank
            mul cl                  ; ax contains index of new entry

            mov si, ax              ; index of current entry
            xor di, di

        write_name_to_buffer:
            mov cl, [str_name+di]
            mov [high_buffer+si], cl

            inc si
            inc di

            cmp di, 3
            jne write_name_to_buffer

            xor di, di

        write_level_to_buffer:
            mov cl, [str_level+di]
            mov [high_buffer+si], cl

            inc si
            inc di

            cmp di, 2
            jne write_level_to_buffer

            xor di, di

        write_goal_to_buffer:
            mov cl, [str_goal+di]
            mov [high_buffer+si], cl
 
            inc si
            inc di

            cmp di, 3
            jne write_goal_to_buffer

            lea dx, high_path        ; Write updated highscores to file
            mov al, 1
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
        xor bh, bh                  ; page number
        mov bl, 0Eh                 ; white
        mov cx, 11                  ; one whole row
        mov al, ' '                 ; blank character

        mov dl, 25                  ; x-coord
        mov dh, 11                  ; y-coord

        print_controls_clear1:
            mov ah, 02h
            int 10h

            mov ah, 09h
            int 10h

            inc dh
            cmp dh, 18
            jne print_controls_clear1

        mov bl, 0Fh                 ; white
        mov cx, 25                  ; one whole row

        mov dl, 40                  ; x-coord
        mov dh, 11                  ; y-coord

        print_controls_clear2:
            mov ah, 02h
            int 10h

            mov ah, 09h
            int 10h

            inc dh
            cmp dh, 18
            jne print_controls_clear2

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

        mov dl, 25                  ; x-coord
        mov dh, 11                  ; y-coord
        mov ah, 02h
        int 10h
        lea dx, msg_control_key1
        mov ah, 09h
        int 21h

        mov dl, 25                  ; x-coord
        mov dh, 12                  ; y-coord
        mov ah, 02h
        int 10h
        lea dx, msg_control_key2
        mov ah, 09h
        int 21h

        mov dl, 25                  ; x-coord
        mov dh, 13                  ; y-coord
        mov ah, 02h
        int 10h
        lea dx, msg_control_key3
        mov ah, 09h
        int 21h

        mov dl, 25                  ; x-coord
        mov dh, 14                  ; y-coord
        mov ah, 02h
        int 10h
        lea dx, msg_control_key4
        mov ah, 09h
        int 21h

        mov dl, 25                  ; x-coord
        mov dh, 15                  ; y-coord
        mov ah, 02h
        int 10h
        lea dx, msg_control_key5
        mov ah, 09h
        int 21h

        mov dl, 25                  ; x-coord
        mov dh, 16                  ; y-coord
        mov ah, 02h
        int 10h
        lea dx, msg_control_key6
        mov ah, 09h
        int 21h

        mov dl, 25                  ; x-coord
        mov dh, 17                  ; y-coord
        mov ah, 02h
        int 10h
        lea dx, msg_control_key7
        mov ah, 09h
        int 21h

        mov dl, 40                  ; x-coord
        mov dh, 11                  ; y-coord
        mov ah, 02h
        int 10h
        lea dx, msg_control_def1
        mov ah, 09h
        int 21h

        mov dl, 40                  ; x-coord
        mov dh, 12                  ; y-coord
        mov ah, 02h
        int 10h
        lea dx, msg_control_def2
        mov ah, 09h
        int 21h

        mov dl, 40                  ; x-coord
        mov dh, 13                  ; y-coord
        mov ah, 02h
        int 10h
        lea dx, msg_control_def3
        mov ah, 09h
        int 21h

        mov dl, 40                  ; x-coord
        mov dh, 14                  ; y-coord
        mov ah, 02h
        int 10h
        lea dx, msg_control_def4
        mov ah, 09h
        int 21h

        mov dl, 40                  ; x-coord
        mov dh, 15                  ; y-coord
        mov ah, 02h
        int 10h
        lea dx, msg_control_def5
        mov ah, 09h
        int 21h

        mov dl, 40                  ; x-coord
        mov dh, 16                  ; y-coord
        mov ah, 02h
        int 10h
        lea dx, msg_control_def6
        mov ah, 09h
        int 21h

        mov dl, 40                  ; x-coord
        mov dh, 17                  ; y-coord
        mov ah, 02h
        int 10h
        lea dx, msg_control_def7
        mov ah, 09h
        int 21h

        ret
    print_controls endp
    
    print_about proc
        xor bh, bh                  ; page number
        mov bl, 0Fh                 ; white
        mov cx, 22                  ; one whole row
        mov al, ' '                 ; blank character
        
        mov dl, 30                  ; x-coord
        mov dh, 9                   ; y-coord
        
        print_about_clear:
            mov ah, 02h
            int 10h

            mov ah, 09h
            int 10h

            inc dh
            cmp dh, 22
            jne print_about_clear

        mov bl, 0Eh

        mov dl, 31                  ; x-coord
        mov dh, 9                   ; y-coord
        mov ah, 02h
        int 10h
        mov ah, 09h
        int 10h
        lea dx, msg_main1
        mov ah, 09h
        int 21h

        mov dl, 30                  ; x-coord
        mov dh, 11                  ; y-coord
        mov ah, 02h
        int 10h
        lea dx, msg_about1
        mov ah, 09h
        int 21h

        mov dl, 30                  ; x-coord
        mov dh, 12                  ; y-coord
        mov ah, 02h
        int 10h
        lea dx, msg_about2
        mov ah, 09h
        int 21h

        mov dl, 30                  ; x-coord
        mov dh, 13                  ; y-coord
        mov ah, 02h
        int 10h
        lea dx, msg_about3
        mov ah, 09h
        int 21h

        mov dl, 30                  ; x-coord
        mov dh, 14                  ; y-coord
        mov ah, 02h
        int 10h
        mov ah, 09h
        int 10h
        lea dx, msg_about4
        mov ah, 09h
        int 21h

        mov dl, 30                  ; x-coord
        mov dh, 15                  ; y-coord
        mov ah, 02h
        int 10h
        lea dx, msg_about5
        mov ah, 09h
        int 21h

        mov dl, 30                  ; x-coord
        mov dh, 16                  ; y-coord
        mov ah, 02h
        int 10h
        lea dx, msg_about6
        mov ah, 09h
        int 21h

        mov dl, 30                  ; x-coord
        mov dh, 18                  ; y-coord
        mov ah, 02h
        int 10h
        mov ah, 09h
        int 10h
        lea dx, msg_about7
        mov ah, 09h
        int 21h

        mov dl, 30                  ; x-coord
        mov dh, 19                  ; y-coord
        mov ah, 02h
        int 10h
        lea dx, msg_about8
        mov ah, 09h
        int 21h    

        ret
    print_about endp
    
    ; Converts an integer loaded in ax into a string loaded in bx
    ; and the number of characters on cx
    itos proc
        mov si, bx
        mov dl, 10

        itos_loop:                  ; convert number to ascii
            div dl

            add ah, '0'
            mov [bx], ah

            xor ah, ah
            inc bx
            dec cx

            cmp cx, 0
            jne itos_loop

            mov di, bx              ; string length
            dec di

            mov dl, '$'
            mov [bx], dl

        str_reverse_loop:           ; reverse string
            mov dl, [si]
            mov dh, [di]
            mov [si], dh
            mov [di], dl

            inc si
            dec di

            cmp si, di
            jl str_reverse_loop

            xor bx, bx
        ret
    itos endp

    ; Converts a string loaded on bx into an integer loaded in ax
    stoi proc
        xor ax, ax

        stoi_loop:
            mov cl, 10
            mul cl                  ; multiply current sum by 10

            xor ch, ch
            mov cl, [bx]
            sub cl, '0'             ; convert to integer

            add ax, cx              ; add current integer
            inc bx

            mov cl, '$'
            cmp [bx], cl
            jne stoi_loop
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

        fin:
            call clear_screen
            mov ah, 4ch
            int 21h
            ret

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
            call print_flag

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
            call random_tetrimino
            mov hold_flag, 0

            jmp tetris

        mov ax, 4c00h
        int 21h
    main endp
end main
