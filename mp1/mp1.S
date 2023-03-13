# mp1.S - missile-command version
# Good luck, and have fun!

.data
    
    # Constants for accessing the fields of a struct missile, 
    # struct missile is defined in rtc.h and mp1.h

    NEXT        = 0
    X     = 4
    Y     = 8
    VX    = 12
    VY    = 16
    DEST_X    = 20
    DEST_Y    = 24
    EXPLODED  = 28
    C     = 32

    # Character to draw for an explosion - '@'
    # Place to set the constant number
    X_UPPER = 80                        # X_UPPER - x <= 0, then not off screen
    X_LOWER = 0x0                       # x - 0 < 0 then off screen
    Y_UPPER = 25                        # Y_UPPER - y <= 0, then not off screen
    Y_LOWER = 0x0                       # y - 0 < 0 then off screen
    NULLPTR = 0x0                       # nullptr
    ROW_OffSET = 24         		    # use for redraw cities; upper 16 bits represents the y offset
    FIRST_CITY_START    = 18            # use for redraw first city
    SECOND_CITY_START = 38              # use for redraw second city
    THIRD_CITY_START = 58               # use for redraw third city
    MISSILE_SIZE    = 36                # size of missile struct = 33 bytes
    SHIFT = 16                          # shifting for upper_16/lower_16
    SPACE = 32                          # " "
    CORSSHAIRS = 43                     # + 
    EXPLOSION = 64                      # @
    LOWER_MASK = 0x0000FFFF
    UPPER_MASK = 0xFFFF0000

# Data shared between this file and rtc.c helper functions

# This '.globl' directive makes these symbols visible externally
.globl mp1_missile_list, base_alive, mp1_score

mp1_missile_list:   .long 0x0   # Head of list pointer
base_alive:         .long 0x0   # Array of 3 bytes, plus a padding byte
mp1_score:          .long 0x0   # Player's current score
city_status_score:  .long 0x0

# Data private to this  file

base_pic:           .string "/^^^\\"    # Picture of a live base
dead_base_pic:      .string "xxxxx" # Picture of a dead base
crosshairs_x:       .long 0x0   # X-position of the crosshairs
crosshairs_y:       .long 0x0   # Y-position of the crosshairs

.text

# void mp1_poke(void);
# You can use this function to write to video memory.
#
# Interface: Register-based arguments (not C-style)
#    Inputs: %cl  - The byte you wish to write
#            %eax - Offset from the start of video memory that you wish
#                   to write to
#   Outputs: Text-mode video screen is written to at location %eax with
#            the byte in %cl
# Registers: Clobbers EDX

mp1_poke:
        movl    vmem_base_addr(,1),%edx
        movb    %cl,(%edx,%eax,1)
        ret

#   ----------------- Exported functions ---------------------

# void mp1_rtc_tasklet(unsigned long garbage);
# Performs three tasks:
#   (1) updates the list of missiles (implement this in update_missiles,
#           below, and call it from here).
#   (2) Redraw the bases - they may have been overwritten with missiles
#   (3) Redraw the crosshairs - it may have been overwritten with missiles
# Inputs   : none
# Outputs  : none
# Registers: Standard C calling convention

.globl mp1_rtc_tasklet
mp1_rtc_tasklet:
        pushl   %ebp
        movl    %esp, %ebp
        pushl   %ebx
        pushl   %esi 
        pushl   %edi 

        call    update_missiles
        call    redraw_city
        call    redraw_crosshairs

        popl    %edi
        popl    %esi
        popl    %ebx
        leave
        ret

# int mp1_ioctl(unsigned long arg, unsigned int cmd)
# The dispatch function for the MP1 ioctls - should use the cmd argument
# and a jumptable to execute one of the specific ioctls implemented below.
# Inputs   : unsigned long arg - parameter to the mp1_ioctl_....
#          : unsigned int cmd  - specifies which mp1_ioctl_... function 
#          :                     to execute
# Outputs  : Returns an integer - depends on which ioctl() function is called
# Registers: Standard C calling convention

# Input     : unsigned long arg - use to pass to other function
#           : unsigned long cmd - {0, 1, 2, 3, 4}
# Outputs   : unsigned long -1 if it is failed; 
#           : Jump to other functions if it succeeds
.globl mp1_ioctl
mp1_ioctl:
        movl    8(%esp), %edi                      # edi = cmd
        cmpl    $5, %edi                            # edi - 5 = cmd - 5
        jge     mp1_ioctl_end_with_error            # 0 <= edi - 5, then return -1
        cmpl    $0, %edi                            # edi - 0 = cmd - 0
        jl      mp1_ioctl_end_with_error            # edi - 0 < 0, then return -1

    mp1_ioctl_end_without_error:
        imull   $4, %edi, %ebx                      # ebx = 4 * edi = 4 * cmd
        addl    $jump_table_ioctl, %ebx             # ebx = jump_table_ioctl + ebx
        jmp     *(%ebx)                             # use jump_table_ioctl to call function

        jmp     mp1_ioctl_end

    mp1_ioctl_end_with_error:
        movl    $-1, %eax
    mp1_ioctl_end:



