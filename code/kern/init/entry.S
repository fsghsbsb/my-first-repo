#include <mmu.h>
#include <memlayout.h>

    .section .text,"ax",%progbits
    .globl kern_entry
kern_entry:
    # a0: hartid
    # a1: dtb physical address
    # save hartid and dtb address
    # NOTE: lla (not la) is required here. These stores run BEFORE satp enables
    # virtual addressing, so the addresses must be PC-relative physical ones.
    # Under a PIC/default-PIE toolchain (e.g. riscv64-linux-gnu), `la` would go
    # through the GOT and yield a virtual address, causing a store fault.
    lla t0, boot_hartid
    sd a0, 0(t0)
    lla t0, boot_dtb
    sd a1, 0(t0)

    # t0 := 三级页表的虚拟地址
    lui     t0, %hi(boot_page_table_sv39)
    # t1 := 0xffffffff40000000 即虚实映射偏移量
    li      t1, 0xffffffffc0000000 - 0x80000000
    # t0 减去虚实映射偏移量 0xffffffff40000000，变为三级页表的物理地址
    sub     t0, t0, t1
    # t0 >>= 12，变为三级页表的物理页号
    srli    t0, t0, 12

    # t1 := 8 << 60，设置 satp 的 MODE 字段为 Sv39
    li      t1, 8 << 60
    # 将刚才计算出的预设三级页表物理页号附加到 satp 中
    or      t0, t0, t1
    # 将算出的 t0(即新的MODE|页表基址物理页号) 覆盖到 satp 中
    csrw    satp, t0
    # 使用 sfence.vma 指令刷新 TLB
    sfence.vma
    # 从此，我们给内核搭建出了一个完美的虚拟内存空间！
    #nop # 可能映射的位置有些bug。。插入一个nop
    
    # 我们在虚拟内存空间中：随意将 sp 设置为虚拟地址！
    lui sp, %hi(bootstacktop)

    # 我们在虚拟内存空间中：随意跳转到虚拟地址！
    # 跳转到 kern_init
    lui t0, %hi(kern_init)
    addi t0, t0, %lo(kern_init)
    jr t0

.section .data
    # .align 2^12
    .align PGSHIFT
    .global bootstack
bootstack:
    .space KSTACKSIZE
    .global bootstacktop
bootstacktop:

.section .data
    # 由于我们要把这个页表放到一个页里面，因此必须 12 位对齐
    .align PGSHIFT
    .global boot_page_table_sv39
# 分配 4KiB 内存给预设的三级页表
boot_page_table_sv39:
    # 本页表是 Sv39 根表，每项为 1GB 大页。
    # 物理地址 0x80000000 的 VPN[2] = 0x80000000>>30 = 2，故 index 0、1 为空
    .zero 8 * 2
    # index 2：恒等映射 0x80000000 -> 0x80000000 (1G)。
    # csrw satp 之后、跳转到高半虚拟地址之前，PC 仍是物理地址，必须靠这条
    # 恒等映射才能继续取指，否则会立刻 exec_page_fault。
    .quad (0x80000 << 10) | 0xcf # VRWXAD
    # index 3..510 为空
    .zero 8 * 508
    # index 511：高半虚拟映射 0xffffffffc0000000 -> 0x80000000 (1G)
    .quad (0x80000 << 10) | 0xcf # VRWXAD

    .global boot_hartid
boot_hartid:
    .quad 0
    .global boot_dtb
boot_dtb:
    .quad 0
