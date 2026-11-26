# Nand to Tetris Capstone: Make the Computer Draw a Box

K = 98 (K mod 3 = 2, K mod 4 = 2)
Box: starts at row 98, 20 rows tall, 48 px (3 words) wide, first address 19520.
Extra assembler feature: warning when a label is defined twice.

Files
- CPU.hdl, Memory.hdl, Computer.hdl : Part A (built-in ALU, ARegister, DRegister, PC, RAM16K, Screen, Keyboard, ROM32K, Mux/DMux chips are used)
- assembler.py : Part B  (python3 assembler.py Box.asm)
- Box.asm, Box.hack : Part C (Box.hack produced by assembler.py)
- tests/ : Add/Max/Rect/Dup test programs, a Python Hack emulator, run_tests.py
- dashboard.html : interactive demo (assembler + emulator + screen)

Status
- Python tests (python3 tests/run_tests.py): all pass.
- HDL files: NOT yet run in the official Hardware Simulator. Run CPU.tst, Memory.tst,
  ComputerAdd.tst, ComputerMax.tst, ComputerRect.tst yourself and take screenshots.
- Pong.asm: not available here. Compare assembler.py output against the official
  Assembler for Pong.asm on your machine.
