import Arrow
open Arrow

def assertEq [BEq α] [ToString α] (label : String) (got expected : α) : IO Unit :=
  unless got == expected do throw (.userError s!"{label}: got {got}, expected {expected}")


def testConstruction : IO Unit := do
  let c ← Col.int64s #[some 1, some 2, some 3, none, some 5]
  assertEq "int64 len" (← c.len) 5
  assertEq "int64 nulls" (← c.nullCount) 1
  assertEq "int64[0]" (← c[0]) (some 1)
  assertEq "int64[2]" (← c[2]) (some 3)
  assertEq "int64[3]" (← c[3]) none
  assertEq "isNull[3]" (← c.isNull 3) true
  assertEq "isValid[0]" (← c.isValid 0) true
  assertEq "isValid[3]" (← c.isValid 3) false

  let f ← Col.float64s #[some 1.1, some 2.2, none, some 4.4]
  assertEq "float64 len" (← f.len) 4
  assertEq "float64[1]" (← f[1]) (some 2.2)
  assertEq "float64[2]" (← f[2]) none

  let b ← Col.bools #[some true, some false, none]
  assertEq "bool len" (← b.len) 3
  assertEq "bool[0]" (← b[0]) (some true)
  assertEq "bool[1]" (← b[1]) (some false)
  assertEq "bool[2]" (← b[2]) none

  let s ← Col.strings #[some "hello", none, some "world"]
  assertEq "string[0]" (← s[0]) (some "hello")
  assertEq "string[1]" (← s[1]) none
  assertEq "string[2]" (← s[2]) (some "world")

  -- Col.toString
  let repr ← c.toString
  unless repr.length > 0 do throw (.userError "Col.toString: empty")
  IO.println "  construction: ok"

def testArithmetic : IO Unit := do
  let a := Col.int64s #[some 10, some 20, some 30]
  let b := Col.int64s #[some 1, some 2, some 3]
  let add ← a + b
  assertEq "add[0]" (← add[0]) (some 11)
  assertEq "add[1]" (← add[1]) (some 22)
  assertEq "add[2]" (← add[2]) (some 33)
  let sub ← a - b
  assertEq "sub[0]" (← sub[0]) (some 9)
  assertEq "sub[2]" (← sub[2]) (some 27)
  let mul ← a * b
  assertEq "mul[0]" (← mul[0]) (some 10)
  assertEq "mul[2]" (← mul[2]) (some 90)
  let div ← a / b
  assertEq "div[0]" (← div[0]) (some 10)
  assertEq "div[2]" (← div[2]) (some 10)
  let neg ← Col.neg (← a)
  assertEq "neg[0]" (← neg[0]) (some (-10))
  assertEq "neg[2]" (← neg[2]) (some (-30))

  -- float arithmetic
  let fa := Col.float64s #[some 1.5, some 2.5]
  let fb := Col.float64s #[some 0.5, some 2.5]
  assertEq "fadd[0]" (← (fa + fb)[0]) (some 2.0)
  assertEq "fsub[0]" (← (fa - fb)[0]) (some 1.0)
  assertEq "fmul[0]" (← (fa * fb)[0]) (some 0.75)
  assertEq "fdiv[0]" (← (fa / fb)[0]) (some 3.0)
  assertEq "fneg[0]" (← (Col.neg (← fa))[0]) (some (-1.5))

  -- null propagation
  let n1 := Col.int64s #[some 10, none, some 30]
  let n2 := Col.int64s #[some 1, some 2, none]
  let nadd ← n1 + n2
  assertEq "null add[0]" (← nadd[0]) (some 11)
  assertEq "null add[1]" (← nadd[1]) none
  assertEq "null add[2]" (← nadd[2]) none

  -- chained: a + b * b works without intermediate binds
  let chained ← a + b * b
  assertEq "(a+b*b)[0]" (← chained[0]) (some 11)
  assertEq "(a+b*b)[1]" (← chained[1]) (some 24)
  assertEq "(a+b*b)[2]" (← chained[2]) (some 39)
  IO.println "  arithmetic: ok"

