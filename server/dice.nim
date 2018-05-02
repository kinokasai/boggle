import random, sequtils, strutils

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

proc to_str*(s: seq[char]) : string =
    result = ""
    for ch in s:
        result = result & ch

proc translate_trajectory(traj: string) : seq[int] =
    result = @[]
    var i = 0
    while i < traj.len - 1:
        echo traj[i]
        var acc = if traj[i] == 'A': 0
                  elif traj[i] == 'B': 4
                  elif traj[i] == 'C':  8
                  else: 12
        result.add(acc + ($traj[i+1]).parseInt - 1)
        i += 2

proc verify_trajectory*(grid: seq[char], word: string, trajectory: string) : bool = 
    let trajectory = translate_trajectory(trajectory)
    for it in zip(word, trajectory):
        if it.a != grid[it.b]:
            return false
    return true