# ----------------- Functions private to this file -------------------

# Input     : NOTHING
# Outputs   : NOTHING
# Function  : Call update_missiles_each_iter as each iteration, and update the Missile_List
update_missiles:
        pushl   %ebp
        movl    %esp, %ebp
        pushl   %ebx
        pushl   %esi 
        pushl   %edi

        movl    $NULLPTR, %esi                          # esi = parent_pointer
        movl    mp1_missile_list, %ebx                  # ebx = curr_pointer
    
    update_missiles_traverse_loop:
        cmpl    $NULLPTR, %ebx                          # curr_pointer - nullptr
        je      update_missiles_traverse_done           # if curr_pointer == nullptr, then done
        movl    NEXT(%ebx), %edi                        # edi = next_pointer

        pushl   %ebx                                    # ebx = curr_pointer
        pushl   %esi                                    # esi = parent_pointer
        call    update_missiles_each_iter               # {parent_pointer, curr_pointer}
        addl $8, %esp                                   # use previous version to specify it is now old_pointer
        # popl  %esi                                    # esi = old_parent_pointer
        # popl  %ebx                                    # ebx = old_curr_pointer

        cmpl    $1, %eax                                # 1 - eax
        je      update_missiles_remove_old_curr_ptr         # eax = 1, indicates old_curr_pointer has been removed
        # cmpl  $NULLPTR, %ebx                          # ebx - nullptr
        # je        update_missiles_remove_old_curr_ptr     # old_curr_pointer has been removed

    update_missiles_not_remove_old_curr_ptr:
        movl    %ebx, %esi                              # old_curr_pointer not removed, update parent; esi(parent) = old_curr_pointer
    update_missiles_remove_old_curr_ptr:                
                                                        # old_curr_pointer removed, parent not need to be updated, esi(parent) = old_parent_pointer
        movl    %edi, %ebx                              # not matter what situation, ebx(curr) = next_pointer = edi

        jmp     update_missiles_traverse_loop

    update_missiles_traverse_done:
    
        popl    %edi
        popl    %esi
        popl    %ebx
        leave
        ret

