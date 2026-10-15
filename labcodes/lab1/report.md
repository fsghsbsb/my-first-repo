# 操作系统实验报告

## 实验基本信息

| 项目 | 内容 |
|------|------|
| **实验名称** | Lab 1: [比麻雀更小的麻雀（最小可执行内核）] |
| **小组成员** | 2311958-王健烨、2313107-程晓耘、2312681-仇晨宇 |
| **完成日期** | 2026-10-13 |

### 小组分工


| 成员 | 负责的练习/模块 |
|------|----------------|
| 2311958-王健烨 | [练习1、练习2] |
| 2312681-仇晨宇 | [实验报告2、3] |
| 2313107-程晓耘 | [实验报告5、6] |

---

## 一、实验目的

<!-- 说明本次实验的主要目标和预期成果 -->

本实验的主要目的是：

1. [练习1：理解内核启动中的程序入口操作]
2. [练习2：使用GDB验证启动流程]
3. [目的3：理解本章整体逻辑线]
4. [目的4：理解每个功能的核心函数或者功能模块]
5. [目的5：学习使用 AI 辅助开发操作系统核心功能]

---

## 二、实验环境

你们使用的 AI 工具

| 成员 | AI 编程工具 | 底层模型 | 备注 |
|------|------------|---------|------|
| 2311958-王健烨 | [Claude Code（终端 Agent）] | [DeepSeek-V4-Flash] |
| 2312681-仇晨宇 | [Claude Code（终端 Agent）] | [DeepSeek-V4-Flash] |
| 2313107-程晓耘 | copilot | auto | |

**说明：**
- **AI 编程工具**：指具体使用的终端工具、编辑器插件、桌面应用或浏览器界面
- **底层模型**：指该工具使用的大语言模型及版本

---

## 三、实验内容与实现

<!-- 
说明：本部分按照 exercises 文档中的练习顺序组织
每个功能模块或者练习中可能包含多项任务，请根据实际情况调整
-->
---

### 一、练习1：[理解内核启动中的程序入口操作]

**负责人：** [2311958-王健烨]

la sp, bootstacktop 把内核栈指针寄存器 sp 设置为内核栈栈顶的地址 bootstacktop：la（load address）是一条取地址伪指令，会展开成 PC 相对寻址的若干条指令，把这个符号在运行时所在的地址装入 sp；而 bootstacktop 是汇编中为内核栈预留的那块连续空间的最高地址，由于 RISC-V 的栈是向低地址方向增长的，栈指针必须指向栈顶而非栈底，这样压栈时才有正确的一段空间可用。它的目的是在进入 C 代码之前为内核建立起自己的栈——C 函数调用需要栈来保存返回地址、被调用者保存的寄存器以及局部变量，而当 bootloader/OpenSBI 跳转到内核入口时，sp 中的值对内核而言是无效的，如果不重新设置，之后任何一次函数调用都会把现场写入随机地址，轻则程序跑飞，重则破坏内核自身的代码和数据。

tail kern_init 把控制权无条件转移到 C 语言入口函数 kern_init：tail 是尾跳转伪指令，它只做跳转，不会像函数调用指令（call/jal）那样把返回地址写入 ra 寄存器，也不在栈上建立新的调用帧。它的目的是完成从汇编代码到 C 代码的交接，让内核进入 C 语言世界去执行真正的初始化工作（清空 bss、打印提示信息等）；之所以用跳转而不是调用，是因为 kern_init 被声明为不会返回（它以死循环结束），根本不存在需要保存的返回地址，用跳转可以避免压入一个毫无意义的返回帧、使入口处的栈保持 ABI 要求的对齐状态；反之若用调用指令，一旦该函数真的返回，就会跳回入口代码之后已无可执行指令的位置而导致内核跑飞。

### 二、练习2: [2311958-王健烨]

**负责人：** [2311958-王健烨]

#### 1. 调试过程

（1）以调试方式启动 QEMU：用 `-S` 让 CPU 在复位后立即暂停，用 `-s` 在 1234 端口打开 GDB 调试服务；另开一个终端运行 riscv64-unknown-elf-gdb，依次执行 `file bin/kernel`、`set arch riscv:rv64`、`target remote localhost:1234` 与 QEMU 建立连接。复现命令如下：

```bash
# 终端 1：启动 QEMU（-S 表示复位后暂停等待调试器，-s 在 1234 端口开启 GDB 服务）
qemu-system-riscv64 -machine virt -nographic -bios default -kernel bin/kernel -s -S

# 终端 2：启动调试器并连接
riscv64-unknown-elf-gdb -ex 'file bin/kernel' -ex 'set arch riscv:rv64' -ex 'target remote localhost:1234'
```

（2）观察复位瞬间的状态：连接后立即用 `p/x $pc` 查看 PC，得到 0x1000，说明加电复位的入口就在 0x1000；此时通用寄存器 a0/a1/a2/t0/sp 全为 0，CPU 手中没有任何可用的运行环境。

（3）单步跟踪复位向量：用 `x/6i 0x1000` 反汇编，看到复位向量共 6 条指令，再用 `si` 逐条单步，记录每条指令执行后寄存器的变化。