def testComparison : IO Unit := do
  let x := Col.int64s #[some 1, some 2, some 3]
  let y := Col.int64s #[some 2, some 2, some 1]
  assertEq "eq[0]" (← (x =. y)[0]) (some false)
  assertEq "eq[1]" (← (x =. y)[1]) (some true)
  assertEq "neq[0]" (← (x ≠. y)[0]) (some true)
  assertEq "neq[1]" (← (x ≠. y)[1]) (some false)
  assertEq "lt[0]" (← (x <. y)[0]) (some true)
  assertEq "lt[2]" (← (x <. y)[2]) (some false)
  assertEq "gt[2]" (← (x >. y)[2]) (some true)
  assertEq "lte[1]" (← (x ≤. y)[1]) (some true)
  assertEq "gte[0]" (← (x ≥. y)[0]) (some false)

  -- nulls propagate in comparisons
  let n1 := Col.int64s #[some 10, none, some 30]
  let n2 := Col.int64s #[some 1, some 2, none]
  assertEq "null eq[0]" (← (n1 =. n2)[0]) (some false)
  assertEq "null eq[1]" (← (n1 =. n2)[1]) none
  assertEq "null eq[2]" (← (n1 =. n2)[2]) none

  -- string comparison
  let sa := Col.strings #[some "apple", some "banana", some "cherry"]
  let sb := Col.strings #[some "banana", some "banana", some "apple"]
  assertEq "str eq[1]" (← (sa =. sb)[1]) (some true)
  assertEq "str lt[0]" (← (sa <. sb)[0]) (some true)
  assertEq "str gte[2]" (← (sa ≥. sb)[2]) (some true)
  IO.println "  comparison: ok"

def testVectorOps : IO Unit := do
  -- filter
  let a ← Col.int64s #[some 10, some 20, some 30]
  let mask ← Col.bools #[some true, some false, some true]
  let filt ← Col.filter a mask
  assertEq "filter len" (← filt.len) 2
  assertEq "filter[0]" (← filt[0]) (some 10)
  assertEq "filter[1]" (← filt[1]) (some 30)

  -- take
  let src ← Col.int64s #[some 10, some 20, some 30, some 40, some 50]
  let idx ← Col.int64s #[some 4, some 0, some 2]
  let taken ← Col.take src idx
  assertEq "take[0]" (← taken[0]) (some 50)
  assertEq "take[1]" (← taken[1]) (some 10)
  assertEq "take[2]" (← taken[2]) (some 30)

  -- sort
  let u ← Col.int64s #[some 30, some 10, some 20]
  let asc ← Col.sort u true
  assertEq "sort asc[0]" (← asc[0]) (some 10)
  assertEq "sort asc[1]" (← asc[1]) (some 20)
  assertEq "sort asc[2]" (← asc[2]) (some 30)
  let desc ← Col.sort u false
  assertEq "sort desc[0]" (← desc[0]) (some 30)
  assertEq "sort desc[2]" (← desc[2]) (some 10)

  -- sort indices
  let si ← Col.sortIndices u true
  assertEq "sortIdx asc[0]" (← si[0]) (some 1)
  assertEq "sortIdx asc[1]" (← si[1]) (some 2)
  assertEq "sortIdx asc[2]" (← si[2]) (some 0)

  -- unique (preserves first-occurrence order)
  let dupes ← Col.int64s #[some 1, some 2, some 1, some 3, some 2]
  let uniq ← Col.unique dupes
  assertEq "unique len" (← uniq.len) 3
  assertEq "unique[0]" (← uniq[0]) (some 1)
  assertEq "unique[1]" (← uniq[1]) (some 2)
  assertEq "unique[2]" (← uniq[2]) (some 3)
  IO.println "  vector ops: ok"