# Input     : parent_pointer
#           : current_pointer; Ensure that each current_pointer is not nullptr
# Outputs   : 0 indicates curr_pointer is not removed
#           : 1 indicates curr_pointer is removed
# Function  : Erase Curr_X, Curr_Y char, update Curr_X to New_x, Curr_Y to New_Y
update_missiles_each_iter:
        pushl   %ebp
        movl    %esp, %ebp
        pushl   %ebx
        pushl   %ecx
        pushl   %edx 
        pushl   %esi 
        pushl   %edi 

        # Get the curr_pointer
        movl    12(%ebp), %ebx                              # ebx = current pointer
    
        # Erase the previous one
        movl    X(%ebx), %ecx                               # ecx = curr_X
        movl    Y(%ebx), %edx                               # edx = curr_Y
        sarl    $SHIFT, %ecx                                # ecx = curr_X with lower 16 bits
        sarl    $SHIFT, %edx                                # edx = curr_Y with lower 16 bits
        pushl   $SPACE
        pushl   %edx
        pushl   %ecx
        call    draw_char_in_text_mode_video                # {x, y, char}; All in lower 16 bits; only in screen, then draw
        addl    $12, %esp                   

        # Get whether it is exploded
        movl    EXPLODED(%ebx), %esi                        # esi = exploded
        cmpl    $0, %esi                                    # esi - 0
        jg      update_missiles_each_iter_EXPLODING         # esi > 0, then exploding

        # Update the new position to the missile
        movl    X(%ebx), %ecx                               # ecx = curr_X
        movl    Y(%ebx), %edx                               # edx = curr_Y
        movl    VX(%ebx), %esi                              # esi = VX
        movl    VY(%ebx), %edi                              # edi = VY
        addl    %esi, %ecx                                  # ecx = ecx + esi = curr_X + VX = new_X
        addl    %edi, %edx                                  # edx = edx + edi = curr_Y + VY = new_Y
        movl    %ecx, X(%ebx)                               # X = ecx = new_X
        movl    %edx, Y(%ebx)                               # Y = edx = new_Y

    update_missiles_each_iter_NOT_EXPLODING:
        # Get the curr_pointer
        movl    12(%ebp), %ebx                              # ebx = current pointer

        movl    X(%ebx), %esi                               # esi = new_X
        movl    Y(%ebx), %edi                               # edi = new_Y
        sarl    $SHIFT, %esi                                # esi = new_X_put_in_lower_16
        sarl    $SHIFT, %edi                                # edi = new_Y_put_in_lower_16
        pushl   %edi
        pushl   %esi
        call    whether_in_screen                           # {x, y}, X_put_in_lower_16, Y_put_in_lower_16
        addl    $8, %esp                

        cmpl    $1, %eax                                    # eax - 1
        je      update_missiles_each_iter_OFF_SCREEN        # eax = 1, then off screen
    update_missiles_each_iter_NOT_OFF_SCREEN:
        # Get the curr_pointer
        movl    12(%ebp), %ebx                              # ebx = current pointer

        movl    X(%ebx), %esi                               # esi = X
        movl    DEST_X(%ebx), %edi                          # edi = Dest_x
        movl    Y(%ebx), %ecx                               # ecx = Y
        movl    DEST_Y(%ebx), %edx                          # edx = Dest_Y
        sarl    $SHIFT, %esi
        sarl    $SHIFT, %ecx


        pushl   %edx
        pushl   %edi
        pushl   %ecx
        pushl   %esi
        call    whether_reach_destination                   # {curr_x, curr_y, dest_x, dest_y}
        addl    $16, %esp           

        cmpl    $0, %eax                                    # eax - 0; 0 reach, 1 not reach
        je      update_missiles_each_iter_Reach_Destination
    update_missiles_each_iter_NOT_Reach_Destination:
        # Get the curr_pointer
        movl    12(%ebp), %ebx                              # ebx = current pointer

        # add next one into the screen
        movl    X(%ebx), %esi                               # esi = X   
        movl    Y(%ebx), %edi                               # edi = Y
        movl    C(%ebx), %ecx                               # ecx = char
        sarl    $SHIFT, %esi
        sarl    $SHIFT, %edi
        pushl   %ecx
        pushl   %edi
        pushl   %esi
        call    draw_char_in_text_mode_video                # {x, y, char}; All in lower 16 bits; only in screen, then draw
        addl    $12, %esp                   

        # nothing to remove, eax = 0
        movl    $0, %eax                                    # eax = 0; nothing removed
        jmp     update_missiles_each_iter_Done

    update_missiles_each_iter_OFF_SCREEN:
    
        # remove from the list
        movl    8(%ebp), %esi                               # esi = parent_pointer
        movl    12(%ebp), %ebx                              # ebx = current pointer
        movl    NEXT(%ebx), %edi                            # edi = next_pointer

        pushl   %edi
        pushl   %ebx
        pushl   %esi
        call    remove_from_list                            # (parent_Pointer, curr_pointer, next_pointer); guarantee curr_pointer is not null
        addl    $12, %esp

        # something is removed, eax = 1
        movl    $1, %eax                                    # eax = 1; something removed
        jmp     update_missiles_each_iter_Done
        
    update_missiles_each_iter_EXPLODING:
    update_missiles_each_iter_Reach_Destination:

        movl    12(%ebp), %ebx                              # ebx = current pointer
        pushl   %ebx
        call    missile_explode                             # {missile_pointer}; ebx
        addl    $4, %esp 
        cmpl    $0, %eax                                    # eax - 0
        je     update_missiles_each_iter_Not_Cause_Others   # eax = 0 

    update_missiles_each_iter_Cause_Others:

        call    mp1_notify_user                             # when esi != 0, notidy users since the bumb causes 

    update_missiles_each_iter_Not_Cause_Others:             
        movl    8(%ebp), %edi                               # edi = parent_pointer
        pushl   %ebx
        pushl   %edi        
        call    exploding_bumb                              # {parent_pointer, curr_pointer}
        addl    $8, %esp                                

    update_missiles_each_iter_Done:

        popl    %edi
        popl    %esi
        popl    %edx
        popl    %ecx
        popl    %ebx
        leave
        ret

# Input     : parent_pointer
#           : current_pointer; Ensure that each current_pointer is not nullptr
#           : next_pointer
# Outputs   : NOTHING
# Function  : remove curr_pointer from the list, and memory using mp1_free
remove_from_list:
        pushl   %ebp
        movl    %esp, %ebp
        pushl   %ebx
        pushl   %ecx                        # protect the ecx from using mp1_free
        pushl   %edx                        # protect the edx from using mp1_free
        pushl   %esi 
        pushl   %edi 

        movl    8(%ebp), %ebx               # ebx = parent_pointer
        movl    12(%ebp), %edx              # edx = curr_pointer
        movl    16(%ebp), %esi              # esi = next_pointer

        cmpl    $NULLPTR, %ebx              # ebx - nullptr
        je      remove_from_list_parent_null

    remove_from_list_parent_not_null:
        movl    %esi, NEXT(%ebx)            # ebx -> next = parent_pointer -> next = next _pointer
        jmp     remove_from_list_free_pointer
    remove_from_list_parent_null:           
                                            # esi = next_pointer
        movl    %esi, mp1_missile_list      # parent_pointer == nullptr; remove current_pointer; then head_pointer = next_pointer

    remove_from_list_free_pointer:
        pushl   %edx                        # free curr_pointer
        call    mp1_free                    # free curr_pointer
        addl    $4, %esp                    # free curr_pointer

    remove_from_list_done:

        # movl  $1, %eax                    # indicates the curr pointer is removed
        popl    %edi
        popl    %esi
        popl    %edx                        # protect the edx from using mp1_free
        popl    %ecx                        # protect the ecx from using mp1_free
        popl    %ebx
        leave
        ret

