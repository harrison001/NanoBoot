; =========================
; File: bootloader_stage2.asm
; =========================
[bits 16]
[org 0x0]                  ; IP starts from 0, but CS=0x6000

; ===== Feature toggles =====
; nasm -dENABLE_EXC       : Exception vector handling (0-19)
; nasm -dENABLE_PIC       : PIC remapping + IRQ0 timer interrupt
; nasm -dENABLE_INTEGRITY : GDT/IDT 16-bit checksum verification
; nasm -dENABLE_SCHED     : Preemptive multitasking scheduler demo

;----------------------------------------
; Configuration - Use METHOD_A or METHOD_B
;----------------------------------------
%ifndef METHOD_A
    %ifndef METHOD_B
        %define METHOD_A        ; Default to METHOD_A if neither defined
    %endif
%endif

;----------------------------------------
; Method-specific constants and macros
;----------------------------------------
%ifdef METHOD_A
    %define PM_CODE_SEL   SEL_CODEA     ; Use runtime-patched segment (0x08)
    %define PM_ENTRY_MODE 0             ; 0 = immediate jump, 1 = indirect jump
    %define HANDLER_ADDR_MODE 0         ; 0 = offset only, 1 = linear address
    %define METHOD_NAME "Method A (Runtime GDT patch)"
%endif

%ifdef METHOD_B
    %define PM_CODE_SEL   SEL_CODEB     ; Use flat segment (0x10)
    %define PM_ENTRY_MODE 1             ; 0 = immediate jump, 1 = indirect jump
    %define HANDLER_ADDR_MODE 1         ; 0 = offset only, 1 = linear address
    %define METHOD_NAME "Method B (Flat addressing)"
%endif

;----------------------------------------
; Scheduler constants (preemptive multitasking)
;----------------------------------------
%ifdef ENABLE_SCHED
    %define KCODE      PM_CODE_SEL      ; Ring0 code selector (0x08 or 0x10)
    %define KDATA      0x18             ; Ring0 data selector
    %define TICK_HZ    50               ; PIT frequency for demo (50Hz = 20ms slices)
%endif

;----------------------------------------
; Stage 2 - Simplified 16-bit loader with integrated 32-bit protected mode
;----------------------------------------
stage2_start:
    mov ax, cs            ; CS is already 0x6000
    mov ds, ax
    mov ss, ax
    mov sp, 0x7c00
    mov es, ax

    mov si, stage2_msg
    call print_string

    mov si, entering_pm_msg
    call print_string

    cli

    ; Calculate correct GDT physical address at runtime
    mov ax, cs
    mov dx, 16
    mul dx                  ; AX = CS * 16
    add ax, gdt_start
    adc dx, 0

    ; Store in GDT descriptor
    mov [gdt_descriptor + 2], ax
    mov [gdt_descriptor + 4], dx

    ;-------------------------------------------- Protected Mode Entry ----------------------------------------
    %if PM_ENTRY_MODE == 1
        ; Method B: Indirect jump via far pointer (linear target)
        xor  eax, eax
        mov  ax, cs
        shl  eax, 4
        add  eax, pm_start_32
        mov  [farptr+0], eax
        mov  word [farptr+4], PM_CODE_SEL
    %endif

    %if PM_ENTRY_MODE == 0
        ; Method A: runtime patch code segment base to CS<<4
        mov  ax, cs
        mov  dx, 16
        mul  dx              ; DX:AX = CS * 16

        mov  di, gdt_start
        add  di, 8           ; descriptor 1 (CodeA)
        mov  [di+2], ax      ; base_low
        mov  [di+4], dl      ; base_mid
        mov  [di+7], dh      ; base_high
    %endif

    lgdt [gdt_descriptor]

    mov eax, cr0
    or  eax, 1
    mov cr0, eax

    %if PM_ENTRY_MODE == 0
        jmp PM_CODE_SEL:pm_start_32
    %endif
    %if PM_ENTRY_MODE == 1
        jmp far dword [farptr]
    %endif
    ;-----------------------------------------------------------------------------------------------------

;----------------------------------------
; 16-bit print function
;----------------------------------------
print_string:
    mov ah, 0x0e
