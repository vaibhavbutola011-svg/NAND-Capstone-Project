#!/usr/bin/env python3
"""
assembler.py - Hack assembler (Nand to Tetris, Project 6)

Usage:  python3 assembler.py Prog.asm [Prog.hack]

Capstone extra feature (K = 98, K mod 3 = 2):
    print a warning if the same label is written twice.
"""
import sys

PREDEFINED = {
    "SP": 0, "LCL": 1, "ARG": 2, "THIS": 3, "THAT": 4,
    "SCREEN": 16384, "KBD": 24576,
}
for _i in range(16):
    PREDEFINED["R%d" % _i] = _i

COMP = {
    "0": "0101010", "1": "0111111", "-1": "0111010",
    "D": "0001100", "A": "0110000", "!D": "0001101", "!A": "0110001",
    "-D": "0001111", "-A": "0110011", "D+1": "0011111", "A+1": "0110111",
    "D-1": "0001110", "A-1": "0110010", "D+A": "0000010", "D-A": "0010011",
    "A-D": "0000111", "D&A": "0000000", "D|A": "0010101",
    "M": "1110000", "!M": "1110001", "-M": "1110011", "M+1": "1110111",
    "M-1": "1110010", "D+M": "1000010", "D-M": "1010011", "M-D": "1000111",
    "D&M": "1000000", "D|M": "1010101",
}
DEST = {"": "000", "M": "001", "D": "010", "MD": "011",
        "A": "100", "AM": "101", "AD": "110", "AMD": "111"}
JUMP = {"": "000", "JGT": "001", "JEQ": "010", "JGE": "011",
        "JLT": "100", "JNE": "101", "JLE": "110", "JMP": "111"}


class AsmError(Exception):
    pass


def clean(line):
    """Remove comments and all whitespace."""
    line = line.split("//", 1)[0]
    return "".join(line.split())


def valid_symbol(s):
    if not s or s[0].isdigit():
        return False
    return all(c.isalnum() or c in "_.$:" for c in s)


def normalise_dest(d):
    """Allow any order of A, D, M letters (e.g. DM == MD)."""
    key = "".join(sorted(d, key="AMD".index)) if d else ""
    return key


def first_pass(lines, warnings):
    """Build the symbol table: record label -> ROM address, skip comments/blank lines."""
    symbols = dict(PREDEFINED)
    label_line = {}
    rom = 0
    for lineno, raw in enumerate(lines, 1):
        text = clean(raw)
        if not text:
            continue
        if text.startswith("("):
            if not text.endswith(")") or not valid_symbol(text[1:-1]):
                raise AsmError("Line %d: invalid label '%s'" % (lineno, raw.strip()))
            name = text[1:-1]
            if name in label_line:
                # --- K mod 3 == 2 extra feature: duplicate-label warning ---
                warnings.append(
                    "Warning: label '%s' defined again on line %d "
                    "(first defined on line %d)" % (name, lineno, label_line[name]))
            else:
                label_line[name] = lineno
                symbols[name] = rom       # first definition wins
            continue
        rom += 1
    return symbols


def encode_a(text, symbols, state, lineno):
    sym = text[1:]
    if not sym:
        raise AsmError("Line %d: empty A-instruction" % lineno)
    if sym.isdigit():
        value = int(sym)
    else:
        if not valid_symbol(sym):
            raise AsmError("Line %d: invalid symbol '%s'" % (lineno, sym))
        if sym not in symbols:
            symbols[sym] = state["next_var"]     # new variable: 16, 17, 18, ...
            state["next_var"] += 1
        value = symbols[sym]
    if value > 32767:
        raise AsmError("Line %d: address %d out of range" % (lineno, value))
    return format(value, "016b")


def encode_c(text, lineno):
    dest, comp, jump = "", text, ""
    if "=" in text:
        dest, comp = text.split("=", 1)
    if ";" in comp:
        comp, jump = comp.split(";", 1)
    dest = normalise_dest(dest)
    if dest not in DEST:
        raise AsmError("Line %d: invalid destination '%s'" % (lineno, dest))
    if comp not in COMP:
        # accept commutative forms such as A+D, M&D, 1+D
        alt = {"A+D": "D+A", "M+D": "D+M", "A&D": "D&A", "M&D": "D&M",
               "A|D": "D|A", "M|D": "D|M", "1+D": "D+1", "1+A": "A+1",
               "1+M": "M+1"}.get(comp)
        if alt is None:
            raise AsmError("Line %d: invalid instruction (bad computation '%s')"
                           % (lineno, comp))
        comp = alt
    if jump not in JUMP:
        raise AsmError("Line %d: invalid jump '%s'" % (lineno, jump))
    return "111" + COMP[comp] + DEST[dest] + JUMP[jump]


def second_pass(lines, symbols):
    out = []
    state = {"next_var": 16}
    for lineno, raw in enumerate(lines, 1):
        text = clean(raw)
        if not text or text.startswith("("):
            continue
        if text.startswith("@"):
            out.append(encode_a(text, symbols, state, lineno))
        else:
            out.append(encode_c(text, lineno))
    return out


def assemble(source_text):
    """Return (list_of_binary_lines, warnings, symbol_table)."""
    lines = source_text.splitlines()
    warnings = []
    symbols = first_pass(lines, warnings)
    binary = second_pass(lines, symbols)
    return binary, warnings, symbols


def main(argv):
    if len(argv) < 2:
        print("Usage: python3 assembler.py Prog.asm [Prog.hack]")
        return 2
    src = argv[1]
    dst = argv[2] if len(argv) > 2 else (src[:-4] if src.endswith(".asm") else src) + ".hack"
    try:
        with open(src) as f:
            text = f.read()
        binary, warnings, _ = assemble(text)
    except AsmError as e:
        print("Error: %s" % e)
        return 1
    except OSError as e:
        print("Error: %s" % e)
        return 1
    for w in warnings:
        print(w, file=sys.stderr)
    with open(dst, "w") as f:
        f.write("\n".join(binary) + "\n")
    print("Assembled %d instructions -> %s" % (len(binary), dst))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
