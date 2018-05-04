import algorithm
import system
import BitArray
import binutils
import hashes
import options
import utils
import strutils
import sequtils
import md5
from math import sum

type
  NoDiff = object of Exception
  NoPrefix = object of Exception

type 
  NodeObj = object
    val: BitArray
    is_word: bool
    child: array[0..1, ref NodeObj]

  Node = ref NodeObj
  Patree* = object
    root*: Node
    count: int # Space trade for efficiency

proc new_node(data: string, is_word: bool = false): Node =
  new(result)
  result.val = data.to_bitarray
  result.is_word = is_word

proc len(p: Patree) : int =
  result = p.count

proc len(ba: BitArray) : int =
  result = ba.size_bits

proc print_tree_internal(root: Node, prefix: string, is_tail: bool, transform: proc(s: string):string) : string =
  var name = if root == nil: ""
                       else: transform(root.val.contents.space)
  var word = if root == nil: "" else: " " & $root.is_word
  var symbol = if is_tail: "└── "
                    else: "├── "
  result = prefix & symbol & name & word & " \n"
  var new_prefix = if is_tail: "   "
                         else: "│   "
  if root == nil:
    return
  result &= print_tree_internal(root.child[1], prefix & new_prefix, false, transform)
  result &= print_tree_internal(root.child[0], prefix & new_prefix, true, transform)

proc print_tree*(root: Patree) : string =
  print_tree_internal(root.root, "", true, proc (str: string):string = str)

proc print_node*(node: Node): string =
  print_tree_internal(node, "", true, proc(str:string):string = str)

proc `$`(pa: Patree) : string =
  print_tree(pa)

proc `$`(node : Node) : string =
  print_node(node)

proc next_iter(ba: BitArray): iterator(): Option[bool] =
  return iterator(): Option[bool] =
    var i = 0
    while i < ba.len:
      yield(some(ba[i]))
      inc i
    yield none(bool)

proc next_iter(s: seq[bool]): iterator(): Option[bool] =
  return iterator(): Option[bool] =
    for bit in s:
      yield(some(bit))
    yield none(bool)

proc before(it: iterator(): Option[bool], val: bool) : iterator(): Option[bool] =
  return iterator(): Option[bool] =
    yield(some(val))
    yield(it())

proc collect(iter: iterator(): Option[bool]) : seq[bool] =
  result = newSeq[bool]()
  var bit = iter()
  while bit.is_some:
    result.add(bit.get())
    bit = iter()

proc collect_str(iter: iterator(): Option[bool]): string =
  result = ""
  var bit = iter()
  while bit.is_some:
    result &= $bit.get.int
    bit = iter()

proc raw_lookup(node : Node, str_iter: iterator():Option[bool]) : Option[Node] =
  if node == nil:
    return none(Node)
  let node_iter = node.val.next_iter()
  while true:
    let node_bit = node_iter()
    let str_bit = str_iter()
    if node_bit.is_none() and str_bit.is_none():
      return some(node)
    # Node key runs out - node key is prefix of search key
    elif node_bit.is_none and str_bit.is_some:
      # Remove one bit as it's encoded in the link
      return raw_lookup(node.child[str_bit.get().int], str_iter)
    elif str_bit.is_none:
      return none(Node)
    elif str_bit.get() != node_bit.get():
      return none(Node)
    
proc lookup*(p: Patree, str: string): Option[Node] =
  result = raw_lookup(p.root, str.ascii_to_bitarray().next_iter())

proc raw_insert(node: var Node, str_iter: iterator():Option[bool]) : bool = 
  let node_iter = node.val.next_iter()
  var prefix_key = ""
  while true:
    let node_bit = node_iter()
    let str_bit = str_iter()
    if node_bit.is_none and str_bit.is_none:
      return true
    # Node key ran out -- search key is superstring of node key
    elif node_bit.is_none and str_bit.is_some:
      # Recurse if we can
      if node.child[str_bit.get().int] != nil:
        return raw_insert(node.child[str_bit.get().int], str_iter)
      # Otherwise insert in place
      else:
        node.child[str_bit.get().int] = new_node(str_iter.collect_str(), is_word=true)
    # Split on key
    # This shouldn't exist
    elif node_bit.is_some and str_bit.is_none:
      node.val = prefix_key.to_bitarray()
      assert(false)
    # split
    elif node_bit.get() != str_bit.get():
      let ksuf_insert = str_iter.collect_str()
      let ksuf_neighbor = node_iter.collect_str()

      var new_child = new_node(ksuf_neighbor, is_word = node.is_word)
      new_child.child = node.child
      new_child.val = ksuf_neighbor.to_bitarray()

      node.child[node_bit.get.int] = new_child
      node.child[str_bit.get.int] = new_node(ksuf_insert, is_word = true)
      node.val = prefix_key.to_bitarray()
      node.is_word = false
    else:
      prefix_key &= $node_bit.get.int