def testAggregation : IO Unit := do
  let a ← Col.int64s #[some 10, some 20, some 30]
  assertEq "sum" (← (← Col.sum a).toInt64) (some 60)
  assertEq "min" (← (← Col.min a).toInt64) (some 10)
  assertEq "max" (← (← Col.max a).toInt64) (some 30)
  assertEq "mean" (← (← Col.mean a).toFloat64) (some 20.0)
  assertEq "count" (← Col.count a) 3

  -- float aggregation
  let fa ← Col.float64s #[some 1.5, some 2.5, some 3.0]
  assertEq "fsum" (← (← Col.sum fa).toFloat64) (some 7.0)
  assertEq "fmin" (← (← Col.min fa).toFloat64) (some 1.5)
  assertEq "fmax" (← (← Col.max fa).toFloat64) (some 3.0)

  -- nulls are skipped in aggregation
  let nv ← Col.int64s #[some 10, none, some 30, none, some 50]
  assertEq "sum(nulls)" (← (← Col.sum nv).toInt64) (some 90)
  assertEq "min(nulls)" (← (← Col.min nv).toInt64) (some 10)
  assertEq "max(nulls)" (← (← Col.max nv).toInt64) (some 50)
  assertEq "mean(nulls)" (← (← Col.mean nv).toFloat64) (some 30.0)
  assertEq "count(nulls)" (← Col.count nv) 3

  -- count distinct
  let dupes ← Col.int64s #[some 1, some 2, some 1, some 3, some 2, none]
  assertEq "count" (← Col.count dupes) 5
  assertEq "countDistinct" (← Col.countDistinct dupes) 3

  -- any / all
  let allTrue ← Col.bools #[some true, some true, some true]
  let mixed ← Col.bools #[some true, some false, some true]
  let allFalse ← Col.bools #[some false, some false]
  assertEq "all(ttt)" (← Col.all allTrue) true
  assertEq "all(tft)" (← Col.all mixed) false
  assertEq "any(tft)" (← Col.any mixed) true
  assertEq "any(ff)" (← Col.any allFalse) false
  -- with nulls: nulls are skipped by default
  let withNull ← Col.bools #[some true, none, some true]
  assertEq "all(t,null,t)" (← Col.all withNull) true
  assertEq "any(t,null,t)" (← Col.any withNull) true
  -- combined with comparison operators
  let vals := Col.int64s #[some 1, some 2, some 3]
  let threshold := Col.int64s #[some 2, some 2, some 2]
  assertEq "any(>)" (← Col.any (← vals >. threshold)) true
  assertEq "all(>)" (← Col.all (← vals >. threshold)) false
  IO.println "  aggregation: ok"

