#!/bin/bash

# Support Method A/B selection and feature flags
METHOD=${1:-A}
FEATURES=${2:-""}

if [[ "$METHOD" != "A" && "$METHOD" != "B" ]]; then
    echo "Usage: $0 [A|B] [FEATURES]"
    echo "  A - Method A (Runtime GDT patching) [default]"
    echo "  B - Method B (Flat addressing)"
    echo ""
    echo "Available FEATURES (space-separated):"
    echo "  EXC       - Exception vector handling (0-19)"
    echo "  PIC       - PIC remapping + IRQ0 timer interrupt" 
    echo "  INTEGRITY - GDT/IDT 16-bit checksum verification"
    echo "  SCHED     - Preemptive multitasking scheduler demo"
    echo ""
    echo "Examples:"
    echo "  $0 A                    # Method A, no extra features"
    echo "  $0 A \"EXC PIC\"          # Method A with exceptions and PIC"
    echo "  $0 B \"EXC PIC INTEGRITY\" # Method B with all features"
    echo "  $0 A \"PIC SCHED\"        # Method A with scheduler demo"
    exit 1
fi

echo "Building Protected Mode Bootloader (Method $METHOD) with Custom Interrupt Demo..."
if [[ -n "$FEATURES" ]]; then
    echo "Enabled features: $FEATURES"
fi

# Assemble both stages
echo "Assembling Stage1 (MBR bootloader)..."
nasm -f bin bootloader_stage1.asm -o bootloader_stage1.bin

echo "Assembling Stage2 (Protected mode with IDT) - Method $METHOD..."

# Build feature flags for NASM
NASM_FLAGS=""
if [[ "$METHOD" == "A" ]]; then
    NASM_FLAGS="-dMETHOD_A"
    echo "Using Method A: Runtime GDT patching, immediate jump"
else
    NASM_FLAGS="-dMETHOD_B"
    echo "Using Method B: Flat addressing, indirect jump"
fi

# Add feature flags
for feature in $FEATURES; do
    case $feature in
        EXC)
            NASM_FLAGS="$NASM_FLAGS -dENABLE_EXC"
            echo "  + Exception vector handling (0-19)"
            ;;
        PIC)
            NASM_FLAGS="$NASM_FLAGS -dENABLE_PIC"
            echo "  + PIC remapping + IRQ0 timer interrupt"
            ;;
        INTEGRITY)
            NASM_FLAGS="$NASM_FLAGS -dENABLE_INTEGRITY"
            echo "  + GDT/IDT integrity checking"
            ;;
        SCHED)
            NASM_FLAGS="$NASM_FLAGS -dENABLE_SCHED"
            echo "  + Preemptive multitasking scheduler demo"
            ;;
        *)
            echo "Warning: Unknown feature '$feature' ignored"
            ;;
    esac
done

# Assemble with flags
nasm -f bin bootloader_stage2.asm -o bootloader_stage2.bin $NASM_FLAGS

# Check if assembly succeeded
if [ $? -eq 0 ]; then
    echo "Both stages assembled successfully!"
    
    # Show file sizes
    echo "File sizes:"
    ls -la bootloader_stage1.bin bootloader_stage2.bin
    
    echo "Creating hard disk image..."
    
    # Create 10MB hard disk image
    dd if=/dev/zero of=bootloader.img bs=512 count=20480 2>/dev/null
    
    # Write stage1 to boot sector (sector 0)
    dd if=bootloader_stage1.bin of=bootloader.img conv=notrunc bs=512 seek=0 2>/dev/null
    echo "Stage1 (MBR) written to sector 0"
    
    # Write stage2 to sectors 1-16 (stage2 needs up to 16 sectors for full features)
    dd if=bootloader_stage2.bin of=bootloader.img conv=notrunc bs=512 seek=1 2>/dev/null
    echo "Stage2 (Protected Mode + IDT) written to sectors 1-16"
    
    echo ""
    echo "Bootloader ready: bootloader.img"
    echo "Test with: qemu-system-i386 -drive file=bootloader.img,format=raw"
else
    echo "Assembly failed!"
    exit 1
fi