.loop:
    lodsb
    test al, al
    jz .done
    int 0x10
    jmp .loop
.done:
    ret

;----------------------------------------
; Data
;----------------------------------------
stage2_msg db "Stage2 simplified loader started!", 13, 10, 0
entering_pm_msg db "Entering protected mode...", 13, 10, 0

; =========================
; GDT table (32-bit pmode)
; =========================

farptr: dd 0, 0
temp_jump_addr: dd 0, 0

; selectors
SEL_NULL   equ 0x00
SEL_CODEA  equ 0x08
SEL_CODEB  equ 0x10
SEL_DATA   equ 0x18

%macro DESC 4
    dw  (%2) & 0xFFFF
    dw  (%1) & 0xFFFF
    db  ((%1) >> 16) & 0xFF
    db  %3
    db  (((%2) >> 16) & 0x0F) | ((%4) & 0xF0)
    db  ((%1) >> 24) & 0xFF
%endmacro

ACC_CODE32  equ 10011010b
ACC_DATA32  equ 10010010b
FLG_GRAN4K  equ 11000000b
LIM_4GB     equ 0x000FFFFF

align 8
gdt_start:
    dd 0, 0
    DESC 0x00000000, LIM_4GB, ACC_CODE32, FLG_GRAN4K ; CodeA (base patched at runtime)
    DESC 0x00000000, LIM_4GB, ACC_CODE32, FLG_GRAN4K ; CodeB (flat base=0)
    DESC 0x00000000, LIM_4GB, ACC_DATA32, FLG_GRAN4K ; Data  (flat base=0)
gdt_end:

gdt_descriptor:
    dw gdt_end - gdt_start - 1
    dd 0

;----------------------------------------
; 32-bit protected mode code
;----------------------------------------
[bits 32]
pm_start_32:
    mov ax, 0x18
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    mov esp, 0x90000

    ; Clear screen
    mov edi, 0xb8000
    mov eax, 0x07200720
    mov ecx, 1000
    rep stosd

%ifdef METHOD_A
    ; "METHOD A + IDT"
    mov word [0xb8000], 0x0F4D
    mov word [0xb8002], 0x0F45
    mov word [0xb8004], 0x0F54
    mov word [0xb8006], 0x0F48
    mov word [0xb8008], 0x0F4F
    mov word [0xb800a], 0x0F44
    mov word [0xb800c], 0x0F20
    mov word [0xb800e], 0x0F41
    mov word [0xb8010], 0x0F20
    mov word [0xb8012], 0x0F2B
    mov word [0xb8014], 0x0F20
    mov word [0xb8016], 0x0F49
    mov word [0xb8018], 0x0F44
    mov word [0xb801a], 0x0F54
%endif
%ifdef METHOD_B
    ; "METHOD B + IDT"
    mov word [0xb8000], 0x0F4D
    mov word [0xb8002], 0x0F45
    mov word [0xb8004], 0x0F54
    mov word [0xb8006], 0x0F48
    mov word [0xb8008], 0x0F4F
    mov word [0xb800a], 0x0F44
    mov word [0xb800c], 0x0F20
    mov word [0xb800e], 0x0F42
    mov word [0xb8010], 0x0F20
    mov word [0xb8012], 0x0F2B
    mov word [0xb8014], 0x0F20
    mov word [0xb8016], 0x0F49
    mov word [0xb8018], 0x0F44
    mov word [0xb801a], 0x0F54
%endif

    call setup_idt

    ; "IDT SETUP"
    mov word [0xb8160], 0x0E49
    mov word [0xb8162], 0x0E44
    mov word [0xb8164], 0x0E54
    mov word [0xb8166], 0x0E20
    mov word [0xb8168], 0x0E53
    mov word [0xb816a], 0x0E45
    mov word [0xb816c], 0x0E54
    mov word [0xb816e], 0x0E55
    mov word [0xb8170], 0x0E50