def testChained : IO Unit := do
  -- top-3 descending
  let vals ← Col.int64s #[some 50, some 10, some 40, some 20, some 30]
  let si ← Col.sortIndices vals false
  let top3idx ← Col.take si (← Col.int64s #[some 0, some 1, some 2])
  let top3 ← Col.take vals top3idx
  assertEq "top3[0]" (← top3[0]) (some 50)
  assertEq "top3[1]" (← top3[1]) (some 40)
  assertEq "top3[2]" (← top3[2]) (some 30)

  -- filter then sum: sum of elements > 2 in [1,2,3,4,5]
  let data := Col.int64s #[some 1, some 2, some 3, some 4, some 5]
  let threshold := Col.int64s #[some 2, some 2, some 2, some 2, some 2]
  let filtered ← Col.filter (← data) (← data >. threshold)
  assertEq "filter>2 len" (← filtered.len) 3
  assertEq "sum(x>2)" (← (← Col.sum filtered).toInt64) (some 12)
  IO.println "  chained: ok"

def testTable : IO Unit := do
  let ca ← (Col.int64s #[some 1, some 2, some 3]) >>= Col.erase
  let cb ← (Col.strings #[some "a", some "b", some "c"]) >>= Col.erase
  let tbl ← Tbl.make #["id", "name"] #[ca, cb]
  assertEq "rows" (← tbl.numRows) 3
  assertEq "cols" (← tbl.numCols) 2
  assertEq "colNames" (← tbl.colNames) #["id", "name"]

  -- round-trip: extract typed column from table
  let idCol ← (← tbl.col "id") |>.castInt64
  assertEq "tbl id[0]" (← idCol[0]) (some 1)
  assertEq "tbl id[2]" (← idCol[2]) (some 3)
  let nameCol ← (← tbl.col "name") |>.castString
  assertEq "tbl name[1]" (← nameCol[1]) (some "b")

  -- table filter
  let mask ← Col.bools #[some true, some false, some true]
  let filtered ← tbl.filter mask
  assertEq "filtered rows" (← filtered.numRows) 2
  let fid ← (← filtered.col "id") |>.castInt64
  assertEq "filtered id[0]" (← fid[0]) (some 1)
  assertEq "filtered id[1]" (← fid[1]) (some 3)

  -- table sort
  let sorted ← tbl.sort "id" false
  let sid ← (← sorted.col "id") |>.castInt64
  assertEq "sorted id[0]" (← sid[0]) (some 3)
  assertEq "sorted id[2]" (← sid[2]) (some 1)

  -- select columns
  let proj ← tbl.select #["name"]
  assertEq "select cols" (← proj.numCols) 1
  assertEq "select names" (← proj.colNames) #["name"]

  -- add column
  let scores ← (Col.float64s #[some 9.5, some 8.0, some 7.5]) >>= Col.erase
  let extended ← tbl.addCol "score" scores
  assertEq "addCol cols" (← extended.numCols) 3
  let sc ← (← extended.col "score") |>.castFloat64
  assertEq "addCol score[0]" (← sc[0]) (some 9.5)
  IO.println "  table: ok"

def testExtendedArith : IO Unit := do
  let a ← Col.float64s #[some (-3.0), some 4.0, some (-5.0)]
  let absA ← Col.abs a
  assertEq "abs[0]" (← absA[0]) (some 3.0)
  assertEq "abs[2]" (← absA[2]) (some 5.0)

  let signA ← Col.sign a
  assertEq "sign[0]" (← signA[0]) (some (-1.0))
  assertEq "sign[1]" (← signA[1]) (some 1.0)

  let b ← Col.float64s #[some 9.0, some 16.0, some 25.0]
  let sqrtB ← Col.sqrt b
  assertEq "sqrt[0]" (← sqrtB[0]) (some 3.0)
  assertEq "sqrt[1]" (← sqrtB[1]) (some 4.0)

  let base ← Col.float64s #[some 2.0, some 3.0]
  let exp ← Col.float64s #[some 3.0, some 2.0]
  let pow ← Col.power base exp
  assertEq "power[0]" (← pow[0]) (some 8.0)
  assertEq "power[1]" (← pow[1]) (some 9.0)

  let c ← Col.float64s #[some 1.5, some 2.7, some (-1.3)]
  assertEq "ceil[0]" (← (Col.ceil c)[0]) (some 2.0)
  assertEq "floor[1]" (← (Col.floor c)[1]) (some 2.0)
  assertEq "trunc[2]" (← (Col.trunc c)[2]) (some (-1.0))
  IO.println "  extended arith: ok"

def testMath : IO Unit := do
  let a ← Col.float64s #[some 0.0, some 1.0]
  assertEq "sin[0]" (← (Col.sin a)[0]) (some 0.0)
  assertEq "cos[0]" (← (Col.cos a)[0]) (some 1.0)
  assertEq "tan[0]" (← (Col.tan a)[0]) (some 0.0)

  let b ← Col.float64s #[some 1.0]
  assertEq "ln[0]" (← (Col.ln b)[0]) (some 0.0)
  assertEq "log2[0]" (← (Col.log2 b)[0]) (some 0.0)
  assertEq "log10[0]" (← (Col.log10 b)[0]) (some 0.0)
  assertEq "log1p[0]" (← (Col.log1p (← Col.float64s #[some 0.0]))[0]) (some 0.0)

  let c ← Col.float64s #[some 0.0]
  assertEq "asin[0]" (← (Col.asin c)[0]) (some 0.0)
  assertEq "acos[0]" (← (Col.acos (← Col.float64s #[some 1.0]))[0]) (some 0.0)
  assertEq "atan[0]" (← (Col.atan c)[0]) (some 0.0)

  -- atan2
  let y ← Col.float64s #[some 1.0, some 0.0]
  let x ← Col.float64s #[some 0.0, some 1.0]
  let at2 ← Col.atan2 y x
  -- atan2(1,0) ≈ π/2, atan2(0,1) = 0
  match ← at2[0] with
  | some v => unless (v > 1.57 && v < 1.58) do throw (.userError s!"atan2[0]: got {v}")
  | none => throw (.userError "atan2[0]: got none")
  assertEq "atan2[1]" (← at2[1]) (some 0.0)
  IO.println "  math: ok"

def testBitwise : IO Unit := do
  let a ← Col.int64s #[some 0b1100, some 0b1010]
  let b ← Col.int64s #[some 0b1010, some 0b1100]
  assertEq "bitAnd[0]" (← (Col.bitAnd a b)[0]) (some 0b1000)
  assertEq "bitOr[0]" (← (Col.bitOr a b)[0]) (some 0b1110)
  assertEq "bitXor[0]" (← (Col.bitXor a b)[0]) (some 0b0110)
  assertEq "bitNot[0]" (← (Col.bitNot a)[0]) (some (-13)) -- ~0b1100 = ...10011 = -13

  let c ← Col.int64s #[some 1, some 4]
  let s ← Col.int64s #[some 2, some 1]
  assertEq "shiftLeft[0]" (← (Col.shiftLeft c s)[0]) (some 4)
  assertEq "shiftRight[1]" (← (Col.shiftRight c s)[1]) (some 2)
  IO.println "  bitwise: ok"

def testNullOps : IO Unit := do
  let a ← Col.int64s #[some 1, none, some 3]
  let nullMask ← Col.isNulls a
  assertEq "isNulls[0]" (← nullMask[0]) (some false)
  assertEq "isNulls[1]" (← nullMask[1]) (some true)
  let validMask ← Col.isValids a
  assertEq "isValids[0]" (← validMask[0]) (some true)
  assertEq "isValids[1]" (← validMask[1]) (some false)

  let dropped ← Col.dropNull a
  assertEq "dropNull len" (← dropped.len) 2
  assertEq "dropNull[0]" (← dropped[0]) (some 1)
  assertEq "dropNull[1]" (← dropped[1]) (some 3)

  let fill ← Col.int64s #[some 99, some 99, some 99]
  let filled ← Col.fillNull a fill
  assertEq "fillNull[0]" (← filled[0]) (some 1)
  assertEq "fillNull[1]" (← filled[1]) (some 99)
  assertEq "fillNull[2]" (← filled[2]) (some 3)

  -- ifElse
  let mask ← Col.bools #[some true, some false, some true]
  let x ← Col.int64s #[some 10, some 20, some 30]
  let y ← Col.int64s #[some 100, some 200, some 300]
  let result ← Col.ifElse mask x y
  assertEq "ifElse[0]" (← result[0]) (some 10)
  assertEq "ifElse[1]" (← result[1]) (some 200)
  assertEq "ifElse[2]" (← result[2]) (some 30)

  -- isIn
  let vals ← Col.int64s #[some 1, some 2, some 3, some 4, some 5]
  let set ← Col.int64s #[some 2, some 4]
  let inSet ← Col.isIn vals set
  assertEq "isIn[0]" (← inSet[0]) (some false)
  assertEq "isIn[1]" (← inSet[1]) (some true)
  assertEq "isIn[3]" (← inSet[3]) (some true)
  assertEq "isIn[4]" (← inSet[4]) (some false)

  -- slice
  let sliced ← Col.slice vals 1 3
  assertEq "slice len" (← sliced.len) 3
  assertEq "slice[0]" (← sliced[0]) (some 2)
  assertEq "slice[2]" (← sliced[2]) (some 4)

  -- isNan / isInf / isFinite
  let f ← Col.float64s #[some (0.0/0.0), some (1.0/0.0), some 1.0]
  assertEq "isNan[0]" (← (Col.isNan f)[0]) (some true)
  assertEq "isNan[2]" (← (Col.isNan f)[2]) (some false)
  assertEq "isInf[1]" (← (Col.isInf f)[1]) (some true)
  assertEq "isInf[2]" (← (Col.isInf f)[2]) (some false)
  assertEq "isFinite[2]" (← (Col.isFinite f)[2]) (some true)
  assertEq "isFinite[0]" (← (Col.isFinite f)[0]) (some false)
  IO.println "  null/cond/set ops: ok"

def testStringOps : IO Unit := do
  let s ← Col.strings #[some "Hello", some "World", some "foo"]
  assertEq "upper[0]" (← (Col.upper s)[0]) (some "HELLO")
  assertEq "lower[1]" (← (Col.lower s)[1]) (some "world")
  assertEq "reverse[2]" (← (Col.reverse s)[2]) (some "oof")

  let lens ← Col.strLen s
  assertEq "strLen[0]" (← lens[0]) (some (5 : Int32))
  assertEq "strLen[2]" (← lens[2]) (some (3 : Int32))

  let padded ← Col.strings #[some "  hello  ", some " world "]
  let trimmed ← Col.trim padded " "
  assertEq "trim[0]" (← trimmed[0]) (some "hello")
  assertEq "trim[1]" (← trimmed[1]) (some "world")

  let words ← Col.strings #[some "foobar", some "bazqux", some "hello"]
  assertEq "startsWith[0]" (← (Col.startsWith words "foo")[0]) (some true)
  assertEq "startsWith[1]" (← (Col.startsWith words "foo")[1]) (some false)
  assertEq "endsWith[0]" (← (Col.endsWith words "bar")[0]) (some true)
  assertEq "contains[1]" (← (Col.contains words "qux")[1]) (some true)
  assertEq "contains[2]" (← (Col.contains words "qux")[2]) (some false)

  let replaced ← Col.replace words "foo" "FOO"
  assertEq "replace[0]" (← replaced[0]) (some "FOObar")
  assertEq "replace[1]" (← replaced[1]) (some "bazqux")
  IO.println "  string ops: ok"

def testTemporal : IO Unit := do
  -- 90061 = 1 day + 1 hour + 1 minute + 1 second = 1970-01-02 01:01:01 UTC (Thursday, day 2 of year)
  let ts ← Col.timestampSs #[some 90061]
  assertEq "year" (← (Col.year ts)[0]) (some (1970 : Int64))
  assertEq "month" (← (Col.month ts)[0]) (some (1 : Int64))
  assertEq "day" (← (Col.day ts)[0]) (some (2 : Int64))
  assertEq "dayOfWeek" (← (Col.dayOfWeek ts)[0]) (some (4 : Int64)) -- Friday=4 (Mon=0)
  assertEq "dayOfYear" (← (Col.dayOfYear ts)[0]) (some (2 : Int64))
  assertEq "hour" (← (Col.hour ts)[0]) (some (1 : Int64))
  assertEq "minute" (← (Col.minute ts)[0]) (some (1 : Int64))
  assertEq "second" (← (Col.second ts)[0]) (some (1 : Int64))

  -- sub-second temporal: 1710495045123456789 ns = 2024-03-15 11:30:45.123456789
  let tsns ← Col.timestampNss #[some 1710495045123456789]
  assertEq "millisecond" (← (Col.millisecond tsns)[0]) (some (123 : Int64))
  assertEq "microsecond" (← (Col.microsecond tsns)[0]) (some (456 : Int64))
  assertEq "nanosecond" (← (Col.nanosecond tsns)[0]) (some (789 : Int64))
  IO.println "  temporal: ok"

def testMoreAggregation : IO Unit := do
  let a ← Col.int64s #[some 2, some 4, some 6]
  assertEq "product" (← (← Col.product a).toInt64) (some 48)

  let b ← Col.float64s #[some 2.0, some 4.0, some 6.0]
  -- variance of [2,4,6] = ((2-4)^2 + (4-4)^2 + (6-4)^2) / 3 = 8/3 ≈ 2.666...
  let v ← (← Col.variance b).toFloat64
  -- just check it's Some and roughly correct
  match v with
  | some vv => unless (vv > 2.6 && vv < 2.7) do throw (.userError s!"variance: got {vv}")
  | none => throw (.userError "variance: got none")

  let sd ← (← Col.stddev b).toFloat64
  match sd with
  | some sv => unless (sv > 1.6 && sv < 1.7) do throw (.userError s!"stddev: got {sv}")
  | none => throw (.userError "stddev: got none")

  let med ← (← Col.approxMedian b).toFloat64
  assertEq "approxMedian" med (some 4.0)

  -- cumulative sum
  let c ← Col.int64s #[some 1, some 2, some 3, some 4]
  let cs ← Col.cumulativeSum c
  assertEq "cumSum[0]" (← cs[0]) (some 1)
  assertEq "cumSum[1]" (← cs[1]) (some 3)
  assertEq "cumSum[2]" (← cs[2]) (some 6)
  assertEq "cumSum[3]" (← cs[3]) (some 10)
  IO.println "  more aggregation: ok"

def testAllTypes : IO Unit := do
  -- int8
  let i8 ← Col.int8s #[some (1 : Int8), none, some (-1 : Int8)]
  assertEq "int8 len" (← i8.len) 3
  assertEq "int8[0]" (← i8[0]) (some (1 : Int8))
  assertEq "int8[1]" (← i8[1]) none
  assertEq "int8[2]" (← i8[2]) (some (-1 : Int8))
  -- int16
  let i16 ← Col.int16s #[some (100 : Int16), none]
  assertEq "int16[0]" (← i16[0]) (some (100 : Int16))
  assertEq "int16[1]" (← i16[1]) none
  -- int32
  let i32 ← Col.int32s #[some (1000 : Int32), none]
  assertEq "int32[0]" (← i32[0]) (some (1000 : Int32))
  assertEq "int32[1]" (← i32[1]) none
  -- uint8
  let u8 ← Col.uint8s #[some (255 : UInt8), none]
  assertEq "uint8[0]" (← u8[0]) (some (255 : UInt8))
  assertEq "uint8[1]" (← u8[1]) none
  -- uint16
  let u16 ← Col.uint16s #[some (1000 : UInt16), none]
  assertEq "uint16[0]" (← u16[0]) (some (1000 : UInt16))
  assertEq "uint16[1]" (← u16[1]) none
  -- uint32
  let u32 ← Col.uint32s #[some (100000 : UInt32), none]
  assertEq "uint32[0]" (← u32[0]) (some (100000 : UInt32))
  assertEq "uint32[1]" (← u32[1]) none
  -- uint64
  let u64 ← Col.uint64s #[some (999999 : UInt64), none]
  assertEq "uint64[0]" (← u64[0]) (some (999999 : UInt64))
  assertEq "uint64[1]" (← u64[1]) none
  -- float32
  let f32 ← Col.float32s #[some (1.5 : Float32), none]
  assertEq "float32[0]" (← f32[0]) (some (1.5 : Float32))
  assertEq "float32[1]" (← f32[1]) none
  -- date32 (days since epoch)
  let d32 ← Col.date32s #[some (0 : Int32), some (1 : Int32), none]
  assertEq "date32[0]" (← d32[0]) (some (0 : Int32))
  assertEq "date32[1]" (← d32[1]) (some (1 : Int32))
  assertEq "date32[2]" (← d32[2]) none
  -- date64 (ms since epoch)
  let d64 ← Col.date64s #[some (86400000 : Int64), none]
  assertEq "date64[0]" (← d64[0]) (some (86400000 : Int64))
  assertEq "date64[1]" (← d64[1]) none
  -- timestamp_ms
  let tsms ← Col.timestampMss #[some (1000 : Int64), none]
  assertEq "ts_ms[0]" (← tsms[0]) (some (1000 : Int64))
  assertEq "ts_ms[1]" (← tsms[1]) none
  -- timestamp_us
  let tsus ← Col.timestampUss #[some (1000000 : Int64), none]
  assertEq "ts_us[0]" (← tsus[0]) (some (1000000 : Int64))
  assertEq "ts_us[1]" (← tsus[1]) none
  -- duration_s
  let durs ← Col.durationSs #[some (60 : Int64), none]
  assertEq "dur_s[0]" (← durs[0]) (some (60 : Int64))
  assertEq "dur_s[1]" (← durs[1]) none
  -- duration_ms
  let durms ← Col.durationMss #[some (1000 : Int64), none]
  assertEq "dur_ms[0]" (← durms[0]) (some (1000 : Int64))
  assertEq "dur_ms[1]" (← durms[1]) none
  -- duration_us
  let durus ← Col.durationUss #[some (1000000 : Int64), none]
  assertEq "dur_us[0]" (← durus[0]) (some (1000000 : Int64))
  assertEq "dur_us[1]" (← durus[1]) none
  -- duration_ns
  let durns ← Col.durationNss #[some (1000000000 : Int64), none]
  assertEq "dur_ns[0]" (← durns[0]) (some (1000000000 : Int64))
  assertEq "dur_ns[1]" (← durns[1]) none
  -- time32s (seconds within day)
  let t32s ← Col.time32Ss #[some (3661 : Int32), none]
  assertEq "time32s[0]" (← t32s[0]) (some (3661 : Int32))
  assertEq "time32s[1]" (← t32s[1]) none
  -- time32ms
  let t32ms ← Col.time32Mss #[some (3661000 : Int32), none]
  assertEq "time32ms[0]" (← t32ms[0]) (some (3661000 : Int32))
  assertEq "time32ms[1]" (← t32ms[1]) none
  -- time64us
  let t64us ← Col.time64Uss #[some (3661000000 : Int64), none]
  assertEq "time64us[0]" (← t64us[0]) (some (3661000000 : Int64))
  assertEq "time64us[1]" (← t64us[1]) none
  -- time64ns
  let t64ns ← Col.time64Nss #[some (3661000000000 : Int64), none]
  assertEq "time64ns[0]" (← t64ns[0]) (some (3661000000000 : Int64))
  assertEq "time64ns[1]" (← t64ns[1]) none
  IO.println "  all types: ok"

def testValAccessors : IO Unit := do
  -- Val.toInt64
  let intVal ← Col.sum (← Col.int64s #[some 10, some 20])
  assertEq "val toInt64" (← intVal.toInt64) (some 30)
  -- Val.toFloat64
  let floatVal ← Col.sum (← Col.float64s #[some 1.5, some 2.5])
  assertEq "val toFloat64" (← floatVal.toFloat64) (some 4.0)
  -- Val.toBool (min of bool col → Val .bool)
  let boolVal ← Col.min (← Col.bools #[some true, some false])
  assertEq "val toBool" (← boolVal.toBool) (some false)
  -- Val.toStr (min of string col → Val .string)
  let strVal ← Col.min (← Col.strings #[some "cherry", some "apple", some "banana"])
  assertEq "val toStr" (← strVal.toStr) (some "apple")
  -- Val.toString (generic string repr)
  let repr ← intVal.toString
  unless repr.length > 0 do throw (.userError "Val.toString: empty")
  -- Val.isValid on valid value
  assertEq "val isValid" (← intVal.isValid) true
  -- Val.isValid on null value (sum of all-null col)
  let nullVal ← Col.sum (← Col.int64s #[none, none])
  assertEq "null val isValid" (← nullVal.isValid) false
  IO.println "  val accessors: ok"

def testCast : IO Unit := do
  let ints ← Col.int64s #[some 1, some 2, some 3]
  let floats ← Col.cast .float64 ints
  assertEq "cast[0]" (← floats[0]) (some 1.0)
  assertEq "cast[2]" (← floats[2]) (some 3.0)
  IO.println "  cast: ok"

def main : IO Unit := do
  IO.println "=== Arrow Test Suite ==="
  testConstruction
  testArithmetic
  testComparison
  testVectorOps
  testAggregation
  testChained
  testTable
  testExtendedArith
  testMath
  testBitwise
  testNullOps
  testStringOps
  testTemporal
  testMoreAggregation
  testCast
  testAllTypes
  testValAccessors
  IO.println "=== all passed ==="