![GDB 实录：加电复位现场与复位向量反汇编](data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSI0NTciIGhlaWdodD0iNDY5IiB2aWV3Qm94PSIwIDAgNDU3IDQ2OSIgZm9udC1mYW1pbHk9IkRlamFWdSBTYW5zIE1vbm8sIE1lbmxvLCBDb25zb2xhcywgbW9ub3NwYWNlIj4KPHJlY3QgeD0iMC41IiB5PSIwLjUiIHdpZHRoPSI0NTYiIGhlaWdodD0iNDY4IiByeD0iOCIgZmlsbD0iIzFlMWUyZSIgc3Ryb2tlPSIjMzEzMjQ0Ii8+CjxwYXRoIGQ9Ik0wLjUgOC41IEE4IDggMCAwIDEgOC41IDAuNSBMNDQ4LjUgMC41IEE4IDggMCAwIDEgNDU2LjUgOC41IEw0NTYuNSAzNCBMMC41IDM0IFoiIGZpbGw9IiMxODE4MjUiLz4KPGNpcmNsZSBjeD0iMTgiIGN5PSIxNy4wIiByPSI1LjUiIGZpbGw9IiNmMzhiYTgiLz4KPGNpcmNsZSBjeD0iMzYiIGN5PSIxNy4wIiByPSI1LjUiIGZpbGw9IiNmOWUyYWYiLz4KPGNpcmNsZSBjeD0iNTQiIGN5PSIxNy4wIiByPSI1LjUiIGZpbGw9IiNhNmUzYTEiLz4KPHRleHQgeD0iMjI4IiB5PSIyMi4wIiBmb250LXNpemU9IjEzIiBmaWxsPSIjNmM3MDg2IiB0ZXh0LWFuY2hvcj0ibWlkZGxlIj5HREI6IOWKoOeUteWkjeS9jeeOsOWcuuS4juWkjeS9jeWQkemHj+WPjeaxh+e8ljwvdGV4dD4KPHRleHQgeD0iMTgiIHk9IjY0IiBmb250LXNpemU9IjE0IiB4bWw6c3BhY2U9InByZXNlcnZlIiBmaWxsPSIjYTZlM2ExIj4oZ2RiKSBwL3ggJHBjPC90ZXh0Pgo8dGV4dCB4PSIxOCIgeT0iODUiIGZvbnQtc2l6ZT0iMTQiIHhtbDpzcGFjZT0icHJlc2VydmUiIGZpbGw9IiNjZGQ2ZjQiPiQxID0gMHgxMDAwPC90ZXh0Pgo8dGV4dCB4PSIxOCIgeT0iMTA2IiBmb250LXNpemU9IjE0IiB4bWw6c3BhY2U9InByZXNlcnZlIiBmaWxsPSIjYTZlM2ExIj4oZ2RiKSBpbmZvIHJlZ2lzdGVycyBhMCBhMSBhMiB0MCBzcDwvdGV4dD4KPHRleHQgeD0iMTgiIHk9IjEyNyIgZm9udC1zaXplPSIxNCIgeG1sOnNwYWNlPSJwcmVzZXJ2ZSIgZmlsbD0iI2NkZDZmNCI+YTAgICAgICAgICAgICAgMHgwICAgICAgMDwvdGV4dD4KPHRleHQgeD0iMTgiIHk9IjE0OCIgZm9udC1zaXplPSIxNCIgeG1sOnNwYWNlPSJwcmVzZXJ2ZSIgZmlsbD0iI2NkZDZmNCI+YTEgICAgICAgICAgICAgMHgwICAgICAgMDwvdGV4dD4KPHRleHQgeD0iMTgiIHk9IjE2OSIgZm9udC1zaXplPSIxNCIgeG1sOnNwYWNlPSJwcmVzZXJ2ZSIgZmlsbD0iI2NkZDZmNCI+YTIgICAgICAgICAgICAgMHgwICAgICAgMDwvdGV4dD4KPHRleHQgeD0iMTgiIHk9IjE5MCIgZm9udC1zaXplPSIxNCIgeG1sOnNwYWNlPSJwcmVzZXJ2ZSIgZmlsbD0iI2NkZDZmNCI+dDAgICAgICAgICAgICAgMHgwICAgICAgMDwvdGV4dD4KPHRleHQgeD0iMTgiIHk9IjIxMSIgZm9udC1zaXplPSIxNCIgeG1sOnNwYWNlPSJwcmVzZXJ2ZSIgZmlsbD0iI2NkZDZmNCI+c3AgICAgICAgICAgICAgMHgwICAgICAgMHgwPC90ZXh0Pgo8dGV4dCB4PSIxOCIgeT0iMjMyIiBmb250LXNpemU9IjE0IiB4bWw6c3BhY2U9InByZXNlcnZlIiBmaWxsPSIjYTZlM2ExIj4oZ2RiKSB4LzZpIDB4MTAwMDwvdGV4dD4KPHRleHQgeD0iMTgiIHk9IjI1MyIgZm9udC1zaXplPSIxNCIgeG1sOnNwYWNlPSJwcmVzZXJ2ZSIgZmlsbD0iI2Y5ZTJhZiI+PSZndDsgMHgxMDAwOiAgICAgIGF1aXBjICAgdDAsMHgwPC90ZXh0Pgo8dGV4dCB4PSIxOCIgeT0iMjc0IiBmb250LXNpemU9IjE0IiB4bWw6c3BhY2U9InByZXNlcnZlIiBmaWxsPSIjY2RkNmY0Ij4gICAweDEwMDQ6ICAgICAgYWRkaSAgICBhMix0MCw0MDwvdGV4dD4KPHRleHQgeD0iMTgiIHk9IjI5NSIgZm9udC1zaXplPSIxNCIgeG1sOnNwYWNlPSJwcmVzZXJ2ZSIgZmlsbD0iI2NkZDZmNCI+ICAgMHgxMDA4OiAgICAgIGNzcnIgICAgYTAsbWhhcnRpZDwvdGV4dD4KPHRleHQgeD0iMTgiIHk9IjMxNiIgZm9udC1zaXplPSIxNCIgeG1sOnNwYWNlPSJwcmVzZXJ2ZSIgZmlsbD0iI2NkZDZmNCI+ICAgMHgxMDBjOiAgICAgIGxkICAgICAgYTEsMzIodDApPC90ZXh0Pgo8dGV4dCB4PSIxOCIgeT0iMzM3IiBmb250LXNpemU9IjE0IiB4bWw6c3BhY2U9InByZXNlcnZlIiBmaWxsPSIjY2RkNmY0Ij4gICAweDEwMTA6ICAgICAgbGQgICAgICB0MCwyNCh0MCk8L3RleHQ+Cjx0ZXh0IHg9IjE4IiB5PSIzNTgiIGZvbnQtc2l6ZT0iMTQiIHhtbDpzcGFjZT0icHJlc2VydmUiIGZpbGw9IiNjZGQ2ZjQiPiAgIDB4MTAxNDogICAgICBqciAgICAgIHQwPC90ZXh0Pgo8dGV4dCB4PSIxOCIgeT0iMzc5IiBmb250LXNpemU9IjE0IiB4bWw6c3BhY2U9InByZXNlcnZlIiBmaWxsPSIjYTZlM2ExIj4oZ2RiKSB4LzZneCAweDEwMTg8L3RleHQ+Cjx0ZXh0IHg9IjE4IiB5PSI0MDAiIGZvbnQtc2l6ZT0iMTQiIHhtbDpzcGFjZT0icHJlc2VydmUiIGZpbGw9IiNjZGQ2ZjQiPjB4MTAxODogMHgwMDAwMDAwMDgwMDAwMDAwICAgICAgMHgwMDAwMDAwMDg3MDAwMDAwPC90ZXh0Pgo8dGV4dCB4PSIxOCIgeT0iNDIxIiBmb250LXNpemU9IjE0IiB4bWw6c3BhY2U9InByZXNlcnZlIiBmaWxsPSIjY2RkNmY0Ij4weDEwMjg6IDB4MDAwMDAwMDA0OTQyNTM0ZiAgICAgIDB4MDAwMDAwMDAwMDAwMDAwMjwvdGV4dD4KPHRleHQgeD0iMTgiIHk9IjQ0MiIgZm9udC1zaXplPSIxNCIgeG1sOnNwYWNlPSJwcmVzZXJ2ZSIgZmlsbD0iI2NkZDZmNCI+MHgxMDM4OiAweDAwMDAwMDAwODAyMDAwMDAgICAgICAweDAwMDAwMDAwMDAwMDAwMDE8L3RleHQ+Cjwvc3ZnPgo=)

