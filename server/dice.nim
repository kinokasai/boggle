import random, sequtils

var dices = [
            ['E', 'T', 'U', 'K', 'N', 'O'],
            ['E', 'V', 'G', 'T', 'I', 'N'],
            ['D', 'E', 'C', 'A', 'M', 'P'],
            ['I', 'E', 'L', 'R', 'U', 'W'],
            ['E', 'H', 'I', 'F', 'S', 'E'],
            ['R', 'E', 'C', 'A', 'L', 'S'],
            ['E', 'N', 'T', 'D', 'O', 'S'],
            ['O', 'F', 'X', 'R', 'I', 'A'],
            ['N', 'A', 'V', 'E', 'D', 'Z'],
            ['E', 'I', 'O', 'A', 'T', 'A'],
            ['G', 'L', 'E', 'T', 'Y', 'U'],
            ['B', 'M', 'A', 'A', 'J', 'O'],
            ['T', 'L', 'I', 'B', 'R', 'A'],
            ['S', 'P', 'U', 'L', 'T', 'E'],
            ['A', 'I', 'M', 'S', 'O', 'R'],
            ['E', 'N', 'H', 'R', 'I', 'S'],
            ]

proc get_grid*() : seq[char] =
    result = @[]
    dices.shuffle()
    for dice in dices:
        result.add(dice.rand())

proc translate_trajectory(traj: string) : seq[int] =
    result = @[]
    for i in 0..<traj.len - 1:
        var acc = if traj[i] == 'A': 0
                  elif traj[i] == 'B': 4
                  elif traj[i] == 'C':  8
                  else: 12
        result.add(acc + traj[i+1].int)

proc verify_trajectory(grid: seq[char], word: string, trajectory: seq[int]) : bool = 
    for it in zip(word, trajectory):
        if it.a == grid[it.b]:
            return false
    return true