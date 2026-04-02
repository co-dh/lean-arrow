import Arrow
open Arrow

def testBasic : IO Unit := do
  IO.println "\n--- Int64 Column ---"
  let c ← Col.int64s #[some 1, some 2, some 3, none, some 5]
  IO.println s!"col: {c}"
  IO.println s!"len: {← c.len}"
  IO.println s!"nulls: {← c.nullCount}"
  IO.println s!"[0]: {← c.getInt64 0}"
  IO.println s!"[3]: {← c.getInt64 3}"
  IO.println s!"isNull[3]: {← c.isNull 3}"
  IO.println s!"isValid[0]: {← c.isValid 0}"

  IO.println "\n--- Float64 Column ---"
  let f ← Col.float64s #[some 1.1, some 2.2, none, some 4.4]
  IO.println s!"float col: {f}"
  IO.println s!"[1]: {← f.getFloat64 1}"

  IO.println "\n--- Bool Column ---"
  let mask ← Col.bools #[some true, some false, some true]
  IO.println s!"mask: {mask}"

  IO.println "\n--- String Column ---"
  let s ← Col.strings #[some "hello", none, some "world"]
  IO.println s!"str col: {s}"
  IO.println s!"[0]: {← s.getString 0}"

def testArithmetic : IO Unit := do
  IO.println "\n--- Int64 arithmetic ---"
  let a ← Col.int64s #[some 10, some 20, some 30]
  let b ← Col.int64s #[some 1, some 2, some 3]
  IO.println s!"add: {← Col.add a b}"
  IO.println s!"sub: {← Col.sub a b}"
  IO.println s!"mul: {← Col.mul a b}"
  IO.println s!"div: {← Col.div a b}"
  IO.println s!"neg: {← Col.neg a}"

  IO.println "\n--- Float64 arithmetic ---"
  let fa ← Col.float64s #[some 1.5, some 2.5, some 3.0]
  let fb ← Col.float64s #[some 0.5, some 2.5, some 1.5]
  IO.println s!"fadd: {← Col.add fa fb}"
  IO.println s!"fsub: {← Col.sub fa fb}"
  IO.println s!"fmul: {← Col.mul fa fb}"
  IO.println s!"fdiv: {← Col.div fa fb}"
  IO.println s!"fneg: {← Col.neg fa}"

  IO.println "\n--- Null propagation ---"
  let n1 ← Col.int64s #[some 10, none, some 30]
  let n2 ← Col.int64s #[some 1, some 2, none]
  IO.println s!"add nulls: {← Col.add n1 n2}"   -- [11, null, null]
  IO.println s!"sub nulls: {← Col.sub n1 n2}"   -- [9, null, null]
  IO.println s!"mul nulls: {← Col.mul n1 n2}"   -- [10, null, null]
  IO.println s!"div nulls: {← Col.div n1 n2}"   -- [10, null, null]
  IO.println s!"neg nulls: {← Col.neg n1}"       -- [-10, null, -30]

def testComparison : IO Unit := do
  IO.println "\n--- Comparison (all ops) ---"
  let x ← Col.int64s #[some 1, some 2, some 3]
  let y ← Col.int64s #[some 2, some 2, some 1]
  IO.println s!"eq:  {← Col.eq x y}"
  IO.println s!"neq: {← Col.neq x y}"
  IO.println s!"lt:  {← Col.lt x y}"
  IO.println s!"gt:  {← Col.gt x y}"
  IO.println s!"lte: {← Col.lte x y}"
  IO.println s!"gte: {← Col.gte x y}"

  IO.println "\n--- Null comparison ---"
  let n1 ← Col.int64s #[some 10, none, some 30]
  let n2 ← Col.int64s #[some 1, some 2, none]
  IO.println s!"eq nulls:  {← Col.eq n1 n2}"
  IO.println s!"lt nulls:  {← Col.lt n1 n2}"

  IO.println "\n--- Float comparison ---"
  let fa ← Col.float64s #[some 1.5, some 2.5, some 3.0]
  let fb ← Col.float64s #[some 0.5, some 2.5, some 1.5]
  IO.println s!"flt: {← Col.lt fa fb}"
  IO.println s!"fgt: {← Col.gt fa fb}"

  IO.println "\n--- String comparison ---"
  let sa ← Col.strings #[some "apple", some "banana", some "cherry"]
  let sb ← Col.strings #[some "banana", some "banana", some "apple"]
  IO.println s!"str eq:  {← Col.eq sa sb}"
  IO.println s!"str lt:  {← Col.lt sa sb}"
  IO.println s!"str gte: {← Col.gte sa sb}"