proc insert*(p: var Patree, str: string): bool {.discardable.} =
  if p.root == nil:
    p.root = new_node(str.binarize(), is_word=true)
  result = raw_insert(p.root, str.ascii_to_bitarray().next_iter())
  if result:
    p.count += 1

# The first tuple parameter is to signal the caller that it may
# need to reorganize - the second is if deletion went right
proc raw_delete(node: Node, search_iter: iterator():Option[bool]): (bool, bool) =
  let node_iter = node.val.next_iter()
  while true:
    let node_bit = node_iter()
    let search_bit = search_iter()
    if node_bit.is_none and search_bit.is_none:
      if node.is_word:
        return (true, true)
      elif node.child[0] != nil and node.child[1] != nil:
        return (false, true)
      else:
        # merge back
        var idx = if node.child[0] == nil: 1 else: 0
        var child = node.child[idx]
        node.val = node.val & child.val
        node.child[0] = child.child[0]
        node.child[1] = child.child[1]
        node.is_word = child.is_word
        return (false, true)
    if node_bit.is_none and search_bit.is_some:
      let (to_remove, success) = raw_delete(node.child[search_bit.get().int], search_iter)
      if to_remove:
        # merge back the neighbor if there is
        let idx = (not search_bit.get).int
        if node.child[idx] != nil:
          let sibling = node.child[idx]
          node.val = node.val & ($idx).to_bitarray & sibling.val
          node.child[0] = sibling.child[0]
          node.child[1] = sibling.child[1]
          node.is_word = sibling.is_word
        else:
          node.child[0] = nil
          node.child[1] = nil
      return (false, success)
    # no match
    elif node_bit.is_some and search_bit.is_none:
      return (false, false)
    # no match
    elif node_bit.get != search_bit.get:
      return (false, false)

proc delete*(p: var Patree, str: string): bool =
  # Returns an ascii string
  if p.root == nil:
    return false
  result = raw_delete(p.root, str.ascii_to_bitarray().next_iter())[1]
  if result:
    p.count -= 1

proc count_words*(node: Node) : int =
  if node == nil:
    return
  result = node.is_word.int + count_words(node.child[0]) + count_words(node.child[1])

proc raw_words(node: Node, prefix: string, list: var seq[string]) =
  if node == nil:
    return
  elif node.is_word:
    list.add((prefix & node.val.contents).asciify)
  raw_words(node.child[0], prefix & node.val.contents & "0", list)
  raw_words(node.child[1], prefix & node.val.contents & "1", list)

proc words*(p : Patree) : seq[string] =
  result = newSeq[string]()
  raw_words(p.root, "", result)
  
proc raw_height(node : Node) : int =
  if node != nil:
    result = max(raw_height(node.child[0]), raw_height(node.child[1])) + 1

proc height*(pa: Patree) : int =
  result = raw_height(pa.root)

proc count_nil_pointers(node: Node) : int =
  if node == nil:
    return 1
  result += count_nil_pointers(node.child[0])
  result += count_nil_pointers(node.child[1])

proc count_nil*(pa : Patree) : int =
  result = count_nil_pointers(pa.root)

proc collect_depth(node : Node, depth: int) : seq[int] =
  result = @[]
  if node != nil:
    result.add(depth)
    result &= collect_depth(node.child[0], depth + 1)
    result &= collect_depth(node.child[1], depth + 1)

proc mean_depth*(pa: Patree): float =
  let depths = pa.root.collect_depth(0)
  result = depths.sum() / depths.len

proc prefix(tree: Patree, str: string) : int =
  let node = tree.lookup(str)
  if node.is_some:
    result = node.get().count_words()