# Input     : X, already put it in lower 16 Bits
#           : Y, already put it in lower 16 Bits
# Outputs   : Offest of X, Y, 160Y + 2X
# Function  : calculate the offest based on X, Y
calc_coordinate:
        pushl   %ebp
        movl    %esp, %ebp
        pushl   %edi
        pushl   %esi

        movl    8(%ebp), %edi               # edi = x coordinate
        movl    12(%ebp), %esi              # esi = y coordinate
        imull   $2, %edi, %edi              # edi = 2x
        imull   $160, %esi, %esi            # esi = 160y
        movl    %esi, %eax                  # eax = esi = 160y
        addl    %edi, %eax                  # eax = eax + edi = 160y + 2x

        popl    %esi
        popl    %edi
        leave
        ret 

# Input     : curr_x, already put it in lower 16 Bits
#           : curr_y, already put it in lower 16 Bits
#           : dest_x, already put it in lower 16 Bits
#           : dest_y, already put it in lower 16 Bits
# Outputs   : 0 means reach the destination
#           : 1 means not reach the deastination
# Function  : Check whether reach destination
whether_reach_destination:
        pushl   %ebp
        movl    %esp, %ebp
        pushl   %ebx                        
        pushl   %esi 
        pushl   %edi 


        movl    8(%ebp), %ebx                           # ebx = curr_x
        movl    16(%ebp), %esi                          # esi = dest_x
        cmpl    %ebx, %esi                              # esi - ebx = dest_x - curr_x
        jne     whether_reach_destination_not_reach

        movl    12(%ebp), %ebx                          # ebx = curr_y
        movl    20(%ebp), %esi                          # esi = dest_y
        cmpl    %ebx, %esi                              # esi - ebx = dest_y - curr_y
        jne     whether_reach_destination_not_reach

    whether_reach_destination_reach:
        movl    $0, %eax    
        jmp     whether_reach_destination_done
    whether_reach_destination_not_reach:
        movl    $1, %eax 
    whether_reach_destination_done:

        popl   %edi 
        popl   %esi 
        popl   %ebx  
        leave                      
        ret


# Input     : x, already put it in lower 16 Bits
#           : y, already put it in lower 16 Bits
# Outputs   : 0 means is still in the screen
#           : 1 means is out of screen
# Function  : Check whether x, y is in screen
whether_in_screen:
        pushl   %ebp
        movl    %esp, %ebp
        pushl   %ebx

        movl    8(%ebp), %ebx                               # ebx =  x
        cmpl    $X_UPPER, %ebx                              # ebx - upper = x - X_UPPER
        jge     whether_in_screen_off_screen                # x - X_UPPER >=  0
        cmpl    $X_LOWER, %ebx                              # x - 0
        jl      whether_in_screen_off_screen                # ebx - 0 < 0

        movl    12(%ebp), %ebx                              # ebx =  y
        cmpl    $Y_UPPER, %ebx                              # ebx - Y_UPPER = y - Y_UPPER
        jge     whether_in_screen_off_screen                # 0 <= y - Y_UPPER 
        cmpl    $Y_LOWER, %ebx                              # y - 0
        jl      whether_in_screen_off_screen                # y - 0 < 0

    whether_in_screen_not_off_screen:
        movl    $0, %eax 
        jmp     whether_in_screen_done
    whether_in_screen_off_screen:
        movl    $1, %eax
    whether_in_screen_done:
		
        popl    %ebx
        leave
        ret

# Input     : x, already put it in lower 16 Bits
#           : y, already put it in lower 16 Bits
#           : char, used to draw on the screen
# Outputs   : NOTHING
# Function  : Draw char at (x, y). Use whether_in_screen to protect
draw_char_in_text_mode_video:
        pushl   %ebp
        movl    %esp, %ebp
        pushl   %ecx                        # protect the ecx from using mp1_poke
        pushl   %ebx
        pushl   %edi
        pushl   %edx                        # protect the edx from using mp1_poke
        pushl   %esi


        movl    8(%ebp), %ebx                       # ebx = x
        movl    12(%ebp), %edi                      # edi = y
        pushl   %edi
        pushl   %ebx
        call    whether_in_screen                   # {x, y}; 
        addl    $8, %esp
        cmpl    $1, %eax                            # eax - 1
        je      draw_char_in_text_mode_video_done   # eax = 1; then not draw

        pushl   %edi
        pushl   %ebx
        call    calc_coordinate             # {x, y}
        addl    $8, %esp    

        # eax = offset
        movb    16(%ebp), %cl               # cl = char
        call    mp1_poke

    draw_char_in_text_mode_video_done:

        popl    %esi
        popl    %edx                        # protect the edx from using mp1_poke
        popl    %edi
        popl    %ebx
        popl    %ecx                        # protect the ecx from using mp1_poke
        leave
        ret 


