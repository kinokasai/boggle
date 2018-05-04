import strutils
import bitarray
import math

type
  NotByte* = object of Exception

type binstring* = string

proc binDigits(x: BiggestInt, r: int): int =
  ## Calculates how many digits `x` has when each digit covers `r` bits.
  result = 1
  var y = x shr r
  while y > 0:
    y = y shr r
    inc(result)
 
proc toBin*(x: BiggestInt, len: Natural = 0): string =
  ## converts `x` into its binary representation. The resulting string is
  ## always `len` characters long. By default the length is determined
  ## automatically. No leading ``0b`` prefix is generated.
  var
    mask: BiggestInt = 1
    shift: BiggestInt = 0
    len = if len == 0: binDigits(x, 1) else: len
  result = newString(len)
  for j in countdown(len-1, 0):
    result[j] = chr(int((x and mask) shr shift) + ord('0'))
    shift = shift + 1
    mask = mask shl 1
 

proc new_string_filled(len: int, c: char) : string =
  result = newStringOfCap(len)
  for i in 0..<len:
    result.add(c)

proc left_pad(s: string, len: int) : string =
  var diff = len - s.len()
  result = (new_string_filled(diff, '0')) & s

# Binary functions 

proc bin_char(c: char) : string =
  toBin(c.BiggestInt, 8)

# The string must be a byte.
proc from_bin_char(s: string) : string =
  var s = s
  if s.len() < 8:
    raise newException(NotByte, "`" & s & "' is not a byte.")
  var acc = 0
  for i in 0..<s.len():
    acc += parseInt($s[i]) * pow(2, (7-i).float).int # 7-1 is the corresponding power of two.
  result = $chr(acc)

proc nsplit(str: string, n : int) : seq[string] =
  result = @[]
  var i = 0
  while i < str.len():
    var substr = str[i..<i+n]
    result.add(substr)
    i += n

proc binarize*(str: string) : binstring =
  result = ""
  for c in str:
    result.add(c.bin_char())
  # Add delimiter to end of word
  result.add("00000000")


proc to_bitarray*(str: binstring) : BitArray =
  result = create_bitarray(str.len + 64, len=str.len)
  for i in 0..<str.len:
    result[i] = (str[i].ord - 48).bool
  
proc ascii_to_bitarray*(str: string) : BitArray =
  result = str.binarize().to_bitarray

proc asciify*(str: binstring) : string = 
    result = ""
    var chars = nsplit(str, 8)
    for c in chars:
      if c != "00000000":
        result.add(from_bin_char(c))

proc space*(str: binstring) : string =
  result = ""
  for i in 0..<str.len:
    if i mod 4 == 0:
      result &= " "
    result &= str[i]

proc contents*(ba: BitArray) : string =
  result = ""
  for i in 0..<ba.len:
    result &= $ba[i].int

proc merge*(ba: BitArray, babis: BitArray) : BitArray =
  let margin = (ba.len + babis.len) div 64 + 1
  result = create_bitarray(margin * 64,len=ba.len + babis.len)
  for i in 0..<ba.len:
    result[i] = ba[i]
  for i in 0..<babis.len:
    result[i + ba.len] = babis[i]
  
proc `&`*(ba: BitArray, babis: BitArray): BitArray =
  merge(ba, babis)