*图 1　GDB 实录：加电复位瞬间的 PC 与通用寄存器（上半部分），0x1000 处复位向量的反汇编与 ROM 中 0x1018 起的固件描述数据（下半部分）*

逐条单步的执行结果如表 1 所示。

**表 1　复位向量逐条单步执行结果**

| 步 | 执行的指令 | 执行后 PC | 关键寄存器变化 |
|---|---|---|---|
| 1 | auipc t0,0x0 | 0x1004 | t0 = 0x1000（当前地址） |
| 2 | addi a2,t0,40 | 0x1008 | a2 = 0x1028（指向固件描述结构） |
| 3 | csrr a0,mhartid | 0x100c | a0 = 0（hart 编号） |
| 4 | ld a1,32(t0) | 0x1010 | a1 = 0x87000000（设备树地址） |
| 5 | ld t0,24(t0) | 0x1014 | t0 = 0x80000000（OpenSBI 基址） |
| 6 | jr t0 | 0x80000000 | 控制权交给 OpenSBI |


（4）观察内核加载瞬间：按提示执行 `watch *(unsigned int *)0x80200000` 设置观察点。GDB 提示这是一个硬件观察点（Hardware watchpoint），即由 QEMU 真正监视对该地址的写操作。继续运行后，该观察点在整个启动过程中始终没有触发；而在加电瞬间、任何一条指令尚未执行时，查看 0x80200000 处的内容就已经是内核的第一条指令（与 entry.S 的编译结果一致）。这说明在 QEMU 中内核映像是在机器初始化阶段就被 QEMU 直接放入物理内存的，并不是由 OpenSBI 在运行过程中搬进去的，OpenSBI 只负责初始化并跳转过去。QEMU 的启动日志也印证了这一点：OpenSBI 打印的 `Domain0 Next Address : 0x80200000`、`Domain0 Next Mode : S-mode` 正来自下文所述 ROM 中的描述结构。

（5）在 0x80200000 下断点 `b *0x80200000` 后 `continue`，程序准确地停在 kern_entry 的第一条指令处，PC = 0x80200000，验证了控制权从 OpenSBI 移交内核的瞬间。此时 a0 = 0（boot hart 编号），a1 = 0x87000000（设备树 DTB 地址），而 sp = 0x8003def0、ra = 0x8000966a 都是 OpenSBI 遗留的值——这恰好说明内核入口必须自己重设栈指针。