# Input     : parent_pointer
#           : curr_pointer, ensure that the curr_pointer is not nullptr
# Outputs   : 0 indicates curr_pointer is not removed
#           : 1 indicated curr_pointer is removed
# Function  : Deal with all missiles reach destination or exploding
exploding_bumb:
        pushl   %ebp
        movl    %esp, %ebp
        pushl   %ebx
        pushl   %ecx
        pushl   %edx
        pushl   %esi 
        pushl   %edi 

        # Update the exploded time
        movl    12(%ebp), %ebx                              # ebx = curr_pointer
        movl    EXPLODED(%ebx), %ecx                        # ecx = EXPLODED
        subl    $1, %ecx                                    # ecx = ecx - 1
        movl    %ecx, EXPLODED(%ebx)                        # EXPLODED = EXPLODED - 1

        # Judge whether the current is > 0
        movl    12(%ebp), %ebx                              # ebx = curr_pointer
        movl    EXPLODED(%ebx), %ecx                        # ecx = exploded
        cmpl    $0, %ecx                                    # ecx - 0
        jg      exploding_bumb_Exist                        # ecx > 0
    
    exploding_bumb_Not_Exist:
        movl    8(%ebp), %ecx                               # ecx = parent_pointer
        movl    12(%ebp), %ebx                              # ebx = curr_pointer
        movl    NEXT(%ebx), %edx                            # edx = next_pointer
        pushl   %edx 
        pushl   %ebx
        pushl   %ecx    
        call    remove_from_list                            # Remove the bumb from the list, free mem, {parent_pointer, curr_poiner, next_pointer}
        addl    $12, %esp 

        movl    $1, %eax                                    # eax = 1; something remove
        jmp     exploding_bumb_Done
    exploding_bumb_Exist:
        movl    12(%ebp), %ebx                              # ebx = curr_pointer
        movl    X(%ebx), %ecx                               # ecx = X
        movl    Y(%ebx), %edx                               # edx = Y
        sarl    $SHIFT, %ecx                                # ecx = Put X at lower 16 bits
        sarl    $SHIFT, %edx                                # edx = Put Y at lower 16 bits
        movl    $EXPLOSION, %esi                            # esi = "@", explosion
        pushl   %esi
        pushl   %edx
        pushl   %ecx  
        call    draw_char_in_text_mode_video                # Draw the bumb in the screen {X, Y, @}
        addl    $12, %esp

        movl    $0, %eax                                    # eax =  0; nothing remove
    exploding_bumb_Done:
        popl    %edi
        popl    %esi
        popl    %edx
        popl    %ecx
        popl    %ebx
        leave
        ret

# Input     : NOTHING
# Outputs   : NOTHING
# Function  : Draw three citys centered at (20), (40), (60)
redraw_city:
        pushl   %ebp
        movl    %esp, %ebp
        pushl   %ebx
        pushl   %esi 
        pushl   %edi 

    redraw_city_first:
        movzbl  base_alive + 0,  %ebx       # find whether the first city is live or not
        cmpl    $0, %ebx                    # ebx - 0
        je      redraw_city_first_dead      # first city is dead    
    redraw_city_first_alive:                # first city alive
        pushl   $FIRST_CITY_START       
        call    redraw_single_city_alive    # {start_x}
        addl    $4, %esp                    
        jmp     redraw_city_second
    redraw_city_first_dead:                 # first city dead
        pushl   $FIRST_CITY_START
        call    redraw_single_city_dead     # {start_x}
        addl    $4, %esp

    redraw_city_second:
        movzbl  base_alive + 1,  %ebx       # find whether the second city is live or not
        cmpl    $0, %ebx                    # ebx - 0
        je      redraw_city_second_dead     # second city is dead
    redraw_city_second_alive:               # second city alive
        pushl   $SECOND_CITY_START      
        call    redraw_single_city_alive    # {start_x}
        addl    $4, %esp                    
        jmp     redraw_city_third
    redraw_city_second_dead:                # second city dead
        pushl   $SECOND_CITY_START
        call    redraw_single_city_dead     # {start_x}
        addl    $4, %esp

    redraw_city_third:
        movzbl  base_alive + 2,  %ebx       # find whether the third city is live or not
        cmpl    $0, %ebx                    # ebx - 0
        je      redraw_city_third_dead      # third city is dead
    redraw_city_third_alive:                # third city alive
        pushl   $THIRD_CITY_START       
        call    redraw_single_city_alive    # {start_x}
        addl    $4, %esp                    
        jmp     redraw_city_done
    redraw_city_third_dead:                 # third city dead
        pushl   $THIRD_CITY_START
        call    redraw_single_city_dead     # {start_x}
        addl    $4, %esp

    redraw_city_done:
        popl    %edi
        popl    %esi
        popl    %ebx
        leave
        ret

