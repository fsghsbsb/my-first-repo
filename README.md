# uCore Operating Systems Lab 3

This branch contains the integrated RISC-V uCore Lab 3 source and report.

- `code/`: buildable Lab 3 kernel source and grading tools.
- `report/report.md`: complete team report.
- `report/prompt.md`: spec and prompt summary.
- `report/答辩准备.md`: C student's demonstration and Q&A notes.

Build and run from WSL Ubuntu:

```bash
cd code
make clean
make -j2
make grade
timeout 25s make qemu
```
