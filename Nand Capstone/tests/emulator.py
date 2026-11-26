"""Minimal Hack CPU emulator used only to verify assembled programs."""
def load(path):
    return [int(l, 2) for l in open(path).read().split()]

class Hack:
    def __init__(self, rom):
        self.rom = rom + [0] * (32768 - len(rom))
        self.ram = [0] * 24577
        self.a = self.d = self.pc = 0

    def step(self):
        i = self.rom[self.pc]
        if not i & 0x8000:
            self.a = i; self.pc += 1; return
        m = self.ram[self.a] if self.a <= 24576 else 0
        y = m if i & 0x1000 else self.a
        x = self.d
        if i & 0x800: x = 0
        if i & 0x400: x = ~x & 0xFFFF
        if i & 0x200: y = 0
        if i & 0x100: y = ~y & 0xFFFF
        o = (x + y) & 0xFFFF if i & 0x80 else x & y
        if i & 0x40: o = ~o & 0xFFFF
        sg = o - 65536 if o & 0x8000 else o
        a_old = self.a
        if i & 0x8: self.ram[a_old] = o
        if i & 0x10: self.d = o
        if i & 0x20: self.a = o
        j = (i & 4 and sg < 0) or (i & 2 and sg == 0) or (i & 1 and sg > 0)
        # jump target is the value A held before this instruction executed
        self.pc = a_old if j else self.pc + 1