# ROW_OFFSET is used as y coordinate := 24
# Input     : start_x_position_of_city, in lower 16 bits
# Outputs   : NOTHING
# Function  : Draw living city
redraw_single_city_alive:
        pushl   %ebp
        movl    %esp, %ebp
        pushl   %ebx
        pushl   %esi 
        pushl   %edi 
        pushl   %ecx
        pushl   %edx

        movl    8(%ebp), %esi                           # esi = start_x
        movl    $base_pic, %edi                         # edi = charr_array_pointer
        movl    $0, %ebx                                # ebx = 0; which is the iteration counter

    redraw_single_city_alive_loop:
        cmpl    $5, %ebx                                # ebx - 5
        je      redraw_single_city_alive_loop_done      # ebx - 5 = 0, ebx = 5, then the loop should end 

        movzbl  (%edi), %ecx                            # ecx = current char
        pushl   %ecx
        pushl   $ROW_OffSET                     
        pushl   %esi    
        call    draw_char_in_text_mode_video            # {x, y, char}
        addl    $12, %esp 

        addl    $1, %esi                                # esi = esi + 1; update the x value
        addl    $1, %edi                                # edi = edi + 1; find next element in the char array
        addl    $1, %ebx                                # ebx = ebx + 1; iteration counter ++

        jmp     redraw_single_city_alive_loop           # looping

    redraw_single_city_alive_loop_done:

        popl    %edx
        popl    %ecx
        popl    %edi
        popl    %esi
        popl    %ebx
        leave
        ret

# ROW_OFFSET is used as y coordinate := 24
# Input     : start_x_position_of_city, in lower 16 bits
# Outputs   : NOTHING
# Function  : Draw dead city
redraw_single_city_dead:
        pushl   %ebp
        movl    %esp, %ebp
        pushl   %ebx
        pushl   %ecx
        pushl   %edx
        pushl   %esi 
        pushl   %edi 

        movl    8(%ebp), %esi                           # esi = start_x
        movl    $dead_base_pic, %edi                    # edi = charr_array_pointer
        movl    $0, %ebx                                # ebx = 0; which is the iteration counter

    redraw_single_city_dead_loop:
        cmpl    $5, %ebx                                # ebx - 5
        je      redraw_single_city_dead_loop_done       # ebx - 5 = 0, ebx = 5, then the loop should end 

        movzbl  (%edi), %ecx                            # ecx = current char
        pushl   %ecx
        pushl   $ROW_OffSET                     
        pushl   %esi    
        call    draw_char_in_text_mode_video            # {x, y, char}
        addl    $12, %esp 
    
        addl    $1, %esi                                # esi = esi + 1; update the y value
        addl    $1, %edi                                # edi = edi + 1; find next element in the char array
        addl    $1, %ebx                                # ebx = ebx + 1; iteration counter ++

        jmp     redraw_single_city_dead_loop            # looping

    redraw_single_city_dead_loop_done:

        popl    %edi 
        popl    %esi
        popl    %edx
        popl    %ecx
        popl    %ebx
        leave
        ret

# Input     : NOTHING
# Outputs   : NOTHING
# Function  : Draw crosshairs
redraw_crosshairs:
        pushl   %ebp
        movl    %esp, %ebp
        pushl   %ebx
        pushl   %esi 
        pushl   %edi 

        movl    crosshairs_x, %esi                  # esi = X_Corsshairs
        movl    crosshairs_y, %edi                  # edi = Y_Corsshairs
        movl    $CORSSHAIRS, %ebx                   # ebx = +
        pushl   %ebx 
        pushl   %edi
        pushl   %esi
        call    draw_char_in_text_mode_video        # {x, y, char}
        addl    $12, %esp

        popl    %edi
        popl    %esi
        popl    %ebx
        leave
        ret

#   jumptable for the five core functions
#   ACCESS: (0)jump_table + 0; (1)jump_table + 4; (2)jump_table + 8; (3)jump_table + 12; (4)jump_table + 16;
jump_table_ioctl:
.long mp1_ioctl_startgame, mp1_ioctl_addmissile, mp1_ioctl_movexhairs, mp1_ioctl_getstatus, mp1_ioctl_endgame

