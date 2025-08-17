# --- GDB bootstrap for stage2 ---
set pagination off
set disassemble-next-line on
set confirm off
set print asm-demangle on
set disassemble-flavor intel

# 1)Connect to QEMU gdbstub
target remote :1234

# 2)Real-mode decoding first
set architecture i8086

# 3)Load separate symbols (built by build_symbols.sh)
symbol-file stage2.debug

# 4) Break at 32-bit entry; when hit, switch to i386 decoding
break pm_start_32
commands
  silent
  echo \n*** hit pm_start_32, switching to i386 mode ***\n
  set architecture i386
  info registers
  x/12i $eip
  continue
end