![GDB 实录：观察点与断点命中内核入口](data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSI2OTMiIGhlaWdodD0iNDI3IiB2aWV3Qm94PSIwIDAgNjkzIDQyNyIgZm9udC1mYW1pbHk9IkRlamFWdSBTYW5zIE1vbm8sIE1lbmxvLCBDb25zb2xhcywgbW9ub3NwYWNlIj4KPHJlY3QgeD0iMC41IiB5PSIwLjUiIHdpZHRoPSI2OTIiIGhlaWdodD0iNDI2IiByeD0iOCIgZmlsbD0iIzFlMWUyZSIgc3Ryb2tlPSIjMzEzMjQ0Ii8+CjxwYXRoIGQ9Ik0wLjUgOC41IEE4IDggMCAwIDEgOC41IDAuNSBMNjg0LjMgMC41IEE4IDggMCAwIDEgNjkyLjMgOC41IEw2OTIuMyAzNCBMMC41IDM0IFoiIGZpbGw9IiMxODE4MjUiLz4KPGNpcmNsZSBjeD0iMTgiIGN5PSIxNy4wIiByPSI1LjUiIGZpbGw9IiNmMzhiYTgiLz4KPGNpcmNsZSBjeD0iMzYiIGN5PSIxNy4wIiByPSI1LjUiIGZpbGw9IiNmOWUyYWYiLz4KPGNpcmNsZSBjeD0iNTQiIGN5PSIxNy4wIiByPSI1LjUiIGZpbGw9IiNhNmUzYTEiLz4KPHRleHQgeD0iMzQ2IiB5PSIyMi4wIiBmb250LXNpemU9IjEzIiBmaWxsPSIjNmM3MDg2IiB0ZXh0LWFuY2hvcj0ibWlkZGxlIj5HREI6IOaWreeCueWRveS4reWGheaguOWFpeWPoyAweDgwMjAwMDAwPC90ZXh0Pgo8dGV4dCB4PSIxOCIgeT0iNjQiIGZvbnQtc2l6ZT0iMTQiIHhtbDpzcGFjZT0icHJlc2VydmUiIGZpbGw9IiNhNmUzYTEiPihnZGIpIHdhdGNoICoodW5zaWduZWQgaW50ICopMHg4MDIwMDAwMDwvdGV4dD4KPHRleHQgeD0iMTgiIHk9Ijg1IiBmb250LXNpemU9IjE0IiB4bWw6c3BhY2U9InByZXNlcnZlIiBmaWxsPSIjY2RkNmY0Ij5IYXJkd2FyZSB3YXRjaHBvaW50IDE6ICoodW5zaWduZWQgaW50ICopMHg4MDIwMDAwMDwvdGV4dD4KPHRleHQgeD0iMTgiIHk9IjEwNiIgZm9udC1zaXplPSIxNCIgeG1sOnNwYWNlPSJwcmVzZXJ2ZSIgZmlsbD0iI2E2ZTNhMSI+KGdkYikgYnJlYWsgKjB4ODAyMDAwMDA8L3RleHQ+Cjx0ZXh0IHg9IjE4IiB5PSIxMjciIGZvbnQtc2l6ZT0iMTQiIHhtbDpzcGFjZT0icHJlc2VydmUiIGZpbGw9IiNjZGQ2ZjQiPkJyZWFrcG9pbnQgMiBhdCAweDgwMjAwMDAwOiBmaWxlIGtlcm4vaW5pdC9lbnRyeS5TLCBsaW5lIDcuPC90ZXh0Pgo8dGV4dCB4PSIxOCIgeT0iMTQ4IiBmb250LXNpemU9IjE0IiB4bWw6c3BhY2U9InByZXNlcnZlIiBmaWxsPSIjYTZlM2ExIj4oZ2RiKSBjb250aW51ZTwvdGV4dD4KPHRleHQgeD0iMTgiIHk9IjE2OSIgZm9udC1zaXplPSIxNCIgeG1sOnNwYWNlPSJwcmVzZXJ2ZSIgZmlsbD0iI2NkZDZmNCI+QnJlYWtwb2ludCAyLCBrZXJuX2VudHJ5ICgpIGF0IGtlcm4vaW5pdC9lbnRyeS5TOjc8L3RleHQ+Cjx0ZXh0IHg9IjE4IiB5PSIxOTAiIGZvbnQtc2l6ZT0iMTQiIHhtbDpzcGFjZT0icHJlc2VydmUiIGZpbGw9IiNjZGQ2ZjQiPjcgICAgICAgICAgIGxhIHNwLCBib290c3RhY2t0b3A8L3RleHQ+Cjx0ZXh0IHg9IjE4IiB5PSIyMTEiIGZvbnQtc2l6ZT0iMTQiIHhtbDpzcGFjZT0icHJlc2VydmUiIGZpbGw9IiNhNmUzYTEiPihnZGIpIGluZm8gcmVnaXN0ZXJzIGEwIGExIHNwIHJhPC90ZXh0Pgo8dGV4dCB4PSIxOCIgeT0iMjMyIiBmb250LXNpemU9IjE0IiB4bWw6c3BhY2U9InByZXNlcnZlIiBmaWxsPSIjY2RkNmY0Ij5hMCAgICAgICAgICAgICAweDAgICAgICAwPC90ZXh0Pgo8dGV4dCB4PSIxOCIgeT0iMjUzIiBmb250LXNpemU9IjE0IiB4bWw6c3BhY2U9InByZXNlcnZlIiBmaWxsPSIjY2RkNmY0Ij5hMSAgICAgICAgICAgICAweDg3MDAwMDAwICAgICAgIDIyNjQ5MjQxNjA8L3RleHQ+Cjx0ZXh0IHg9IjE4IiB5PSIyNzQiIGZvbnQtc2l6ZT0iMTQiIHhtbDpzcGFjZT0icHJlc2VydmUiIGZpbGw9IiNjZGQ2ZjQiPnNwICAgICAgICAgICAgIDB4ODAwM2RlZjAgICAgICAgMHg4MDAzZGVmMDwvdGV4dD4KPHRleHQgeD0iMTgiIHk9IjI5NSIgZm9udC1zaXplPSIxNCIgeG1sOnNwYWNlPSJwcmVzZXJ2ZSIgZmlsbD0iI2NkZDZmNCI+cmEgICAgICAgICAgICAgMHg4MDAwOTY2YSAgICAgICAweDgwMDA5NjZhPC90ZXh0Pgo8dGV4dCB4PSIxOCIgeT0iMzE2IiBmb250LXNpemU9IjE0IiB4bWw6c3BhY2U9InByZXNlcnZlIiBmaWxsPSIjYTZlM2ExIj4oZ2RiKSBpbmZvIGJyZWFrcG9pbnRzPC90ZXh0Pgo8dGV4dCB4PSIxOCIgeT0iMzM3IiBmb250LXNpemU9IjE0IiB4bWw6c3BhY2U9InByZXNlcnZlIiBmaWxsPSIjY2RkNmY0Ij5OdW0gICAgIFR5cGUgICAgICAgICAgIERpc3AgRW5iIEFkZHJlc3MgICAgICAgICAgICBXaGF0PC90ZXh0Pgo8dGV4dCB4PSIxOCIgeT0iMzU4IiBmb250LXNpemU9IjE0IiB4bWw6c3BhY2U9InByZXNlcnZlIiBmaWxsPSIjY2RkNmY0Ij4xICAgICAgIGh3IHdhdGNocG9pbnQgIGtlZXAgeSAgICAgICAgICAgICAgICAgICAgICAqKHVuc2lnbmVkIGludCAqKTB4ODAyMDAwMDA8L3RleHQ+Cjx0ZXh0IHg9IjE4IiB5PSIzNzkiIGZvbnQtc2l6ZT0iMTQiIHhtbDpzcGFjZT0icHJlc2VydmUiIGZpbGw9IiNjZGQ2ZjQiPjIgICAgICAgYnJlYWtwb2ludCAgICAga2VlcCB5ICAgMHgwMDAwMDAwMDgwMjAwMDAwIGtlcm4vaW5pdC9lbnRyeS5TOjc8L3RleHQ+Cjx0ZXh0IHg9IjE4IiB5PSI0MDAiIGZvbnQtc2l6ZT0iMTQiIHhtbDpzcGFjZT0icHJlc2VydmUiIGZpbGw9IiNjZGQ2ZjQiPiAgICAgICAgYnJlYWtwb2ludCBhbHJlYWR5IGhpdCAxIHRpbWU8L3RleHQ+Cjwvc3ZnPgo=)

*图 2　GDB 实录：硬件观察点全程未触发，而 0x80200000 处的断点准确命中，证明内核映像在执行任何指令之前就已经位于物理内存中*

#### 2. 观察结果

复位时 PC = 0x1000，6 条指令的执行效果依次是：`auipc t0,0x0` 把当前地址 0x1000 取入 t0；`addi a2,t0,40` 令 a2 = 0x1028，指向 ROM 中一段描述固件装载信息的结构；`csrr a0,mhartid` 把当前 hart 编号读入 a0；`ld a1,32(t0)` 从 0x1020 处取出 0x87000000 装入 a1；`ld t0,24(t0)` 从 0x1018 处取出 0x80000000 装入 t0；`jr t0` 跳转到 0x80000000，控制权交给 OpenSBI。查看 0x1028 起的内存可以读到该结构的内容：magic 为 0x4942534f（即字符串 "OSBI"）、版本号 2、next_addr = 0x80200000、next_mode = 1（S 模式），也就是说"最终交给内核的地址和特权级"在复位向量还没有执行时就已经约定好了。此后 OpenSBI v1.0 完成主初始化并打印平台信息，跳到 0x80200000，内核随即打印 "(THU.CST) os is loading ..."。