# Input     : NOTHING
# Outputs   : NOTHING
# Function  : kernel start game
mp1_ioctl_startgame:
        pushl   %ebp
        movl    %esp, %ebp
        pushl   %ebx
        pushl   %esi 
        pushl   %edi
        pushl   %ecx
        pushl   %edx

        movl    $0x00010101, base_alive             # base_alive = {padding, alive, alive, avlie}; little_endien
        movl    $0x0, mp1_score                     # mp1_score = 0
        movl    $40, crosshairs_x                   # crosshairs_x = 40
        movl    $12, crosshairs_y                   # crosshairs_y = 12
        movl    $0x0, mp1_missile_list              # mp1_missile_list = nullptr

        popl    %edx
        popl    %ecx
        popl    %edi
        popl    %esi
        popl    %ebx
        leave
        ret

# Input     : missile* user_missile
# Outputs   : 0 indicates add missile successfully
#           : -1 indicates failed
# Function  : Add missile to the list
mp1_ioctl_addmissile:
        pushl   %ebp
        movl    %esp, %ebp
        pushl   %ebx
        pushl   %esi 
        pushl   %edi
        pushl   %ecx
        pushl   %edx

        pushl   $MISSILE_SIZE
        call    mp1_malloc                              # {unsigned long size} {*void}
        addl    $4, %esp
        movl    %eax, %ebx                              # ebx = eax = memory address of the newly-allocated memory
        cmpl    $NULLPTR, %ebx                          # ebx - nullptr
        je      mp1_ioctl_addmissile_done_with_error    # ebx = nullptr, then it generates an error

                                                        
        movl    8(%ebp), %esi                           # esi = user_missile = from
                                                        # ebx = memory address of the newly-allocated memory = to

        pushl   $MISSILE_SIZE
        pushl   %esi
        pushl   %ebx
        call    mp1_copy_from_user                      # mp1_copy_from_user {to, from, size}
        addl    $12, %esp

        cmpl    $0, %eax                                # eax - 0
        jne     mp1_ioctl_addmissile_done_with_error    # eax != 0, which means there generates an error                                            

    mp1_ioctl_addmissile_done_without_error:
                                                        # ebx = memory address of the newly-allocated memory = to
        movl    mp1_missile_list, %esi                  # esi = head_of_linked_list
        movl    %esi, NEXT(%ebx)                        # ebx -> next = new_missile_pointer -> next = head_of_linked_list
        movl    %ebx, mp1_missile_list                  # new_head_of_linked_list = ebx
        movl    $0, %eax                                # eax = 0; succeed
        
        jmp     mp1_ioctl_addmissile_done
    mp1_ioctl_addmissile_done_with_error:
                                                        # ebx = memory address of the newly-allocated memory = to
        pushl   %ebx
        call    mp1_free                                # {ptr}
        addl    $4, %esp

        movl    $-1, %eax                               # eax = -1; fail
    mp1_ioctl_addmissile_done:

        popl    %edx
        popl    %ecx
        popl    %edi
        popl    %esi
        popl    %ebx
        leave
        ret


# Input     : signed 32 bit xhair_delta_packed := \dealta Y: \delta X
# Outputs   : 0, always successfully
# Function  : change the position of crosshairs
mp1_ioctl_movexhairs:
        pushl   %ebp
        movl    %esp, %ebp
        pushl   %ebx
        pushl   %esi 
        pushl   %edi
        pushl   %ecx
        pushl   %edx
        
        movl    8(%ebp), %ebx                           # ebx = xhair_delta_packed
        andl    $LOWER_MASK, %ebx                       # ebx = \delta X with unsigned 0
        movl    8(%ebp), %esi                           # esi = xhair_delta_packed
        andl    $UPPER_MASK, %esi                       # esi = \delta Y : 0000
        sarl    $SHIFT, %esi                            # esi = \delta Y
        shll    $SHIFT, %ebx
        sarl    $SHIFT, %ebx                            # ebx = \delta X with signed extending 

        movl    crosshairs_x, %edi                      # edi = original_X
        addl    %edi, %ebx                              # ebx = ebx + edi = \delta X + original_X = NEW_X
        movl    crosshairs_y, %edi                      # edi = original_Y
        addl    %edi, %esi                              # esi = esi + edi = \delta Y + original_Y = NEW_Y

        pushl   %esi
        pushl   %ebx
        call    whether_in_screen                       # {x, y}; All in lower 16 bits
        addl    $8, %esp

        cmpl    $1, %eax                                # eax - 1
        je      mp1_ioctl_movexhairs_off_screen         # eax = 1, then off_screen

    mp1_ioctl_movexhairs_not_off_screen:
        # redraw at the new position
                                                        # ebx = NEW_X
                                                        # esi = NEW_Y
        pushl   $CORSSHAIRS
        pushl   %esi
        pushl   %ebx
        call    draw_char_in_text_mode_video            # {x, y, char}; All in lower 16 bits
        addl    $12, %esp

        # erase from the original position
        movl    crosshairs_x, %edi                      # edi = original_X
        movl    crosshairs_y, %edx                      # edx = original_Y
        pushl   $SPACE
        pushl   %edx
        pushl   %edi    
        call    draw_char_in_text_mode_video
        addl    $12, %esp

        # update the crosshairs_x, crosshairs_y 
                                                        # ebx = NEW_X
                                                        # esi = NEW_Y
        movl    %ebx, crosshairs_x
        movl    %esi, crosshairs_y
        jmp     mp1_ioctl_movexhairs_done
    mp1_ioctl_movexhairs_off_screen:                
        # because it off_screen, no need to redraw, keep previous crosshair; not need to update the position

    mp1_ioctl_movexhairs_done:

        movl    $0, %eax                                # always return 0
        popl    %edx
        popl    %ecx
        popl    %edi
        popl    %esi
        popl    %ebx
        leave
        ret