def testVectorOps : IO Unit := do
  IO.println "\n--- Filter ---"
  let a ← Col.int64s #[some 10, some 20, some 30]
  let mask ← Col.bools #[some true, some false, some true]
  IO.println s!"filter: {← Col.filter a mask}"

  IO.println "\n--- Take ---"
  let src ← Col.int64s #[some 10, some 20, some 30, some 40, some 50]
  let idx ← Col.int64s #[some 4, some 0, some 2]
  IO.println s!"take [10..50] by [4,0,2]: {← Col.take src idx}"

  IO.println "\n--- Sort ---"
  let u ← Col.int64s #[some 30, some 10, some 20]
  IO.println s!"sorted asc:  {← Col.sort u true}"
  IO.println s!"sorted desc: {← Col.sort u false}"

  IO.println "\n--- Sort indices ---"
  IO.println s!"sort_idx asc:  {← Col.sortIndices u true}"
  IO.println s!"sort_idx desc: {← Col.sortIndices u false}"

  IO.println "\n--- Unique ---"
  let dupes ← Col.int64s #[some 1, some 2, some 1, some 3, some 2]
  IO.println s!"unique: {← Col.unique dupes}"

  IO.println "\n--- String sort + unique ---"
  let sa ← Col.strings #[some "cherry", some "apple", some "banana"]
  IO.println s!"str sorted: {← Col.sort sa true}"
  let sd ← Col.strings #[some "x", some "y", some "x", some "z"]
  IO.println s!"str unique: {← Col.unique sd}"

def testAggregation : IO Unit := do
  IO.println "\n--- Int64 aggregation ---"
  let a ← Col.int64s #[some 10, some 20, some 30]
  IO.println s!"sum:  {← Col.sum a}"
  IO.println s!"min:  {← Col.min a}"
  IO.println s!"max:  {← Col.max a}"
  IO.println s!"mean: {← Col.mean a}"
  IO.println s!"count: {← Col.count a}"

  IO.println "\n--- Float64 aggregation ---"
  let fa ← Col.float64s #[some 1.5, some 2.5, some 3.0]
  IO.println s!"fsum:  {← Col.sum fa}"
  IO.println s!"fmin:  {← Col.min fa}"
  IO.println s!"fmax:  {← Col.max fa}"
  IO.println s!"fmean: {← Col.mean fa}"

  IO.println "\n--- Aggregation with nulls ---"
  let nv ← Col.int64s #[some 10, none, some 30, none, some 50]
  IO.println s!"sum(nulls):   {← Col.sum nv}"
  IO.println s!"min(nulls):   {← Col.min nv}"
  IO.println s!"max(nulls):   {← Col.max nv}"
  IO.println s!"mean(nulls):  {← Col.mean nv}"
  IO.println s!"count(nulls): {← Col.count nv}"

  IO.println "\n--- Count distinct ---"
  let dupes ← Col.int64s #[some 1, some 2, some 1, some 3, some 2, none]
  IO.println s!"count:         {← Col.count dupes}"
  IO.println s!"countDistinct: {← Col.countDistinct dupes}"

def testChained : IO Unit := do
  IO.println "\n--- Chained: top-3 descending ---"
  let vals ← Col.int64s #[some 50, some 10, some 40, some 20, some 30]
  let si ← Col.sortIndices vals false
  let top3idx ← Col.take si (← Col.int64s #[some 0, some 1, some 2])
  IO.println s!"top-3 desc: {← Col.take vals top3idx}"

  IO.println "\n--- Chained: filter then sum ---"
  let data ← Col.int64s #[some 1, some 2, some 3, some 4, some 5]
  let gt2 ← Col.gt data (← Col.int64s #[some 2, some 2, some 2, some 2, some 2])
  let filtered ← Col.filter data gt2
  IO.println s!"sum(x > 2): {← Col.sum filtered}"

def testTable : IO Unit := do
  IO.println "\n--- Table ---"
  let ca ← (Col.int64s #[some 1, some 2, some 3]) >>= Col.erase
  let cb ← (Col.strings #[some "a", some "b", some "c"]) >>= Col.erase
  let tbl ← Tbl.make #["id", "name"] #[ca, cb]
  IO.println s!"table:\n{tbl}"
  IO.println s!"rows: {← tbl.numRows}"
  IO.println s!"cols: {← tbl.numCols}"
  IO.println s!"col names: {← tbl.colNames}"

def main : IO Unit := do
  IO.println "=== Arrow Lean Bindings Test ==="
  testBasic
  testArithmetic
  testComparison
  testVectorOps
  testAggregation
  testChained
  testTable
  IO.println "\n=== All tests passed ==="