![QEMU 串口日志：OpenSBI 启动与内核打印](data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSI0OTEiIGhlaWdodD0iMzY0IiB2aWV3Qm94PSIwIDAgNDkxIDM2NCIgZm9udC1mYW1pbHk9IkRlamFWdSBTYW5zIE1vbm8sIE1lbmxvLCBDb25zb2xhcywgbW9ub3NwYWNlIj4KPHJlY3QgeD0iMC41IiB5PSIwLjUiIHdpZHRoPSI0OTAiIGhlaWdodD0iMzYzIiByeD0iOCIgZmlsbD0iIzFlMWUyZSIgc3Ryb2tlPSIjMzEzMjQ0Ii8+CjxwYXRoIGQ9Ik0wLjUgOC41IEE4IDggMCAwIDEgOC41IDAuNSBMNDgyLjIgMC41IEE4IDggMCAwIDEgNDkwLjIgOC41IEw0OTAuMiAzNCBMMC41IDM0IFoiIGZpbGw9IiMxODE4MjUiLz4KPGNpcmNsZSBjeD0iMTgiIGN5PSIxNy4wIiByPSI1LjUiIGZpbGw9IiNmMzhiYTgiLz4KPGNpcmNsZSBjeD0iMzYiIGN5PSIxNy4wIiByPSI1LjUiIGZpbGw9IiNmOWUyYWYiLz4KPGNpcmNsZSBjeD0iNTQiIGN5PSIxNy4wIiByPSI1LjUiIGZpbGw9IiNhNmUzYTEiLz4KPHRleHQgeD0iMjQ1IiB5PSIyMi4wIiBmb250LXNpemU9IjEzIiBmaWxsPSIjNmM3MDg2IiB0ZXh0LWFuY2hvcj0ibWlkZGxlIj5RRU1VIOS4suWPo+aXpeW/lzogT3BlblNCSSDlkK/liqjkuI7lhoXmoLjmiZPljbA8L3RleHQ+Cjx0ZXh0IHg9IjE4IiB5PSI2NCIgZm9udC1zaXplPSIxNCIgeG1sOnNwYWNlPSJwcmVzZXJ2ZSIgZmlsbD0iI2NkZDZmNCI+T3BlblNCSSB2MS4wPC90ZXh0Pgo8dGV4dCB4PSIxOCIgeT0iODUiIGZvbnQtc2l6ZT0iMTQiIHhtbDpzcGFjZT0icHJlc2VydmUiIGZpbGw9IiNjZGQ2ZjQiPlBsYXRmb3JtIE5hbWUgICAgICAgICAgICAgOiByaXNjdi12aXJ0aW8scWVtdTwvdGV4dD4KPHRleHQgeD0iMTgiIHk9IjEwNiIgZm9udC1zaXplPSIxNCIgeG1sOnNwYWNlPSJwcmVzZXJ2ZSIgZmlsbD0iI2NkZDZmNCI+UGxhdGZvcm0gSEFSVCBDb3VudCAgICAgICA6IDE8L3RleHQ+Cjx0ZXh0IHg9IjE4IiB5PSIxMjciIGZvbnQtc2l6ZT0iMTQiIHhtbDpzcGFjZT0icHJlc2VydmUiIGZpbGw9IiNjZGQ2ZjQiPlBsYXRmb3JtIFRpbWVyIERldmljZSAgICAgOiBhY2xpbnQtbXRpbWVyIEAgMTAwMDAwMDBIejwvdGV4dD4KPHRleHQgeD0iMTgiIHk9IjE0OCIgZm9udC1zaXplPSIxNCIgeG1sOnNwYWNlPSJwcmVzZXJ2ZSIgZmlsbD0iI2NkZDZmNCI+UGxhdGZvcm0gQ29uc29sZSBEZXZpY2UgICA6IHVhcnQ4MjUwPC90ZXh0Pgo8dGV4dCB4PSIxOCIgeT0iMTY5IiBmb250LXNpemU9IjE0IiB4bWw6c3BhY2U9InByZXNlcnZlIiBmaWxsPSIjY2RkNmY0Ij5GaXJtd2FyZSBCYXNlICAgICAgICAgICAgIDogMHg4MDAwMDAwMDwvdGV4dD4KPHRleHQgeD0iMTgiIHk9IjE5MCIgZm9udC1zaXplPSIxNCIgeG1sOnNwYWNlPSJwcmVzZXJ2ZSIgZmlsbD0iI2NkZDZmNCI+RmlybXdhcmUgU2l6ZSAgICAgICAgICAgICA6IDI1MiBLQjwvdGV4dD4KPHRleHQgeD0iMTgiIHk9IjIxMSIgZm9udC1zaXplPSIxNCIgeG1sOnNwYWNlPSJwcmVzZXJ2ZSIgZmlsbD0iI2NkZDZmNCI+RG9tYWluMCBCb290IEhBUlQgICAgICAgICA6IDA8L3RleHQ+Cjx0ZXh0IHg9IjE4IiB5PSIyMzIiIGZvbnQtc2l6ZT0iMTQiIHhtbDpzcGFjZT0icHJlc2VydmUiIGZpbGw9IiNjZGQ2ZjQiPkRvbWFpbjAgTmV4dCBBZGRyZXNzICAgICAgOiAweDAwMDAwMDAwODAyMDAwMDA8L3RleHQ+Cjx0ZXh0IHg9IjE4IiB5PSIyNTMiIGZvbnQtc2l6ZT0iMTQiIHhtbDpzcGFjZT0icHJlc2VydmUiIGZpbGw9IiNjZGQ2ZjQiPkRvbWFpbjAgTmV4dCBBcmcxICAgICAgICAgOiAweDAwMDAwMDAwODcwMDAwMDA8L3RleHQ+Cjx0ZXh0IHg9IjE4IiB5PSIyNzQiIGZvbnQtc2l6ZT0iMTQiIHhtbDpzcGFjZT0icHJlc2VydmUiIGZpbGw9IiNjZGQ2ZjQiPkRvbWFpbjAgTmV4dCBNb2RlICAgICAgICAgOiBTLW1vZGU8L3RleHQ+Cjx0ZXh0IHg9IjE4IiB5PSIyOTUiIGZvbnQtc2l6ZT0iMTQiIHhtbDpzcGFjZT0icHJlc2VydmUiIGZpbGw9IiNjZGQ2ZjQiPkJvb3QgSEFSVCBJRCAgICAgICAgICAgICAgOiAwPC90ZXh0Pgo8dGV4dCB4PSIxOCIgeT0iMzE2IiBmb250LXNpemU9IjE0IiB4bWw6c3BhY2U9InByZXNlcnZlIiBmaWxsPSIjY2RkNmY0Ij5Cb290IEhBUlQgSVNBICAgICAgICAgICAgIDogcnY2NGltYWZkY3N1aDwvdGV4dD4KPHRleHQgeD0iMTgiIHk9IjMzNyIgZm9udC1zaXplPSIxNCIgeG1sOnNwYWNlPSJwcmVzZXJ2ZSIgZmlsbD0iI2NkZDZmNCI+KFRIVS5DU1QpIG9zIGlzIGxvYWRpbmcgLi4uPC90ZXh0Pgo8L3N2Zz4K)