# Input     : void* user_status
# Outputs   : 0, means successfully
#           : 1, means fails
# Function  : get status of city and user's score
mp1_ioctl_getstatus:
        pushl   %ebp
        movl    %esp, %ebp
        pushl   %ebx
        pushl   %esi 
        pushl   %edi
        pushl   %ecx
        pushl   %edx

        movl    $0, %edi                                    # edi = 0   

    mp1_ioctl_getstatus_first:
        movzbl  base_alive + 0,  %ebx                       # ebx = first_byte
        cmpl    $0, %ebx                                    # ebx - 0
        je      mp1_ioctl_getstatus_first_not_alive         # ebx == 0, not alive
    mp1_ioctl_getstatus_first_alive:
        addl    $1, %edi                                    # if alive, then edi = edi + 1 
    mp1_ioctl_getstatus_first_not_alive:
        shll     $1, %edi                                    # always shift edi by 1

    mp1_ioctl_getstatus_second:
        movzbl  base_alive + 1,  %ebx                       # ebx = second_byte
        cmpl    $0, %ebx                                    # ebx - 0
        je      mp1_ioctl_getstatus_second_not_alive        # ebx == 0, not alive
    mp1_ioctl_getstatus_second_alive:
        addl    $1, %edi                                    # if alive, then edi = edi + 1 
    mp1_ioctl_getstatus_second_not_alive:
        shll     $1, %edi

    mp1_ioctl_getstatus_third:
        movzbl  base_alive + 2,  %ebx                       # ebx = third_byte
        cmpl    $0, %ebx                                    # ebx - 0
        je      mp1_ioctl_getstatus_third_not_alive         # ebx == 0, not alive
    mp1_ioctl_getstatus_third_alive:
        addl    $1, %edi                                    # if alive, then edi = edi + 1 
    mp1_ioctl_getstatus_third_not_alive:
        shll     $SHIFT, %edi                                # sifht left 16 bits

        movl    mp1_score, %ebx                             # ebx = current_score
        addl    %edi, %ebx                                  # ebx = ebx + edi = citye_status:score
        movl    %ebx, city_status_score                     # M[citye_status_score] = ebx
        movl    8(%ebp), %esi                               # esi = user_status pointer = to

        pushl   $4
        pushl   $city_status_score
        pushl   %esi
        call    mp1_copy_to_user
        addl    $12, %esp                               

        cmpl    $0, %eax                                    # eax - 0
        je      mp1_ioctl_getstatus_succeed                 # eax = 0, then succeed

    mp1_ioctl_getstatus_fail:
        movl    $-1, %eax                                   # if fail, eax = -1 
        jmp     mp1_ioctl_getstatus_done
    mp1_ioctl_getstatus_succeed:
        movl    $0, %eax                                    # if succeed, eax = 0
    
    mp1_ioctl_getstatus_done:


        popl    %edx
        popl    %ecx
        popl    %edi
        popl    %esi
        popl    %ebx
        leave
        ret

# Input     : NOTHING
# Outputs   : NOTHING
# Function  : end the game
mp1_ioctl_endgame:
        pushl   %ebp
        movl    %esp, %ebp
        pushl   %ebx
        pushl   %esi 
        pushl   %edi
        pushl   %ecx
        pushl   %edx

        movl    mp1_missile_list, %ebx              # ebx = head_pointer
    mp1_ioctl_endgame_begin_loop:
                                                    # ebx = head_pointer
        cmpl    $NULLPTR, %ebx                      # ebx - nullptr = head_pointer - nullptr
        je      mp1_ioctl_endgame_done              # head_pointer = nullptr
        movl    NEXT(%ebx), %esi                    # esi = head_pointer -> next_pointer

        pushl   %ebx
        call    mp1_free                            # {pointer}
        addl    $4, %esp

        movl    %esi, %ebx                          # ebx = head_pointer = next_pointer = esi
        jmp     mp1_ioctl_endgame_begin_loop
    mp1_ioctl_endgame_done:
        movl    $NULLPTR, mp1_missile_list          # set as nullptr

        popl    %edx
        popl    %ecx
        popl    %edi
        popl    %esi
        popl    %ebx
        leave
        ret



