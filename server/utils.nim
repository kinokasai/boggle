import macros

proc warn*(str: string) =
  echo "[WARN]: " & str

macro debug*(n: varargs[untyped]): typed =
  # `n` is a Nim AST that contains a list of expressions;
  # this macro returns a list of statements (n is passed for proper line
  # information):
  result = newNimNode(nnkStmtList, n)
  # iterate over any argument that is passed to this macro:
  for x in n:
    # add a call to the statement list that writes the expression;
    # `toStrLit` converts an AST to its string representation:
    result.add(newCall("write", newIdentNode("stdout"), toStrLit(x)))
    # add a call to the statement list that writes ": "
    result.add(newCall("write", newIdentNode("stdout"), newStrLitNode(": ")))
    # add a call to the statement list that writes the expressions value:
    result.add(newCall("writeLine", newIdentNode("stdout"), x))