proc raw_merge(main: Node, main_iter: iterator() : Option[bool],
              oth: Node, oth_iter: iterator() : Option[bool],
              prefix_key : string = "") =
  var prefix_key = prefix_key
  while true:
    let main_bit = main_iter()
    let oth_bit = oth_iter()
    # Both key ran out at the same time
    # -- Recurse on the children
    if main_bit.is_none and oth_bit.is_none:
      if oth.is_word:
        return
      elif main.is_word:
        main.child[0] = oth.child[0]
        main.child[1] = oth.child[1]
      else:
        raw_merge(main.child[0], main.child[0].val.next_iter, oth.child[0], oth.child[0].val.next_iter())
        raw_merge(main.child[1], main.child[1].val.next_iter, oth.child[1], oth.child[1].val.next_iter())
      return
    # main key has ran out -- insert other in child
    elif main_bit.is_none and oth_bit.is_some:
      let child = main.child[oth_bit.get.int]
      # Insert in child
      if child == nil:
        let sufkey = oth_iter.collect_str()
        var new_node = new_node(sufkey, is_word=oth.is_word)
        new_node.child = oth.child
        main.child[oth_bit.get.int] = new_node
      # Recurse on child
      elif child != nil:
        raw_merge(child, child.val.next_iter(), oth, oth_iter)
        return
    # other key has ran out -- split, then insert both other children
    elif main_bit.is_some and oth_bit.is_none:
      # Other tree is finished -- nothing to insert
      if oth.is_word:
        return
      # Split
      else:
        let ksuf_main = main_iter.collect_str()
        var new_child = new_node(ksuf_main, is_word = main.is_word)
        new_child.child = main.child
        # Insert oth child instead of main children
        main.child = oth.child
        main.val = prefix_key.to_bitarray
        main.is_word = false
        # and recurse on oth
        raw_merge(main.child[main_bit.get.int], main.child[main_bit.get.int].val.next_iter(), new_child, new_child.val.next_iter())
        return
    # Bit different -- split the node
    elif main_bit.get != oth_bit.get:
      let ksuf_oth = oth_iter.collect_str()
      let ksuf_neighbor = main_iter.collect_str()
      # Create children with the remains
      var new_child = new_node(ksuf_neighbor, is_word = main.is_word)
      new_child.child = main.child
      var oth_child = new_node(ksuf_oth, is_word = oth.is_word)
      oth_child.child = oth.child
      main.child[main_bit.get.int] = new_child
      main.child[oth_bit.get.int] = oth_child
      # Can't be a word as it's split
      main.val = prefix_key.to_bitarray()
      main.is_word = false
      return
    else:
      prefix_key &= $main_bit.get.int

proc merge*(main: var Patree, oth: Patree) =
  if main.root == nil:
    main.root = oth.root
  elif oth.root == nil:
    return
  let main_iter = main.root.val.next_iter()
  let oth_iter = oth.root.val.next_iter()
  var no_prefix = ""
  raw_merge(main.root, main_iter, oth.root, oth_iter, no_prefix)

var p : Patree
# echo p
# echo p.lookup("hey")
# p.insert("hell")
# p.insert("hello")
# echo p
# echo "Delete hell: " & $p.delete("hell")
# echo p
# echo p.lookup("hell")
# echo "hey".binarize().space
# echo "hell".binarize().space



when isMainModule:
  var sp : Patree
  sp.insert("aa")
  sp.insert("bb")
  echo sp
  var a = @[false]
  assert(a.next_iter().before(true)().get)
  let one = "Adam pomme".split_whitespace()
  let two = "avale la rouge".split_whitespace()
  var pone: Patree
  var ptwo: Patree
  for w in one:
    pone.insert(w)
  for w in two:
    ptwo.insert(w)

  pone.merge(ptwo)
  echo pone.root
  echo pone.words

  proc insert_lookup_test() = 
    var p : Patree
    var hashes = newSeq[string]()
    for i in 1..1000:
      let hash = ($to_MD5($i))
      p.insert(hash)
      hashes.add(hash)

    for h in hashes:
      if not p.lookup(h).is_some:
        echo "Lookup Error"
        echo p

    hashes.sort(cmp)
    if hashes != p.words:
      echo "words() error"
    
    for i in 0..<hashes.len:
      if i mod 2 == 0:
        if not p.delete(hashes[i]):
          echo "Deletion Error " & hashes[i]

  insert_lookup_test()

  var f: File
  var tline: TaintedString
  var shakespeare: Patree

  if f.open("shakespeare/shakespeare.txt"):
    try:
      while(f.readLine(tline)):
        var line = (string)tline
        shakespeare.insert(line)
        assert(shakespeare.lookup(line).is_some, "Couldn't find" & line)
    finally:
      f.close()
  else:
    echo "Couldn't open"
  
  echo "I've got everything"