*图 3　QEMU 串口日志节选：OpenSBI v1.0 的启动信息与内核的第一条打印输出，其中 `Domain0 Next Address : 0x80200000`、`Domain0 Next Mode : S-mode` 即固件最终移交控制权的地址与特权级*

#### 3. 问题回答

硬件加电后最初执行的几条指令位于地址 0x1000，它是 QEMU virt 平台预置的复位向量（掩码 ROM，属于机器的一部分，并非 OpenSBI 自身的代码），一共 6 条指令。它们本身并不做实质性的硬件初始化，功能可以概括为"备好参数、移交控制"：先用 PC 相对的取址方式得到当前地址，据此从 ROM 的固定单元里读出 OpenSBI 固件基址（0x80000000）和固件描述结构地址，同时把 hart 编号、设备树地址、描述结构指针分别放进 a0、a1、a2 作为调用约定要求的参数，最后跳转到 0x80000000，机器于是开始执行 OpenSBI 的代码。真正的最基础硬件初始化和后续准备工作是在 0x80000000 之后的固件代码中完成的（实测其开头即保存 a0/a1/a2 并调用初始化例程），最终由固件按描述结构中约定的 next_addr = 0x80200000、next_mode = S 模式把控制权交给内核。

### 三、说明自己对本章节整体逻辑线的理解，即本章节是按照什么顺序、围绕哪些功能逐步实现的。

**负责人：** [2312681-仇晨宇]

lab1 章节围绕一个核心目标展开：**构建一个最小可执行内核（“麻雀骨架”），它不依赖操作系统和任何标准库，能完成格式化输出，然后进入死循环**。整个章节沿着“一段代码要怎样才能在裸机上真正跑起来”这条主线，按照从硬件到软件、从底层到上层的顺序逐步实现，可以概括为六个环节：

1. **约定内核的运行位置（链接脚本）**：`tools/kernel.ld` 把内核入口设为 `kern_entry`、基址定为 `0x80200000`，并按 `.text → .rodata → .data → .bss` 的顺序规划内存布局，同时用 `etext / edata / end` 导出各段边界符号。这是后续一切工作的地址基础——内核被链接到什么地址，决定了它之后在内存里“住”在哪里。

2. **搞清楚控制权如何交到内核手里（硬件与固件）**：RISC-V 加电后 PC 从 `0x1000` 的复位向量开始执行 6 条指令，跳到 OpenSBI（`0x80000000`）；OpenSBI 完成最基本的硬件初始化后，按固件描述结构中约定的 `next_addr = 0x80200000`、S 模式把控制权交给内核。这一步回答了“内核入口之前发生了什么”。

3. **搭建内核的运行环境（汇编入口）**：`kern/init/entry.S` 的 `kern_entry` 先用 `la sp, bootstacktop` 建立内核栈（C 代码能运行的前提），再用 `tail kern_init` 不保存返回地址地跳进 C 世界。至此汇编阶段的任务完成，内核进入 C 语言阶段。

4. **C 世界的初始化（内核主体）**：`kern_init` 先清空 bss 段（ELF 中 bss 不占文件空间、但运行期必须为零），再打印启动消息，最后进入死循环。它展示了“内核初始化 = 准备好运行环境 + 做有意义的事 + 永不退出”的基本形态。

5. **自底向上搭建输出能力（从 SBI 到 stdio）**：这是本章唯一真正实现的功能模块。最底层是 RISC-V 的 `ecall` / SBI 通道（`libs/sbi.c`），向上封装出控制台设备层（`kern/driver/console.c`）、字符与格式化输出层（`kern/libs/stdio.c`、`libs/printfmt.c`），最终暴露给 `kern_init` 一个 `cprintf`。每一层只依赖下面一层，逐层屏蔽硬件细节。

6. **构建、运行与验证（工程闭环）**：`Makefile` 用 riscv64 交叉工具链完成编译、链接（`-T tools/kernel.ld`）、`objcopy` 转裸二进制 `bin/ucore.img`，再由 QEMU 的 `loader` 设备把它放到 `0x80200000`；`make qemu` 运行验证输出，练习 2 再用 GDB 跟踪从加电到内核第一条指令的完整过程，反过来验证了前几个环节的结论。

一句话总结逻辑线：**先用链接脚本定好“住址”，再让硬件/固件把控制权送进内核入口，入口建好栈后进入 C 世界，C 世界先清 bss 再做格式化输出，最后死循环驻留；全程由构建脚本和调试工具保证“能编译、能加载、能验证”。** 各环节环环相扣，上一环节的输出就是下一环节的输入。


### 四、说明自己对每个功能的核心函数或功能模块的理解。

**负责人：** [2312681-仇晨宇]

#### 1. 内核入口模块 `kern/init/entry.S`（`kern_entry`）

- **功能**：内核第一条指令所在地，负责从“固件刚把控制权交给内核”的瞬间过渡到 C 代码。
- **核心函数**：`kern_entry` 中的 `la sp, bootstacktop` 与 `tail kern_init`。
- **理解**：`bootstack` 通过 `.space KSTACKSIZE` 预留了 2 页（8KB）的栈空间，`bootstacktop` 是它的最高地址；RISC-V 的栈向低地址增长，`sp` 必须指向栈顶。内核必须自建栈，因为固件遗留的 `sp` 对内核无效。`tail` 用跳转而非调用，是因为 `kern_init` 被声明为不会返回（`__attribute__((noreturn))`），不存在需要保存的返回地址。

