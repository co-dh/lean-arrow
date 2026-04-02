import Arrow.Col

namespace Arrow

-- Opaque scalar value indexed by Dtype
opaque Val.Pointed (d : Dtype) : NonemptyType
def Val (d : Dtype) : Type := (Val.Pointed d).type
instance : Nonempty (Val d) := (Val.Pointed d).property

-- Aggregation functions producing scalars
@[extern "lean_arrow_sum"]
opaque Col.sum [IsNumeric d] : @& Col d → IO (Val d)
@[extern "lean_arrow_min_val"]
opaque Col.min [IsOrd d] : @& Col d → IO (Val d)
@[extern "lean_arrow_max_val"]
opaque Col.max [IsOrd d] : @& Col d → IO (Val d)
@[extern "lean_arrow_mean"]
opaque Col.mean [IsNumeric d] : @& Col d → IO (Val .float64)
@[extern "lean_arrow_count"]
opaque Col.count : @& Col d → IO Nat
@[extern "lean_arrow_count_distinct"]
opaque Col.countDistinct : @& Col d → IO Nat

-- Scalar extraction
@[extern "lean_arrow_val_to_string"]
opaque Val.toString : @& Val d → IO String
@[extern "lean_arrow_val_is_valid"]
opaque Val.isValid : @& Val d → IO Bool
@[extern "lean_arrow_val_get_int64"]
opaque Val.toInt64 : @& Val .int64 → IO (Option Int64)
@[extern "lean_arrow_val_get_float64"]
opaque Val.toFloat64 : @& Val .float64 → IO (Option Float)
@[extern "lean_arrow_val_get_bool"]
opaque Val.toBool : @& Val .bool → IO (Option Bool)
@[extern "lean_arrow_val_get_string"]
opaque Val.toStr : @& Val .string → IO (Option String)

private unsafe def Val.toStringUnsafe (v : Val d) : String :=
  match unsafeIO (Val.toString v) with | .ok s => s | .error _ => "<val>"
@[implemented_by Val.toStringUnsafe]
private opaque Val.toStringPure : Val d → String
instance : ToString (Val d) where toString := Val.toStringPure

end Arrow
