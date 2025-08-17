[bits 16]
[org 0x7c00]

start:
    cli                     ; Disable interrupts
    cld                     ; Clear direction flag
    xor ax, ax             ; Clear AX
    mov ds, ax             ; Set data segment
    mov es, ax             ; Set extra segment
    mov ss, ax             ; Set stack segment
    mov bp, 0x7c00         ; Set base pointer
    lea sp, [bp-0x20]      ; Set stack pointer
    sti                     ; Enable interrupts

    ; Display system information
    lea si, [system_info]
    call print_string
    lea si, [security_msg]
    call print_string
    lea si, [divider_msg]
    call print_string


    ; Set Stage1 completion marker
    mov byte [stage1_complete], 0xAA    ; Mark stage1 as completed
    
    ; Direct load Stage2 without partition search
    lea si, [loading_msg]
    call print_string
    
    ; Verify Stage1 completion before loading Stage2
    cmp byte [stage1_complete], 0xAA
    jne stage1_error
    
    lea si, [stage1_ok_msg]
    call print_string

    ; Load Stage2 to 0x6000
    mov ax, 0x6000          ; Stage2 load address segment
    mov es, ax
    xor bx, bx              ; Offset address = 0
    mov ah, 0x02            ; BIOS 13h - Read sectors
    mov al, 16              ; Read 16 sectors (for up to 8192 byte stage2)
    mov ch, 0               ; Cylinder 0
    mov cl, 2               ; Sector 2 (starting sector)
    mov dh, 0               ; Head 0
    mov dl, [boot_drive]    ; Boot drive number
    int 0x13
    jc load_error

    ; Set Stage1 to Stage2 transition marker
    mov byte [stage2_entry], 0xBB       ; Mark stage2 entry preparation
    
    ; Jump to Stage2
    jmp 0x6000:0 

stage1_error:
    lea si, [stage1_error_msg]
    call print_string
    jmp $

load_error:
    lea si, [stage2_load_error]
    call print_string
    jmp $

print_string:
    mov ah, 0x0E
.loop:
    lodsb
    test al, al
    jz .done
    int 0x10
    jmp .loop
.done:
    ret

print_newline:
    mov ah, 0x0e
    mov al, 13        ; Carriage return
    int 0x10
    mov al, 10        ; Line feed
    int 0x10
    ret

print_hex:
    push ax
    mov bx, 0x10          ; Base 16
    xor cx, cx
.next_digit:
    xor dx, dx
    div bx                ; AX divided by 16, result in AL
    push dx
    inc cx
    test ax, ax
    jnz .next_digit
.print_digit:
    pop dx
    add dl, '0'
    cmp dl, '9'
    jbe .output
    add dl, 'A' - '9' - 1
.output:
    mov ah, 0x0e
    mov al, dl
    int 0x10
    loop .print_digit
    pop ax
    ret

stage2_load_error db "Error loading Stage2!", 13, 10, 0
stage1_error_msg db "Stage1 execution check failed!", 13, 10, 0
stage1_ok_msg db "Stage1 completed successfully", 13, 10, 0
loading_msg db "Loading Stage2...", 13, 10, 0
boot_drive db 0x80          ; Boot drive number
stage1_complete db 0        ; Stage1 completion marker
stage2_entry db 0           ; Stage2 entry marker

    times 446-($-$$) db 0   ; Fill up to partition table start

    ; Partition table (first partition is active)
    ;db 0x80, 0x01, 0x01, 0x00  ; Active partition flag
    ;db 0x0E, 0xFE, 0xFF, 0xFF  ; Partition type and CHS address
    ;db 0x3F, 0x00, 0x00, 0x00  ; Starting sector count
    ;db 0xC1, 0xFE, 0x0F, 0x00  ; Total sector count


; Add system information messages
system_info      db "SentinelOS v1.0", 13, 10, 0
security_msg     db "Secure Boot", 13, 10, 0
divider_msg      db "============", 13, 10, 0

    times 510-($-$$) db 0   ; Fill up to byte 510
dw 0xAA55               ; Boot signature
