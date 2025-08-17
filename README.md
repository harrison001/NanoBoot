# x86 Bootloader Framework (Demo from Production System)

## 📌 Background
This project is a **public, simplified demonstration** of a custom bootloader framework I originally developed for enterprise embedded systems.  

The **production system** was deployed in security-critical environments (finance, automotive, industrial control) with features such as:  
- TPM-based **secure boot and attestation**  
- **Encrypted signature verification** and hardware-backed chain of trust  
- **Deterministic real-time scheduling** with sub-millisecond interrupt handling  
- **Regulatory compliance** and hardened fault-tolerance mechanisms  

This **demo version** keeps the architectural spirit and technical patterns, while simplifying security and runtime features for educational and portfolio purposes.

---

## 🎯 Goals of This Demo
- Showcase **system programming expertise** on x86 boot and kernel primitives  
- Provide an **architecture-level view** of real production bootloaders  
- Share **educational code** with the community (low-level OS concepts)  
- Document the **translation of enterprise requirements** into technical design  

---

## 🏗️ Architecture Overview
- **Two-stage boot sequence**: Stage1 MBR (512B) → Stage2 protected mode framework  
- **Protected mode setup**: GDT/IDT initialization, interrupt remapping, exception handlers  
- **Feature-toggled build system**: Selective compilation of subsystems (`EXC`, `PIC`, `INTEGRITY`, `SCHED`)  
- **Preemptive multitasking demo**: Hardware timer (IRQ0) driving a round-robin scheduler  

---

## 🔑 Feature Matrix (Production vs Demo)

| Feature              | Production (Enterprise)                          | Demo (Open Source)                     |
|----------------------|--------------------------------------------------|----------------------------------------|
| **Secure Boot**      | TPM attestation, encrypted signatures, trust chain | Checksum validation (SGDT/SIDT)         |
| **Interrupts**       | Priority-based routing, deterministic latency    | PIC remap + timer IRQ, basic ISR        |
| **Scheduling**       | Priority, RT guarantees, IPC                     | Round-robin, 3 tasks (A/B/Idle)         |
| **Exception Handling** | Fault isolation, encrypted crash reports        | Simple vector table + hex dump          |
| **Portability**      | Multi-platform x86 embedded                      | Flat model / runtime-patched GDT        |

---

## 📂 Project Structure
```
├── bootloader_stage1.asm   # Stage1: MBR (16-bit real mode)
├── bootloader_stage2.asm   # Stage2: Protected mode + features
├── build_bootloader.sh     # Build script with feature flags
├── build_symbols.sh        # Debug symbol generation
├── load_symbols.gdb        # GDB loader for QEMU debugging
└── README.md               # This document
```

---

## ⚙️ Build & Run
```bash
# Method A: Runtime GDT patch (legacy platforms)
./build_bootloader.sh A

# Method B: Flat addressing (modern platforms)
./build_bootloader.sh B

# With features
./build_bootloader.sh A "EXC PIC INTEGRITY SCHED"
```

Run in QEMU:  
```bash
qemu-system-i386 -drive file=bootloader.img,format=raw
```

---

## 🖥️ Expected Output Highlights
- **Base**: "METHOD A/B + IDT" → "IDT SETUP" → "INT 0x30 TRIGGERED"  
- **PIC enabled**: `TICKS:XX` increments in real-time  
- **Integrity check**: Displays GDT/IDT checksums  
- **Scheduler enabled**: Task indicators cycle (`A → B → I`) with counters updating  

---

## 🧩 Technical Concepts Demonstrated
- Real → Protected mode transition  
- GDT/IDT setup and exception handling  
- PIC reprogramming and hardware interrupt handling  
- Preemptive scheduling via context switching  
- Boot-time integrity validation mechanisms  

---

## 🚀 Skills Demonstrated
- **System programming (x86 assembly)**: low-level bootloader + kernel mechanisms  
- **Interrupt and scheduling design**: hardware timer-driven context switching  
- **Security mindset**: integrity checking, trust chain concepts  
- **Production experience**: Translating enterprise security & real-time requirements into implementable architectures  

---

## 📌 Value
This repository demonstrates how **production-grade embedded bootloader concepts** can be distilled into an **open-source educational framework**, while still highlighting:  
- Engineering depth (secure boot, interrupts, scheduling)  
- Architecture clarity (modular feature toggles, dual addressing models)  
- Practical coding ability (working bootloader in <5KB)  

It bridges the gap between **commercial system design** and **teaching-oriented open source**, showcasing both engineering rigor and technical communication.  
# NanoBoot
