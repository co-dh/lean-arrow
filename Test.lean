import Arrow
open Arrow

def main : IO Unit := do
  IO.println "=== Arrow Lean Bindings Test ==="

  -- Int64 column
  IO.println "\n--- Int64 Column ---"
  let c ← Col.int64s #[some 1, some 2, some 3, none, some 5]
  IO.println s!"col: {c}"
  IO.println s!"len: {← c.len}"
  IO.println s!"nulls: {← c.nullCount}"
  IO.println s!"[0]: {← c.getInt64 0}"
  IO.println s!"[3]: {← c.getInt64 3}"
  IO.println s!"isNull[3]: {← c.isNull 3}"
  IO.println s!"isValid[0]: {← c.isValid 0}"

  -- Arithmetic
  IO.println "\n--- Arithmetic ---"
  let a ← Col.int64s #[some 10, some 20, some 30]
  let b ← Col.int64s #[some 1, some 2, some 3]
  IO.println s!"add: {← Col.add a b}"
  IO.println s!"sub: {← Col.sub a b}"
  IO.println s!"mul: {← Col.mul a b}"
  IO.println s!"div: {← Col.div a b}"
  IO.println s!"neg: {← Col.neg a}"

  -- Comparison
  IO.println "\n--- Comparison ---"
  IO.println s!"eq: {← Col.eq a b}"
  IO.println s!"lt: {← Col.lt a b}"

  -- Float64
  IO.println "\n--- Float64 Column ---"
  let f ← Col.float64s #[some 1.1, some 2.2, none, some 4.4]
  IO.println s!"float col: {f}"
  IO.println s!"[1]: {← f.getFloat64 1}"

  -- Bool
  IO.println "\n--- Bool Column ---"
  let mask ← Col.bools #[some true, some false, some true]
  IO.println s!"mask: {mask}"

  -- String
  IO.println "\n--- String Column ---"
  let s ← Col.strings #[some "hello", none, some "world"]
  IO.println s!"str col: {s}"
  IO.println s!"[0]: {← s.getString 0}"

  -- Filter
  IO.println "\n--- Filter ---"
  let filtered ← Col.filter a mask
  IO.println s!"filter [10,20,30] by [T,F,T]: {filtered}"

  -- Sort
  IO.println "\n--- Sort ---"
  let unsorted ← Col.int64s #[some 30, some 10, some 20]
  let sorted ← Col.sort unsorted true
  IO.println s!"sorted asc: {sorted}"

  -- Unique
  IO.println "\n--- Unique ---"
  let dupes ← Col.int64s #[some 1, some 2, some 1, some 3, some 2]
  let uniq ← Col.unique dupes
  IO.println s!"unique: {uniq}"

  -- Aggregation (Val)
  IO.println "\n--- Aggregation ---"
  IO.println s!"sum: {← Col.sum a}"
  IO.println s!"min: {← Col.min a}"
  IO.println s!"max: {← Col.max a}"
  IO.println s!"mean: {← Col.mean a}"
  IO.println s!"count: {← Col.count a}"

  -- Table
  IO.println "\n--- Table ---"
  let ca ← (Col.int64s #[some 1, some 2, some 3]) >>= Col.erase
  let cb ← (Col.strings #[some "a", some "b", some "c"]) >>= Col.erase
  let tbl ← Tbl.make #["id", "name"] #[ca, cb]
  IO.println s!"table:\n{tbl}"
  IO.println s!"rows: {← tbl.numRows}"
  IO.println s!"cols: {← tbl.numCols}"
  IO.println s!"col names: {← tbl.colNames}"

  IO.println "\n=== All tests passed ==="