#### 2. 链接脚本 `tools/kernel.ld`

- **功能**：规定内核的链接地址与内存布局，是“内核放在 `0x80200000`”这一约定的落点。
- **核心内容**：`ENTRY(kern_entry)`、`BASE_ADDRESS = 0x80200000`、`.text / .rodata / .data / .sdata / .bss` 的段顺序、`PROVIDE(etext / edata / end)`。
- **理解**：段边界符号由链接器生成，供 `kern_init` 清 bss 时使用；bss 段在文件中不占空间，链接脚本只为其分配地址区间，这也解释了为什么必须在运行时用 `memset` 清零。

#### 3. 初始化模块 `kern/init/init.c`（`kern_init`）

- **功能**：内核的 C 语言入口，完成最基本的初始化并驻留。
- **核心函数**：`memset(edata, 0, end - edata)` 清零 bss；`cprintf` 打印启动消息；`while (1);` 死循环。
- **理解**：这是“最小内核”的完整形态——环境就绪（栈已建）→ 数据就绪（bss 清零）→ 功能演示（打印）→ 永不退出。死循环正是“内核没有任务时也不能把控制权交还”这一 OS 语义的雏形。

#### 4. SBI 封装层 `libs/sbi.c`（`sbi_call` / `sbi_console_putchar`）

- **功能**：内核与 M 模式固件 OpenSBI 之间的“系统调用”通道。
- **核心函数**：`sbi_call` 用内联汇编按 SBI 调用约定布置参数（a7 = 功能号、a0~a2 = 参数）后执行 `ecall`，返回值从 a0 取回；`sbi_console_putchar` 调用功能号 1（`SBI_CONSOLE_PUTCHAR`）。
- **理解**：内核运行在 S 模式，没有特权直接操作串口等硬件，一切特权操作都要通过 `ecall` 委托给 OpenSBI——这与用户态进程通过系统调用委托内核，是同一分层思想的体现。

#### 5. 控制台设备层 `kern/driver/console.c`（`cons_putc` / `cons_getc`）

- **功能**：向上提供统一的字符收发接口，屏蔽底层实现。
- **核心函数**：`cons_putc` 调 `sbi_console_putchar`；`cons_getc` 调 `sbi_console_getchar`；`cons_init` / `kbd_intr` / `serial_intr` 目前是空函数。
- **理解**：设备驱动“统一接口 + 具体实现”的分层——将来换用真实串口/键盘时，只需修改这一层，上层无需变动。

#### 6. 格式化输出引擎 `libs/printfmt.c`（`vprintfmt` / `printnum` / `snprintf`）

- **功能**：把“格式串 + 变参”转换成字符流，是整个 printf 家族的核心。
- **核心函数**：`vprintfmt` 用回调 `putch` 输出字符，支持 `%c / %d / %u / %o / %x / %p / %s / %e / %%`，并处理宽度、填充字符与 `l` 长度标志；`printnum` 递归逐位打印数字；`snprintf` / `vsnprintf` 通过 `sprintputch` 把字符写进内存缓冲区。
- **理解**：输出目标被抽象成“一个 `putch` 回调”，同一套格式化引擎既可以打印到控制台（`cputch`），也可以打印到内存缓冲区（`sprintputch`），体现了 printf 族“格式化与输出分离”的设计。

#### 7. 高层 I/O 接口 `kern/libs/stdio.c`（`cprintf` / `vcprintf` / `cputchar` / `getchar`）

- **功能**：内核最常用的打印/输入接口。
- **核心函数**：`cprintf` 变参 → `vcprintf` 包装 `va_list` → `vprintfmt(cputch)` 实际格式化输出；`getchar` 阻塞读取字符。
- **理解**：这是裸机版“标准库 stdio”——没有 libc，就自己实现一个最小子集，说明一个可执行内核连 `printf` 都要自给自足。

#### 8. 输入行读取 `libs/readline.c`（`readline`）

- **功能**：从标准输入读一整行到静态缓冲区，支持退格与回车结束，超长部分截断。
- **理解**：为后续 lab 的交互式命令行（如之后的 shell 交互）预留；当前 lab1 的 `kern_init` 并未调用它。

#### 9. 构建系统 `Makefile` + `tools/function.mk`

- **功能**：把分散的 `.c / .S` 源码编译、链接成内核镜像，并驱动 QEMU 运行。
- **核心内容**：交叉工具链 `riscv64-unknown-elf-*`；`CFLAGS` 中的 `-mcmodel=medany`（PC 相对寻址，代码可在 2GB 范围内任意链接）、`-nostdinc / -nostdlib`（裸机无标准库）、`-ffunction-sections / -fdata-sections` 配合链接时的 `--gc-sections` 裁剪未用代码；`kernel` 目标用 `ld -T tools/kernel.ld` 链接；`ucore.img` 目标用 `objcopy --strip-all -O binary` 转成裸二进制；`qemu` 目标用 `-device loader,file=bin/ucore.img,addr=0x80200000` 加载运行。
- **理解**：内核镜像的“加载地址”由链接脚本与 QEMU loader 双重约定，二者必须一致（都是 `0x80200000`），这是整个实验最容易被忽略、也最容易出错的工程细节。

**模块总览表：**

| 模块 | 所在文件 | 核心函数/内容 | 一句话职责 |
|---|---|---|---|
| 内核入口 | `kern/init/entry.S` | `kern_entry`：`la sp, bootstacktop`、`tail kern_init` | 建立内核栈，跳入 C 世界 |
| 内存布局 | `tools/kernel.ld` | `ENTRY`、`BASE_ADDRESS`、段顺序、`edata/end` | 规定内核链接地址与布局 |
| 初始化 | `kern/init/init.c` | `kern_init`：清 bss、`cprintf`、`while(1)` | 清数据段、打印、驻留 |
| SBI 封装 | `libs/sbi.c` | `sbi_call`（`ecall`）、`sbi_console_putchar` | 通过 ecall 委托固件服务 |
| 控制台设备 | `kern/driver/console.c` | `cons_putc` / `cons_getc` | 统一字符收发接口 |
| 格式化引擎 | `libs/printfmt.c` | `vprintfmt` / `printnum` / `snprintf` | 格式串 → 字符流 |
| 高层 I/O | `kern/libs/stdio.c` | `cprintf` / `vcprintf` / `getchar` | 内核常用的打印/输入接口 |
| 行输入 | `libs/readline.c` | `readline` | 读一行（后续实验使用） |
| 构建系统 | `Makefile` + `tools/function.mk` | 编译、链接、objcopy、qemu 目标 | 生成镜像并驱动 QEMU 运行 |