%ifdef ENABLE_INTEGRITY
    sgdt [current_gdt_desc]
    movzx ecx, word [current_gdt_desc]
    inc   ecx
    mov   esi, [current_gdt_desc+2]
    call checksum16
    mov [gdt_cksum], ax

    sidt [current_idt_desc]
    movzx ecx, word [current_idt_desc]
    inc   ecx
    mov   esi, [current_idt_desc+2]
    call checksum16
    mov [idt_cksum], ax

    mov word [0xb81bc], 0x0B47
    mov word [0xb81be], 0x0B44
    mov word [0xb81c0], 0x0B54
    mov word [0xb81c2], 0x0B3A
    movzx eax, word [gdt_cksum]
    mov edi, 0xb81c4
    call print_hex16_at_edi

    mov word [0xb81cc], 0x0B20
    mov word [0xb81ce], 0x0B49
    mov word [0xb81d0], 0x0B44
    mov word [0xb81d2], 0x0B54
    mov word [0xb81d4], 0x0B3A
    movzx eax, word [idt_cksum]
    mov edi, 0xb81d6
    call print_hex16_at_edi
%endif

    ; "INT 0x30 TRIGGERED"
    mov word [0xb8320], 0x0C49
    mov word [0xb8322], 0x0C4E
    mov word [0xb8324], 0x0C54
    mov word [0xb8326], 0x0C20
    mov word [0xb8328], 0x0C30
    mov word [0xb832a], 0x0C78
    mov word [0xb832c], 0x0C33
    mov word [0xb832e], 0x0C30
    mov word [0xb8330], 0x0C20
    mov word [0xb8332], 0x0C54
    mov word [0xb8334], 0x0C52
    mov word [0xb8336], 0x0C49
    mov word [0xb8338], 0x0C47
    mov word [0xb833a], 0x0C47
    mov word [0xb833c], 0x0C45
    mov word [0xb833e], 0x0C52
    mov word [0xb8340], 0x0C45
    mov word [0xb8342], 0x0C44

    int 0x30

%ifdef ENABLE_SCHED
    call init_scheduler
%endif

    ; "DONE - STOPPED"
    mov word [0xb86a0], 0x0B44
    mov word [0xb86a2], 0x0B4F
    mov word [0xb86a4], 0x0B4E
    mov word [0xb86a6], 0x0B45
    mov word [0xb86a8], 0x0B20
    mov word [0xb86aa], 0x0B2D
    mov word [0xb86ac], 0x0B20
    mov word [0xb86ae], 0x0B53
    mov word [0xb86b0], 0x0B54
    mov word [0xb86b2], 0x0B4F
    mov word [0xb86b4], 0x0B50
    mov word [0xb86b6], 0x0B50
    mov word [0xb86b8], 0x0B45
    mov word [0xb86ba], 0x0B44

.halt:
%ifdef ENABLE_PIC
    sti
%else
    cli
%endif
    hlt
    jmp .halt

;----------------------------------------
; Setup IDT
;----------------------------------------
setup_idt:
    mov edi, idt_table
    xor eax, eax
    mov ecx, 512
    rep stosd

    ; INT 0x30
%if HANDLER_ADDR_MODE == 0
    mov eax, custom_interrupt_handler
%else
    mov eax, 0x60000
    add eax, custom_interrupt_handler
%endif
    mov ebx, idt_table
    add ebx, (0x30 * 8)
    mov [ebx], ax
    mov word [ebx + 2], PM_CODE_SEL
    shr eax, 16
    mov [ebx + 6], ax
    mov word [ebx + 4], 0x8E00

%ifdef ENABLE_EXC
    %define IDT_ATTR 0x8E00
    %define KCODE    PM_CODE_SEL
    call install_exception_handlers
%endif

%ifdef ENABLE_PIC
    call install_irq0_handler
    call pic_remap
%endif

    mov word [idt_descriptor], (256 * 8) - 1
    mov eax, idt_table
    mov [idt_descriptor + 2], eax
    lidt [idt_descriptor]
    ret

;----------------------------------------
; Custom interrupt handler (INT 0x30)
;----------------------------------------
custom_interrupt_handler:
    mov word [ds:0xb84e0], 0x0A48 ; H
    mov word [ds:0xb84e2], 0x0A41 ; A
    mov word [ds:0xb84e4], 0x0A4E ; N
    mov word [ds:0xb84e6], 0x0A44 ; D
    mov word [ds:0xb84e8], 0x0A4C ; L
    mov word [ds:0xb84ea], 0x0A45 ; E
    mov word [ds:0xb84ec], 0x0A52 ; R
    iret

