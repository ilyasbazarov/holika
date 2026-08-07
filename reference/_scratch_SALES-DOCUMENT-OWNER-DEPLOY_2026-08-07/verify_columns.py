import re

src = open("reference/code/cf-facts/bq_ops.py").read()
m = re.search(
    r"WHEN MATCHED THEN UPDATE SET\n(.*?)\n\nWHEN NOT MATCHED THEN INSERT \(\n(.*?)\n\) VALUES",
    src,
    re.S,
)
update_block, insert_block = m.groups()


def cols(block, prefix):
    out = []
    for line in block.split("\n"):
        line = line.strip().rstrip(",")
        if not line:
            continue
        if prefix == "update":
            col = line.split("=")[0].strip().split(".")[1].strip()
        else:
            col = line
        out.append(col)
    return out


upd = cols(update_block, "update")
ins = cols(insert_block, "insert")
print("UPDATE SET (%d):" % len(upd), upd)
print("INSERT (%d):" % len(ins), ins)
diff = [c for c in ins if c not in upd]
print("INSERT-only columns (%d):" % len(diff), diff)
