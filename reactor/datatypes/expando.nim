## Expando allows adding new fields to objects.
##
import tables

type
  Expando*[T] = ref object
    table: Table[pointer, T]

var whichExpando {.threadvar.}: TableRef[pointer, pointer]

proc newExpando*[T](): Expando[T] =
  new(result)
  result.table = initTable[pointer, T]()

proc ensureInit*[T](expando: var Expando[T]) =
  if expando == nil:
    expando = newExpando[T]()

proc get*[T, O](expando: Expando[T], obj: ref O): T =
  let p = cast[pointer](obj)
  return expando.table.getOrDefault(p)

proc destructExpandoObj[T, O](obj: ref O) =
  let p = cast[pointer](obj)
  let expando = cast[Expando[T]](whichExpando[p])
  expando.table.del(p)

proc copyWithValue*[T, O](expando: Expando[T], obj: O, val: T): ref O =
  if whichExpando == nil:
    whichExpando = newTable[pointer, pointer]()

  var newObj: ref O
  new(newObj, destructExpandoObj[T, O])
  newObj[] = obj
  whichExpando[cast[pointer](newObj)] = cast[pointer](expando)
  expando.table[cast[pointer](newObj)] = val
  return newObj
