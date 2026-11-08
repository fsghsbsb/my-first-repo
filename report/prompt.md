# Lab 3 提示词与 spec 汇总

本文把 A、B 已有记录和 C 的整合验证过程整理成可复用提示词。A、B 部分依据各自提交的 prompt/报告归纳；C 部分是整合时使用的验收规格，不冒充原始聊天记录。

## A：Trap 汇编入口与上下文恢复

### Spec

- 前置条件：`SAVE_ALL` 已完成，`sp` 指向 36 个 `REGBYTES` 槽位组成的 `trapframe`。
- 保持 `SAVE_ALL`、Trap frame 布局和 `trap(struct trapframe *)` 接口不变。
- 恢复顺序：先写回 `sstatus/sepc`，再恢复通用寄存器，旧 `sp` 最后恢复。
- 如使用 `s1/s2` 作 CSR 临时寄存器，必须随后从原槽位恢复。
- `__alltraps` 按 psABI 将 `sp` 放入 `a0`，调用 `trap()`，再跳到 `__trapret`；返回路径最后执行 `sret`。
- `scause/stval` 供诊断，不在恢复路径写回。
- 验收：Trap 测试中的寄存器哨兵、断点返回和 EPC 位置正确。

### 最终 Prompt

```text
ROLE
你是熟悉 RISC-V64 S 态特权架构、Sv39、Trap 现场和 psABI 的内核汇编工程师。

TASK
只在 kern/trap/trapentry.S 完成 RESTORE_ALL，并补全 __alltraps 调用
trap(struct trapframe *) 的衔接。不得改 SAVE_ALL、trap.h 或 C 函数签名。

RELY
struct trapframe 有 36 个 8 字节槽位；通用寄存器槽位与 SAVE_ALL 的 STORE
顺序一致，status/epc/stval/scause 在槽 32–35。SAVE_ALL 结束时 sp 指向
trapframe。RISC-V psABI 的第一个参数通过 a0 传递，LOAD/STORE 在 RV64
展开为 ld/sd。测试会在 ebreak 前设置寄存器哨兵并在返回后检查。

SPEC
先从槽 32、33 恢复 sstatus、sepc；按保存槽位恢复 x1、x3–x31，跳过恒零
x0；若中转 CSR 使用 s1/s2，必须恢复它们的原值；槽 2 的旧 sp 是最后一次
内存 LOAD。__alltraps 执行 SAVE_ALL 后依次 mv a0, sp、call trap、
j __trapret；__trapret 执行 RESTORE_ALL 后 sret。不得写回 scause/stval。
```

### 迭代追问

1. 为什么旧 `sp` 必须最后恢复？请对照每条 LOAD 的基址说明。
2. 用 `s1/s2` 写 CSR 后，如何确保恢复到陷入前的值？
3. 为什么传给 `trap()` 的参数是当前 `sp`，而不是旧 `sp`？
4. 为什么 C 函数返回后应跳转 `__trapret`，而不是 `ret`？
5. 新旧 CSR 助记符 `sbadaddr/stval` 是否同一 CSR，如何兼容不同汇编器？

## B：C 层中断和异常

### Spec

- 只围绕已有 `trapframe`、`trap_dispatch()` 和项目头文件中的接口实现。
- 根据 `scause` 最高位区分中断/异常；对中断原因去掉最高位后分类。
- Supervisor timer 必须先重设下一时钟事件，再让 `ticks` 恰好递增一次；每 100 ticks 输出一次，累计 10 次后通过已有 SBI 接口关机。
- 非法指令和断点异常输出原始 EPC；若指令低两位是 `11`，EPC 加 4，否则加 2。
- 其他原因不得静默忽略，使用已有诊断输出。
- 不改测试脚本和 sentinel。

### 最终 Prompt

```text
ROLE
你是熟悉 RISC-V 特权架构、ucore Trap 流程和 C 内核开发的工程师。

TASK
在 kern/trap/trap.c 的指定位置实现 interrupt_handler() 和
exception_handler()，保持现有 trap_dispatch()、trap()、trapframe 和测试不变。

RELY
先核对 trap.c、trap.h、clock.h/c、intr.h、riscv.h、sbi.h、Makefile 和
tools/grade.sh。只使用源码中存在的 IRQ/CAUSE 宏、ticks、TICK_NUM、
clock_set_next_event()、print_trapframe() 和 sbi_shutdown()。

SPEC
Supervisor timer 到来时重设下一次事件、ticks 加一；每 TICK_NUM 次调用
print_ticks()；达到 SHUTDOWN_AFTER 后调用 sbi_shutdown()。断点和非法指令
要按 16/32 位指令长度推进 EPC，避免重复执行；未知中断/异常输出现场。
```

## C：代码整合与验收

### Spec

- 以 `lab3_new` 官方树为基线，不覆盖 A/B 原始文件夹。
- 合入 A 的 Trap 汇编和 B 的 C handler；补齐 Lab2 已完成的 `page_init()`、Best-Fit 和必要启动兼容修复，保留 Lab3 既有接口。
- 物理页管理需排除内核映像和页描述符数组占用的内存，并检查 DTB 范围及页对齐。
- 不改动 grade 测试逻辑、评分和 sentinel；只修复启动参数以使 QEMU/OpenSBI 实际运行内核。
- 验收包括 clean build、`make grade` 100/100、普通 `make qemu` 的初始化输出和 1000 ticks 后 SBI 关机。

### 可复用 Prompt

```text
ROLE
你是负责合并 RISC-V uCore 实验代码的工程师，熟悉 Sv39 启动、页管理、
Trap 入口、OpenSBI/QEMU 和 shell 测试脚本。

TASK
以官方 Lab3 工程为基线，合并 A 的 trapentry.S、B 的 trap.c 和已经完成的
Lab2 PMM/Best-Fit 依赖，解决运行启动问题，生成完整报告并验证后提交。

RELY
逐项核对官方骨架、A/B 成品、Lab2 已验证代码、DTB 内存范围、Makefile 和
grade.sh。先查明未启动发生在 OpenSBI 交接、分页切换还是内核初始化阶段。

SPEC
不修改 A/B 原始目录；不弱化或修改任何评分条件。页描述符数组和内核映像
必须保留，空闲范围按整页对齐。修复启动时保持现有虚拟地址布局。报告只写
可复现的事实。最终提供 clean build、100/100 grade 和普通启动/关机的证据。
```

## 提示词使用总结

- **ROLE** 约束架构和执行层次，减少生成 x86 或用户态实现的风险。
- **RELY** 只放核对过的项目事实，如槽位布局、函数签名、已有宏和测试断言。
- **SPEC** 写成能通过代码检查或测试观察的约束，而不是“实现正确”这种不可验收的描述。
- 对汇编恢复顺序、C 异常指令长度、启动页表恒等映射等高风险问题采用追问和实际测试，不把第一次生成当作最终答案。
