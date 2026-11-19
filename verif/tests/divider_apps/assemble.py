"""Encode the small RV32IM programs in this folder as .x memory images.

This intentionally supports only the instructions used by these examples.
Run `python3 verif/tests/divider_apps/assemble.py` from the repository root.
"""

from pathlib import Path


HERE = Path(__file__).resolve().parent
R_FUNCT3 = {"add": 0, "div": 4, "divu": 5, "rem": 6, "remu": 7}
B_FUNCT3 = {"beq": 0, "bne": 1, "blt": 4}


def register(token):
    assert token.startswith("x") and token[1:].isdigit(), token
    number = int(token[1:])
    assert 0 <= number < 32, token
    return number


def signed_range(value, bits):
    assert -(1 << (bits - 1)) <= value < (1 << (bits - 1)), value
    return value & ((1 << bits) - 1)


def encode(line, pc, labels):
    parts = line.replace(",", " ").split()
    op, args = parts[0], parts[1:]

    if op == "nop":
        assert not args
        return 0x00000013
    if op == "ecall":
        assert not args
        return 0x00000073
    if op == "addi":
        assert len(args) == 3
        rd, rs1, imm = register(args[0]), register(args[1]), signed_range(int(args[2], 0), 12)
        return (imm << 20) | (rs1 << 15) | (rd << 7) | 0x13
    if op in R_FUNCT3:
        assert len(args) == 3
        rd, rs1, rs2 = map(register, args)
        funct7 = 1 if op != "add" else 0
        return (funct7 << 25) | (rs2 << 20) | (rs1 << 15) | (R_FUNCT3[op] << 12) | (rd << 7) | 0x33
    if op in B_FUNCT3:
        assert len(args) == 3
        rs1, rs2 = register(args[0]), register(args[1])
        offset = labels[args[2]] - pc
        assert offset % 2 == 0
        imm = signed_range(offset, 13)
        return (((imm >> 12) & 1) << 31 | ((imm >> 5) & 0x3f) << 25 |
                (rs2 << 20) | (rs1 << 15) | (B_FUNCT3[op] << 12) |
                ((imm >> 1) & 0xf) << 8 | ((imm >> 11) & 1) << 7 | 0x63)
    if op == "jal":
        assert len(args) == 2
        rd = register(args[0])
        offset = labels[args[1]] - pc
        assert offset % 2 == 0
        imm = signed_range(offset, 21)
        return (((imm >> 20) & 1) << 31 | ((imm >> 1) & 0x3ff) << 21 |
                ((imm >> 11) & 1) << 20 | ((imm >> 12) & 0xff) << 12 |
                (rd << 7) | 0x6f)
    raise ValueError(f"unsupported instruction: {line}")


def assemble(path):
    labels = {}
    instructions = []
    for raw in path.read_text().splitlines():
        line = raw.split("#", 1)[0].strip()
        if not line:
            continue
        if line.endswith(":"):
            label = line[:-1]
            assert label not in labels, label
            labels[label] = 4 * len(instructions)
        else:
            instructions.append(line)
    words = [encode(line, 4 * index, labels) for index, line in enumerate(instructions)]
    path.with_suffix(".x").write_text("".join(f"{word:08x}\n" for word in words))
    print(f"{path.name}: {len(words)} instructions")


if __name__ == "__main__":
    for source in sorted(HERE.glob("*.txt")):
        assemble(source)