;=============== Exception Vector Handling (0-19) ===============
%ifdef ENABLE_EXC
%macro ISR_NOERR 1
isr_%1:
    push dword 0
    push dword %1
    jmp isr_common_noerr
%endmacro

%macro ISR_ERR 1
isr_%1:
    push dword %1
    jmp isr_common_err
%endmacro

%macro SET_IDT 4
    mov ebx, idt_table
    add ebx, (%1)*8
%if HANDLER_ADDR_MODE == 0
    mov eax, %2
%else
    mov eax, 0x60000
    add eax, %2
%endif
    mov [ebx], ax
    mov word [ebx+2], %3
    shr eax, 16
    mov [ebx+6], ax
    mov word [ebx+4], %4
%endmacro

isr_common_noerr:
    pusha
    mov ax, 0x18
    mov ds, ax
    mov es, ax
    mov eax, [esp+36]
    mov ebx, [esp+32]
    mov word [ds:0xb84e0], 0x0C45
    mov word [ds:0xb84e2], 0x0C58
    mov word [ds:0xb84e4], 0x0C43
    mov word [ds:0xb84e6], 0x0C3A
    push eax
    mov edi, 0xb84e8
    call print_hex8_at_edi
    pop eax
    popa
    add esp, 8
    iretd

isr_common_err:
    pusha
    mov ax, 0x18
    mov ds, ax
    mov es, ax
    mov eax, [esp+36]
    mov ebx, [esp+40]
    mov word [ds:0xb84e0], 0x0C45
    mov word [ds:0xb84e2], 0x0C58
    mov word [ds:0xb84e4], 0x0C43
    mov word [ds:0xb84e6], 0x0C3A
    push eax
    mov edi, 0xb84e8
    call print_hex8_at_edi
    pop eax
    mov word [ds:0xb84f0], 0x0C20
    mov word [ds:0xb84f2], 0x0C45
    mov word [ds:0xb84f4], 0x0C52
    mov word [ds:0xb84f6], 0x0C52
    mov word [ds:0xb84f8], 0x0C3A
    mov eax, ebx
    mov edi, 0xb84fa
    call print_hex8_at_edi
    popa
    add esp, 4
    iretd

ISR_NOERR 0
ISR_NOERR 1
ISR_NOERR 2
ISR_NOERR 3
ISR_NOERR 4
ISR_NOERR 5
ISR_NOERR 6
ISR_NOERR 7
ISR_NOERR 9
ISR_NOERR 16
ISR_NOERR 18
ISR_NOERR 19

ISR_ERR 8
ISR_ERR 10
ISR_ERR 11
ISR_ERR 12
ISR_ERR 13
ISR_ERR 14
ISR_ERR 17

install_exception_handlers:
    push eax
    push ebx

    ; Example: install only 0,1,2,13 (add others as needed with SET_IDT)
    mov ebx, idt_table
    add ebx, 0*8
%if HANDLER_ADDR_MODE == 0
    mov eax, isr_0
%else
    mov eax, 0x60000
    add eax, isr_0
%endif
    mov [ebx], ax
    mov word [ebx+2], PM_CODE_SEL
    shr eax, 16
    mov [ebx+6], ax
    mov word [ebx+4], 0x8E00

    mov ebx, idt_table
    add ebx, 1*8
%if HANDLER_ADDR_MODE == 0
    mov eax, isr_1
%else
    mov eax, 0x60000
    add eax, isr_1
%endif
    mov [ebx], ax
    mov word [ebx+2], PM_CODE_SEL
    shr eax, 16
    mov [ebx+6], ax
    mov word [ebx+4], 0x8E00

    mov ebx, idt_table
    add ebx, 2*8
%if HANDLER_ADDR_MODE == 0
    mov eax, isr_2
%else
    mov eax, 0x60000
    add eax, isr_2
%endif
    mov [ebx], ax
    mov word [ebx+2], PM_CODE_SEL
    shr eax, 16
    mov [ebx+6], ax
    mov word [ebx+4], 0x8E00

    mov ebx, idt_table
    add ebx, 13*8
%if HANDLER_ADDR_MODE == 0
    mov eax, isr_13
