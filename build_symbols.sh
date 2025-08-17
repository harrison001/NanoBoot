#!/usr/bin/env bash
set -euo pipefail

# Usage: ./build_symbols.sh [stage2.asm]
ASM="${1:-stage2.asm}"
OBJ="${ASM%.asm}.o"
ELF="${ASM%.asm}.elf"
DBG="${ASM%.asm}.debug"
LDS="link.ld"

echo "[*] Assembling $ASM -> $OBJ (ELF32 + DWARF)"
nasm -f elf32 -g -F dwarf -o "$OBJ" "$ASM"

echo "[*] Writing $LDS (VMA=0x00060000)"
cat > "$LDS" <<'EOF'
ENTRY(pm_start_32)          
SECTIONS
{
  . = 0x00060000;

  .text : ALIGN(16) { *(.text*) }
  .rodata : ALIGN(16) { *(.rodata*) }
  .data : ALIGN(16) { *(.data*) }
  .bss  : ALIGN(16) { *(.bss*) *(COMMON) }
}
EOF

echo "[*] Linking -> $ELF"
ld -m elf_i386 -nostdlib -T "$LDS" -o "$ELF" "$OBJ"

echo "[*] Extracting debug symbols -> $DBG"
objcopy --only-keep-debug "$ELF" "$DBG"

echo "[*] Stripping runtime ELF & adding debuglink"
strip --strip-debug --strip-unneeded "$ELF"
objcopy --add-gnu-debuglink="$DBG" "$ELF"

echo
echo "[+] Done."
echo "    Runtime ELF : $ELF"
echo "    Debug file  : $DBG"
echo "    Linker script: $LDS"
echo
echo "GDB quickstart:"
echo "  (gdb) symbol-file $DBG"
echo "  (gdb) b pm_start_32"
echo "  (gdb) run  # or 'c' when attached to QEMU gdbstub"
