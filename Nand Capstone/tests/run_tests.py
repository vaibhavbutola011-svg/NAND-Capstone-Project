import os, sys, subprocess
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, ROOT); sys.path.insert(0, HERE)
import assembler
from emulator import Hack

def asm(name):
    src = open(os.path.join(HERE, name + '.asm') if os.path.exists(os.path.join(HERE, name + '.asm')) else os.path.join(ROOT, name + '.asm')).read()
    binary, warnings, symbols = assembler.assemble(src)
    return binary, warnings, symbols

fails = 0
def check(label, cond):
    global fails
    print(("PASS  " if cond else "FAIL  ") + label)
    if not cond: fails += 1

# Add: known official output
b, _, _ = asm('Add')
expected = ["0000000000000010","1110110000010000","0000000000000011",
            "1110000010010000","0000000000000000","1110001100001000"]
check("Add.hack matches official output", b == expected)
cpu = Hack([int(x, 2) for x in b])
for _ in range(6): cpu.step()
check("Add: RAM[0] == 5", cpu.ram[0] == 5)

# Max
b, _, sym = asm('Max')
for r0, r1 in [(3, 7), (7, 3), (5, 5), (0, 1)]:
    cpu = Hack([int(x, 2) for x in b]); cpu.ram[0] = r0; cpu.ram[1] = r1
    for _ in range(200): cpu.step()
    check("Max(%d,%d) -> R2 == %d" % (r0, r1, max(r0, r1)), cpu.ram[2] == max(r0, r1))
check("Max labels: OUTPUT_FIRST=10, OUTPUT_D=12, INFINITE_LOOP=14",
      (sym['OUTPUT_FIRST'], sym['OUTPUT_D'], sym['INFINITE_LOOP']) == (10, 12, 14))

# Rect
b, _, _ = asm('Rect')
cpu = Hack([int(x, 2) for x in b]); cpu.ram[0] = 5
for _ in range(2000): cpu.step()
rows = [r for r in range(256) if cpu.ram[16384 + 32 * r] == 0xFFFF]
check("Rect R0=5: rows 0-4 filled", rows == [0, 1, 2, 3, 4])
check("Rect variable 'counter' at 16, 'address' at 17",
      asm('Rect')[2]['counter'] == 16 and asm('Rect')[2]['address'] == 17)

# Duplicate-label warning (K mod 3 == 2)
_, w, _ = asm('Dup')
check("Duplicate label warning raised", len(w) == 1 and "'A'" in w[0] and "line 3" in w[0])

# Box (own assembler)
b, _, _ = asm('Box')
prog = [int(x, 2) for x in b]
K = 98
start, height, width_words = K, 20, ((K % 4) + 1)
def screen_state(cpu):
    return {r: [cpu.ram[16384 + 32 * r + c] for c in range(32)] for r in range(256)}
cpu = Hack(prog)
for _ in range(3000): cpu.step()
check("Box: screen blank with no key", all(v == 0 for v in cpu.ram[16384:24576]))
cpu.ram[24576] = 75
for _ in range(3000): cpu.step()
ok = True
for r in range(256):
    for c in range(32):
        want = 0xFFFF if (start <= r < start + height and c < width_words) else 0
        if cpu.ram[16384 + 32 * r + c] != want: ok = False
check("Box: key held -> exactly rows 98-117, 3 words (48 px) black", ok)
cpu.ram[24576] = 0
for _ in range(3000): cpu.step()
check("Box: key released -> box disappears", all(v == 0 for v in cpu.ram[16384:24576]))

# error reporting is not a crash
try:
    assembler.assemble("@1\nD=Q+1\n")
    check("Bad line raises AsmError", False)
except assembler.AsmError as e:
    check("Bad line gives message: %s" % e, "Line 2" in str(e))

print("\n%s" % ("ALL TESTS PASSED" if fails == 0 else "%d FAILED" % fails))
sys.exit(1 if fails else 0)
