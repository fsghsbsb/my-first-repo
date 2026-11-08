#include <riscv.h>

    .macro SAVE_ALL

    csrw sscratch, sp

    addi sp, sp, -36 * REGBYTES
    # save x registers
    STORE x0, 0*REGBYTES(sp)
    STORE x1, 1*REGBYTES(sp)
    STORE x3, 3*REGBYTES(sp)
    STORE x4, 4*REGBYTES(sp)
    STORE x5, 5*REGBYTES(sp)
    STORE x6, 6*REGBYTES(sp)
    STORE x7, 7*REGBYTES(sp)
    STORE x8, 8*REGBYTES(sp)
    STORE x9, 9*REGBYTES(sp)
    STORE x10, 10*REGBYTES(sp)
    STORE x11, 11*REGBYTES(sp)
    STORE x12, 12*REGBYTES(sp)
    STORE x13, 13*REGBYTES(sp)
    STORE x14, 14*REGBYTES(sp)
    STORE x15, 15*REGBYTES(sp)
    STORE x16, 16*REGBYTES(sp)
    STORE x17, 17*REGBYTES(sp)
    STORE x18, 18*REGBYTES(sp)
    STORE x19, 19*REGBYTES(sp)
    STORE x20, 20*REGBYTES(sp)
    STORE x21, 21*REGBYTES(sp)
    STORE x22, 22*REGBYTES(sp)
    STORE x23, 23*REGBYTES(sp)
    STORE x24, 24*REGBYTES(sp)
    STORE x25, 25*REGBYTES(sp)
    STORE x26, 26*REGBYTES(sp)
    STORE x27, 27*REGBYTES(sp)
    STORE x28, 28*REGBYTES(sp)
    STORE x29, 29*REGBYTES(sp)
    STORE x30, 30*REGBYTES(sp)
    STORE x31, 31*REGBYTES(sp)

    # get sr, epc, badvaddr, cause
    # Set sscratch register to 0, so that if a recursive exception
    # occurs, the exception vector knows it came from the kernel
    csrrw s0, sscratch, x0
    csrr s1, sstatus
    csrr s2, sepc
    csrr s3, stval             # 旧称 sbadaddr，同一 CSR(0x143)，存放陷入相关辅助地址
    csrr s4, scause

    STORE s0, 2*REGBYTES(sp)
    STORE s1, 32*REGBYTES(sp)
    STORE s2, 33*REGBYTES(sp)
    STORE s3, 34*REGBYTES(sp)
    STORE s4, 35*REGBYTES(sp)
    .endm

    .macro RESTORE_ALL

    #lab3 function1 2312681
    # 第 1 步：先恢复两个特权 CSR。
    #   sret 指令依据 sepc 决定返回地址、依据 sstatus 的 SPP/SPIE 完成
    #   特权级切换与中断使能恢复，因此必须在 sret 之前写好。
    #   这里临时用 s1/s2 中转；它们随后会从通用寄存器槽位恢复真正值，
    #   不会污染被打断程序的上下文。
    LOAD s1, 32*REGBYTES(sp)       # tf->status  -> sstatus
    LOAD s2, 33*REGBYTES(sp)       # tf->epc     -> sepc
    csrw sstatus, s1
    csrw sepc, s2

    # 第 2 步：按 SAVE_ALL 的槽位（与 struct pushregs 一一对应）恢复通用寄存器。
    #   x0 恒为 0，无需恢复；x2(sp) 留到最后一步单独恢复。
    LOAD ra,  1*REGBYTES(sp)      # x1
    LOAD gp,  3*REGBYTES(sp)      # x3
    LOAD tp,  4*REGBYTES(sp)      # x4
    LOAD t0,  5*REGBYTES(sp)
    LOAD t1,  6*REGBYTES(sp)
    LOAD t2,  7*REGBYTES(sp)
    LOAD s0,  8*REGBYTES(sp)
    LOAD s1,  9*REGBYTES(sp)      # 覆盖上面的中转值，恢复真正的 s1
    LOAD a0, 10*REGBYTES(sp)
    LOAD a1, 11*REGBYTES(sp)
    LOAD a2, 12*REGBYTES(sp)
    LOAD a3, 13*REGBYTES(sp)
    LOAD a4, 14*REGBYTES(sp)
    LOAD a5, 15*REGBYTES(sp)
    LOAD a6, 16*REGBYTES(sp)
    LOAD a7, 17*REGBYTES(sp)
    LOAD s2, 18*REGBYTES(sp)      # 覆盖上面的中转值，恢复真正的 s2
    LOAD s3, 19*REGBYTES(sp)
    LOAD s4, 20*REGBYTES(sp)
    LOAD s5, 21*REGBYTES(sp)
    LOAD s6, 22*REGBYTES(sp)
    LOAD s7, 23*REGBYTES(sp)
    LOAD s8, 24*REGBYTES(sp)
    LOAD s9, 25*REGBYTES(sp)
    LOAD s10,26*REGBYTES(sp)
    LOAD s11,27*REGBYTES(sp)
    LOAD t3, 28*REGBYTES(sp)
    LOAD t4, 29*REGBYTES(sp)
    LOAD t5, 30*REGBYTES(sp)
    LOAD t6, 31*REGBYTES(sp)

    # 第 3 步：栈指针最后恢复。此前所有 LOAD 都以 sp 为基址指向 trapframe，
    # 一旦提前改写 sp，后续取值基址立即失效；旧栈指针保存在槽位 2。
    LOAD sp,  2*REGBYTES(sp)

    .endm

    .globl __alltraps
    .align(2)
__alltraps:
    SAVE_ALL

    #lab3 function1 2312681
    # sp should be the same as before "jal trap"
    # RISC-V 调用约定（psABI）：第一个整型参数通过 a0 传递；
    # 此时 sp 指向当前栈上 trapframe 的起始地址，把它作为
    # struct trapframe *tf 传给 C 语言统一处理函数 trap()。
    mv a0, sp
    call trap
    # trap() 返回后 sp 由调用约定复原，仍指向 trapframe；
    # 跳转 __trapret 执行 RESTORE_ALL + sret，禁止使用 ret。
    j __trapret

    .globl __trapret
__trapret:
    RESTORE_ALL
    # return from supervisor call
    sret