%else
    mov eax, 0x60000
    add eax, isr_13
%endif
    mov [ebx], ax
    mov word [ebx+2], PM_CODE_SEL
    shr eax, 16
    mov [ebx+6], ax
    mov word [ebx+4], 0x8E00

    pop ebx
    pop eax
    ret
%endif ; ENABLE_EXC

;=============== PIC Remapping + IRQ0 Timer Interrupt ===============
%ifdef ENABLE_PIC
PIC1_CMD   equ 0x20
PIC1_DATA  equ 0x21
PIC2_CMD   equ 0xA0
PIC2_DATA  equ 0xA1
EOI        equ 0x20

; Optional PIT setup
PIT_CMD  equ 0x43
PIT_CH0  equ 0x40
%ifndef TICK_HZ
    %define TICK_HZ 50
%endif
%define PIT_DIV (1193182 / TICK_HZ)

pit_init:
    mov al, 00110110b            ; ch0, lobyte/hibyte, mode3
    out PIT_CMD, al
    mov ax, PIT_DIV
    out PIT_CH0, al              ; low
    mov al, ah
    out PIT_CH0, al              ; high
    ret

pic_remap:
    in   al, PIC1_DATA
    push eax
    in   al, PIC2_DATA
    push eax

    mov al, 0x11
    out PIC1_CMD, al
    out PIC2_CMD, al

    mov al, 0x20                 ; master -> 0x20..0x27
    out PIC1_DATA, al
    mov al, 0x28                 ; slave  -> 0x28..0x2F
    out PIC2_DATA, al

    mov al, 0x04                 ; master has slave on IRQ2
    out PIC1_DATA, al
    mov al, 0x02                 ; slave id
    out PIC2_DATA, al

    mov al, 0x01                 ; 8086 mode
    out PIC1_DATA, al
    out PIC2_DATA, al

    pop eax
    mov al, 0xFF
    out PIC2_DATA, al            ; mask all slave

    pop eax
    mov al, 0xFE                 ; enable only IRQ0
    out PIC1_DATA, al
    ret

; IRQ0 handler - using pushad/popad
isr_irq0:
    pushad
    mov  ax, 0x18
    mov  ds, ax
    mov  es, ax

    inc dword [irq0_ticks]
    cmp dword [irq0_ticks], 1
    jne .skip_label
    mov word [ds:0xb8064], 0x0E54
    mov word [ds:0xb8066], 0x0E49
    mov word [ds:0xb8068], 0x0E43
    mov word [ds:0xb806a], 0x0E4B
    mov word [ds:0xb806c], 0x0E53
    mov word [ds:0xb806e], 0x0E3A
.skip_label:
    mov eax, [irq0_ticks]
    and eax, 0xFF
    mov edi, 0xb8070
    call print_hex8_at_edi

%ifdef ENABLE_SCHED
    jmp scheduler_switch         ; No return: popad/iretd from "new task" stack
%endif

    mov al, EOI
    out PIC1_CMD, al
    popad
    iretd

install_irq0_handler:
    push eax
    push ebx
    mov ebx, idt_table
    add ebx, 0x20*8
%if HANDLER_ADDR_MODE == 0
    mov eax, isr_irq0
%else
    mov eax, 0x60000
    add eax, isr_irq0
%endif
    mov [ebx], ax
    mov word [ebx+2], PM_CODE_SEL
    shr eax, 16
    mov [ebx+6], ax
    mov word [ebx+4], 0x8E00
    pop ebx
    pop eax
    ret

irq0_ticks: dd 0
%endif ; ENABLE_PIC

;=============== GDT/IDT Integrity Checking ===============
%ifdef ENABLE_INTEGRITY
checksum16:
    push ebx
    push edx
    xor eax, eax
    test ecx, ecx
    jz .done
.ck_loop:
    movzx edx, byte [esi]
    add ax, dx
    inc esi
    dec ecx
    jnz .ck_loop
.done:
    pop edx
    pop ebx
    ret

gdt_cksum: dw 0
idt_cksum: dw 0
current_gdt_desc: dw 0, 0, 0
current_idt_desc: dw 0, 0, 0
%endif ; ENABLE_INTEGRITY