### 五、列出你认为本实验中重要的知识点，以及与对应 OS 原理中的知识点，并简要说明二者的含义、关系和差异。

**负责人：** [2313107-程晓耘]

| 本实验中的知识点 | 对应的 OS 原理知识点 | 含义、关系与差异 |
|---|---|---|
| 内核入口、启动栈与从汇编跳入 C 代码 | 操作系统引导与内核初始化 | 内核入口建立栈并转入初始化函数，体现了操作系统启动时先准备运行环境、再执行内核代码的过程。本实验只完成单核、最小化的入口交接；完整系统还要初始化中断、内存管理和设备等子系统。 |
| 链接脚本规定内核装载地址和各段布局 | 程序映像、地址空间与内存布局 | `.text`、`.data`、`.bss` 等段分别承载不同类型的程序内容，链接脚本确定它们在内存中的位置。本实验直接使用物理地址并由 QEMU 装载映像；一般操作系统还会管理多个进程的地址空间，并通过虚拟内存提供隔离和映射。 |
| 启动时清零 bss 段 | 进程/内核映像的装入与初始化 | bss 在可执行文件中通常不保存实际零字节，但运行时需要呈现为零值，因此启动代码必须初始化相应内存。本实验由内核入口阶段的初始化代码完成；通用系统还需在创建进程、分配内存时按规则初始化和保护内存。 |
| S 模式通过 `ecall` 请求 OpenSBI 服务 | 特权级、陷入机制与系统调用 | 低特权级代码不能直接执行所有特权操作，需要通过受控入口请求更高特权级软件代办。本实验使用 SBI 服务输出字符；它是内核向固件请求机器级服务，不等同于用户程序向操作系统内核发起的系统调用。 |
| `cons_putc`、`cprintf` 与格式化输出的分层 | I/O 子系统、设备驱动与接口抽象 | 下层负责字符输出，上层负责格式化并调用统一接口，分层后上层不必了解具体硬件操作。本实验最终通过 SBI 输出到 QEMU 串口；完整 OS 的设备驱动和 I/O 子系统还要处理设备状态、缓冲、并发和错误等问题。 |
| 使用交叉工具链、链接脚本和 QEMU 构建运行内核 | 操作系统构建、装载与运行环境 | 编译、链接和装载必须对内核地址等约定保持一致，调试则可验证控制流和寄存器状态。本实验用 QEMU 模拟目标机器并直接装载内核映像；真实机器还涉及固件、引导程序及硬件差异。 |

### 六、列出你认为 OS 原理中很重要、但在本实验中没有对应上的知识点。

**负责人：** 2313107-程晓耘

1. **进程与线程管理、CPU 调度**：本实验只有一个启动中的内核执行流，最后停留在死循环，没有创建进程或线程，也没有实现上下文切换、调度策略和进程间隔离。它们是多任务操作系统实现并发执行的基础。
2. **虚拟内存与内存管理**：实验使用固定的物理装载地址，没有建立页表，也没有实现虚拟地址到物理地址的转换、按需分配、页面置换或内存保护。实际操作系统需要用这些机制管理有限内存并隔离不同执行主体。
3. **中断与异常处理**：本实验观察了复位入口以及由 `ecall` 进入固件服务的路径，但没有建立内核自己的中断/异常入口和处理流程，也没有处理时钟中断、外部设备中断或异常恢复。中断机制是响应异步事件和支持抢占式调度的重要基础。
4. **同步与并发控制**：实验没有多个执行流共享数据，因此没有涉及锁、信号量、条件变量、原子操作或死锁。多核和并发环境中的共享资源需要通过同步机制保证正确性。
5. **系统调用与用户态隔离**：内核通过 SBI `ecall` 请求 OpenSBI 服务，但没有用户态程序，也没有实现用户程序进入内核的系统调用分发、参数检查和权限隔离。SBI 调用发生在内核与固件之间，不能直接视作完整 OS 的用户态系统调用。
6. **文件系统与进程级 I/O**：实验只通过控制台输出启动信息，没有文件、目录、缓存、存储设备管理或统一文件接口。文件系统负责组织和持久化数据，是实际操作系统的重要组成部分。

---

## 五、实验总结与收获


### 对操作系统的理解

通过本实验，我们对“内核如何从一段被装载的映像变成正在运行的软件”有了更完整的认识：链接脚本确定内核的入口和内存布局，QEMU 将映像放到约定地址，复位向量和 OpenSBI 完成启动交接，内核入口建立自己的栈并跳转到 C 初始化代码，随后清零 bss、通过 SBI 和分层输出接口打印信息，最终进入驻留循环。各环节之间有明确的地址、调用约定和接口约定，任一环节不一致都可能导致内核无法启动。

操作系统原理中的特权级和模块分层并非抽象概念。S 模式内核通过 `ecall` 请求 OpenSBI 服务，输出功能则由格式化层、控制台层和 SBI 层逐级协作完成。不过，本实验只实现了最小启动和输出闭环，没有涉及进程调度、虚拟内存、完整中断处理、并发同步及文件系统等核心机制；这些内容是从“能启动的内核”走向“可供多个程序使用的操作系统”所必须继续实现的部分。

总体而言，本实验把交叉编译、链接、模拟运行和 GDB 调试串成了一个可验证的工程流程。我不仅理解了启动路径中关键地址和寄存器的作用，也认识到观察实际执行状态、核对二进制和运行结果，是验证操作系统原理理解是否正确的重要方法。

### AI 协作开发的经验

启动 QEMU、连 GDB、单步复位向量、设观察点和断点，这些操作它可以直接执行并把真实输出贴回来，省掉了大量查手册和敲命令的时间，我们只需要判断输出意味着什么。

同时，AI 给出的解释仍需要结合源码、调试器状态和实验现象核对，不能只凭文字判断结论。把任务拆成可验证的小步骤（例如先确认复位时的 PC，再逐条观察寄存器变化，最后验证内核入口）有助于发现不准确的推断，也让 AI 成为提高效率的辅助工具，而不是替代理解和验证的工具。

---