;----------------------------------------
; Print Utilities
;----------------------------------------
print_hex8_at_edi:
    push eax
    push ebx
    mov bl, al
    shr bl, 4
    and bl, 0x0F
    cmp bl, 9
    jbe .high_digit
    add bl, 'A' - 10 - '0'
.high_digit:
    add bl, '0'
    mov bh, 0x0C
    mov [edi], bx
    add edi, 2

    mov bl, al
    and bl, 0x0F
    cmp bl, 9
    jbe .low_digit
    add bl, 'A' - 10 - '0'
.low_digit:
    add bl, '0'
    mov bh, 0x0C
    mov [edi], bx
    add edi, 2
    pop ebx
    pop eax
    ret

print_hex16_at_edi:
    push ebx
    mov bx, ax
    mov al, bh
    call print_hex8_at_edi
    mov al, bl
    call print_hex8_at_edi
    pop ebx
    ret


run_chars db 'A','B','I'

update_run_at_schd:
    push eax
    push ebx
    mov  ebx, [current_task]     ; 0=A, 1=B, 2=Idle
    mov  edi, 0x60000
    mov  al,  [edi + run_chars + ebx]
    mov  ah,  0x0E               ; Yellow text more visible
    mov  [0xb860C], ax
    pop  ebx
    pop  eax
    ret

;----------------------------------------
; ===== Scheduler (ENABLE_SCHED) =====
;----------------------------------------
%ifdef ENABLE_SCHED

; Build initial context: match pushad/popad + iretd stack layout
; IN:  EBX = task entry (label), ECX = stack top linear
; OUT: EAX = initial ESP for this task
build_initial_frame:
    push edx
    mov  edx, ecx
    sub  edx, (8*4 + 3*4)      ; 8 regs + IRET = 44 bytes

    ; Register slots for popad order (written in reverse order)
    mov dword [edx+ 0], 0      ; EDI
    mov dword [edx+ 4], 0      ; ESI
    mov dword [edx+ 8], 0      ; EBP
    mov dword [edx+12], 0      ; ESP (dummy, popad ignores)
    mov dword [edx+16], 0      ; EBX
    mov dword [edx+20], 0      ; EDX
    mov dword [edx+24], 0      ; ECX
    mov dword [edx+28], 0      ; EAX

%ifdef METHOD_B
    mov eax, 0x60000
    add eax, ebx               ; Linear EIP
%else
    mov eax, ebx               ; Offset EIP
%endif
    mov dword [edx+32], eax    ; EIP
    mov dword [edx+36], KCODE  ; CS
    mov dword [edx+40], 0x202  ; EFLAGS (IF=1)

    mov eax, edx               ; Return ESP
    pop edx
    ret

; Three example tasks
task_a:
.loop_a:
    inc dword [task_a_counter]
    mov eax, [task_a_counter]
    and eax, 0xFF
    mov edi, 0xb8504
    call print_hex8_at_edi
    mov ecx, 0x50000
.delay_a:
    dec ecx
    jnz .delay_a
    sti
    jmp .loop_a

task_b:
.loop_b:
    inc dword [task_b_counter]
    mov eax, [task_b_counter]
    and eax, 0xFF
    mov edi, 0xb852c
    call print_hex8_at_edi
    mov ecx, 0x5000000
.delay_b:
    dec ecx
    jnz .delay_b
    sti
    jmp .loop_b

idle_task:
.loop_idle:
    inc dword [idle_counter]
    mov eax, [idle_counter]
    and eax, 0xFF
    mov edi, 0xb8554
    call print_hex8_at_edi
    mov ecx, 0x20000
.delay_idle:
    dec ecx
    jnz .delay_idle
    sti
    jmp .loop_idle

; Initialize scheduler
init_scheduler:
    push eax
    push ebx
    push ecx
%ifdef ENABLE_PIC
    call pit_init              ; Optional: set timer frequency
%endif
    ; Task A
    mov  ebx, task_a
    mov  ecx, 0x60000
    add  ecx, task_a_stack_top
    call build_initial_frame
    mov  [pcb_table + 0*32 + 0], eax

    ; Task B
    mov  ebx, task_b
    mov  ecx, 0x60000
    add  ecx, task_b_stack_top
    call build_initial_frame
    mov  [pcb_table + 1*32 + 0], eax

    ; Idle
    mov  ebx, idle_task
    mov  ecx, 0x60000
    add  ecx, idle_stack_top
    call build_initial_frame
    mov  [pcb_table + 2*32 + 0], eax

    mov  dword [current_task], 0

    ; Simple UI labels
    mov word [0xb8600], 0x0E53  ; 'S'
    mov word [0xb8602], 0x0E43  ; 'C'
    mov word [0xb8604], 0x0E48  ; 'H'
    mov word [0xb8606], 0x0E44  ; 'D'
    mov word [0xb8608], 0x0F3A   ; ':'
    mov word [0xb860C], 0x0441   ; 'A'
   



    mov word [0xb8500], 0x0441  ; 'A'
    mov word [0xb8502], 0x043A  ; ':'
    mov word [0xb8528], 0x0542  ; 'B'
    mov word [0xb852a], 0x053A  ; ':'
    mov word [0xb8550], 0x0749  ; 'I'
    mov word [0xb8552], 0x073A  ; ':'

    pop ecx
    pop ebx
    pop eax
    ret

; Real switching: first round directly starts Task A; then round-robin save/load ESP
scheduler_switch:
    ; Conservative approach: set DS/ES to kernel data segment on scheduler entry
    push eax
    mov  ax, KDATA
    mov  ds, ax
    mov  es, ax
    pop  eax

    ; ---------------- First round: direct jump to Task A ----------------
    cmp  dword [scheduler_started], 0
    jne  .normal_switch

    ; Set current task to 0 (Task A), load its pre-built ESP
    mov  dword [current_task], 0
    mov  edx, 0
    shl  edx, 5                 ; edx = 0 * 32
    add  edx, pcb_table         ; &pcb_table[0]
    mov  esp, [edx]             ; Load Task A's initial ESP
    mov  dword [scheduler_started], 1
    call update_run_at_schd

%ifdef ENABLE_PIC
    mov  al, EOI
    out  PIC1_CMD, al
%endif
    popad
    iretd

.normal_switch:
    ; ---------------- Normal rotation: save current → select next → load ----------------
    mov  eax, [current_task]

    ; Save current task ESP to its PCB
    mov  edx, eax
    shl  edx, 5                 ; edx = eax * 32
    add  edx, pcb_table         ; &pcb_table[eax]
    mov  [edx], esp             ; save current ESP

    ; Round-robin to next task (0->1->2->0)
    inc  eax
    cmp  eax, 3
    jb   .ok
    xor  eax, eax
.ok:
    mov  [current_task], eax
    call update_run_at_schd

    ; Load next task ESP
    mov  edx, eax
    shl  edx, 5                 ; edx = eax * 32
    add  edx, pcb_table         ; &pcb_table[eax]
    mov  esp, [edx]             ; load next ESP

%ifdef ENABLE_PIC
    mov  al, EOI
    out  PIC1_CMD, al
%endif
    popad
    iretd

; ---- Scheduler Data ----
align 4
pcb_table:
    ; Task A PCB (32 bytes each). Only ESP[0] used in this version, rest reserved
    dd 0,0,0,0,0,0,0,0
    dd 0,0,0,0,0,0,0,0
    dd 0,0,0,0,0,0,0,0

current_task      dd 0
scheduler_started dd 0
switch_counter    dd 0

task_a_counter    dd 0
task_b_counter    dd 0
idle_counter      dd 0

align 16
task_a_stack: times 256 dd 0
task_a_stack_top:
task_b_stack: times 256 dd 0
task_b_stack_top:
idle_stack:   times 256 dd 0
idle_stack_top:
%endif ; ENABLE_SCHED

;----------------------------------------
; IDT Table and Descriptor
;----------------------------------------
align 8
idt_table:
    times 256 dq 0

idt_descriptor:
    dw 0
    dd 0

; =========================
; ===== Build & Run =======
; =========================
; Example:
;   nasm stage2_sched.asm -f bin -o stage2.bin -dMETHOD_B -dENABLE_PIC -dENABLE_SCHED
; Then load to CS=0x6000 via your stage1 and execute; or follow your existing boot flow.