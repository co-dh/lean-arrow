import Arrow.Dtype

namespace Arrow

-- Opaque column type indexed by Dtype. The index is erased at runtime.
opaque Col.Pointed (d : Dtype) : NonemptyType
def Col (d : Dtype) : Type := (Col.Pointed d).type
instance : Nonempty (Col d) := (Col.Pointed d).property

-- Initialization (registers external classes)
@[extern "lean_arrow_init"]
private opaque initFn : IO Unit
initialize initFn

-- Construction: one extern per dtype
@[extern "lean_arrow_col_bool"]
opaque Col.bools : @& Array (Option Bool) → IO (Col .bool)
@[extern "lean_arrow_col_int8"]
opaque Col.int8s : @& Array (Option Int8) → IO (Col .int8)
@[extern "lean_arrow_col_int16"]
opaque Col.int16s : @& Array (Option Int16) → IO (Col .int16)
@[extern "lean_arrow_col_int32"]
opaque Col.int32s : @& Array (Option Int32) → IO (Col .int32)
@[extern "lean_arrow_col_int64"]
opaque Col.int64s : @& Array (Option Int64) → IO (Col .int64)
@[extern "lean_arrow_col_uint8"]
opaque Col.uint8s : @& Array (Option UInt8) → IO (Col .uint8)
@[extern "lean_arrow_col_uint16"]
opaque Col.uint16s : @& Array (Option UInt16) → IO (Col .uint16)
@[extern "lean_arrow_col_uint32"]
opaque Col.uint32s : @& Array (Option UInt32) → IO (Col .uint32)
@[extern "lean_arrow_col_uint64"]
opaque Col.uint64s : @& Array (Option UInt64) → IO (Col .uint64)
@[extern "lean_arrow_col_float32"]
opaque Col.float32s : @& Array (Option Float32) → IO (Col .float32)
@[extern "lean_arrow_col_float64"]
opaque Col.float64s : @& Array (Option Float) → IO (Col .float64)
@[extern "lean_arrow_col_strings"]
opaque Col.strings : @& Array (Option String) → IO (Col .string)

-- Temporal constructors reuse int32/int64 representation
@[extern "lean_arrow_col_date32"]
opaque Col.date32s : @& Array (Option Int32) → IO (Col .date32)
@[extern "lean_arrow_col_date64"]
opaque Col.date64s : @& Array (Option Int64) → IO (Col .date64)
@[extern "lean_arrow_col_ts_s"]
opaque Col.timestampSs : @& Array (Option Int64) → IO (Col .timestamp_s)
@[extern "lean_arrow_col_ts_ms"]
opaque Col.timestampMss : @& Array (Option Int64) → IO (Col .timestamp_ms)
@[extern "lean_arrow_col_ts_us"]
opaque Col.timestampUss : @& Array (Option Int64) → IO (Col .timestamp_us)
@[extern "lean_arrow_col_ts_ns"]
opaque Col.timestampNss : @& Array (Option Int64) → IO (Col .timestamp_ns)
@[extern "lean_arrow_col_dur_s"]
opaque Col.durationSs : @& Array (Option Int64) → IO (Col .duration_s)
@[extern "lean_arrow_col_dur_ms"]
opaque Col.durationMss : @& Array (Option Int64) → IO (Col .duration_ms)
@[extern "lean_arrow_col_dur_us"]
opaque Col.durationUss : @& Array (Option Int64) → IO (Col .duration_us)
@[extern "lean_arrow_col_dur_ns"]
opaque Col.durationNss : @& Array (Option Int64) → IO (Col .duration_ns)
@[extern "lean_arrow_col_time32s"]
opaque Col.time32Ss : @& Array (Option Int32) → IO (Col .time32s)
@[extern "lean_arrow_col_time32ms"]
opaque Col.time32Mss : @& Array (Option Int32) → IO (Col .time32ms)
@[extern "lean_arrow_col_time64us"]
opaque Col.time64Uss : @& Array (Option Int64) → IO (Col .time64us)
@[extern "lean_arrow_col_time64ns"]
opaque Col.time64Nss : @& Array (Option Int64) → IO (Col .time64ns)

-- Access (generic over dtype)
@[extern "lean_arrow_col_len"]
opaque Col.len : @& Col d → IO Nat
@[extern "lean_arrow_col_null_count"]
opaque Col.nullCount : @& Col d → IO Nat
@[extern "lean_arrow_col_is_null"]
opaque Col.isNull : @& Col d → @& UInt64 → IO Bool
@[extern "lean_arrow_col_is_valid"]
opaque Col.isValid : @& Col d → @& UInt64 → IO Bool
@[extern "lean_arrow_col_to_string"]
opaque Col.toString : @& Col d → IO String
private unsafe def Col.toStringUnsafe (c : Col d) : String :=
  match unsafeIO (Col.toString c) with | .ok s => s | .error _ => "<col>"
@[implemented_by Col.toStringUnsafe]
private opaque Col.toStringPure : Col d → String
instance : ToString (Col d) where toString := Col.toStringPure

-- Typed element access
@[extern "lean_arrow_col_get_bool"]
opaque Col.getBool : @& Col .bool → @& UInt64 → IO (Option Bool)
@[extern "lean_arrow_col_get_int8"]
opaque Col.getInt8 : @& Col .int8 → @& UInt64 → IO (Option Int8)
@[extern "lean_arrow_col_get_int16"]
opaque Col.getInt16 : @& Col .int16 → @& UInt64 → IO (Option Int16)
@[extern "lean_arrow_col_get_int32"]
opaque Col.getInt32 : @& Col .int32 → @& UInt64 → IO (Option Int32)
@[extern "lean_arrow_col_get_int64"]
opaque Col.getInt64 : @& Col .int64 → @& UInt64 → IO (Option Int64)
@[extern "lean_arrow_col_get_uint8"]
opaque Col.getUInt8 : @& Col .uint8 → @& UInt64 → IO (Option UInt8)
@[extern "lean_arrow_col_get_uint16"]
opaque Col.getUInt16 : @& Col .uint16 → @& UInt64 → IO (Option UInt16)
@[extern "lean_arrow_col_get_uint32"]
opaque Col.getUInt32 : @& Col .uint32 → @& UInt64 → IO (Option UInt32)
@[extern "lean_arrow_col_get_uint64"]
opaque Col.getUInt64 : @& Col .uint64 → @& UInt64 → IO (Option UInt64)
@[extern "lean_arrow_col_get_float32"]
opaque Col.getFloat32 : @& Col .float32 → @& UInt64 → IO (Option Float32)
@[extern "lean_arrow_col_get_float64"]
opaque Col.getFloat64 : @& Col .float64 → @& UInt64 → IO (Option Float)
@[extern "lean_arrow_col_get_string"]
opaque Col.getString : @& Col .string → @& UInt64 → IO (Option String)

-- Compute: arithmetic (numeric types only)
@[extern "lean_arrow_add"]
opaque Col.add [IsNumeric d] : @& Col d → @& Col d → IO (Col d)
@[extern "lean_arrow_sub"]
opaque Col.sub [IsNumeric d] : @& Col d → @& Col d → IO (Col d)
@[extern "lean_arrow_mul"]
opaque Col.mul [IsNumeric d] : @& Col d → @& Col d → IO (Col d)
@[extern "lean_arrow_div"]
opaque Col.div [IsNumeric d] : @& Col d → @& Col d → IO (Col d)
@[extern "lean_arrow_neg"]
opaque Col.neg [IsNumeric d] : @& Col d → IO (Col d)

-- Compute: comparison (returns bool column)
@[extern "lean_arrow_eq"]
opaque Col.eq : @& Col d → @& Col d → IO (Col .bool)
@[extern "lean_arrow_neq"]
opaque Col.neq : @& Col d → @& Col d → IO (Col .bool)
@[extern "lean_arrow_lt"]
opaque Col.lt [IsOrd d] : @& Col d → @& Col d → IO (Col .bool)
@[extern "lean_arrow_gt"]
opaque Col.gt [IsOrd d] : @& Col d → @& Col d → IO (Col .bool)
@[extern "lean_arrow_lte"]
opaque Col.lte [IsOrd d] : @& Col d → @& Col d → IO (Col .bool)
@[extern "lean_arrow_gte"]
opaque Col.gte [IsOrd d] : @& Col d → @& Col d → IO (Col .bool)

-- Compute: vector operations
@[extern "lean_arrow_filter"]
opaque Col.filter : @& Col d → @& Col .bool → IO (Col d)
@[extern "lean_arrow_take"]
opaque Col.take : @& Col d → @& Col .int64 → IO (Col d)
@[extern "lean_arrow_sort"]
opaque Col.sort [IsOrd d] : @& Col d → @& Bool → IO (Col d)
@[extern "lean_arrow_sort_indices"]
opaque Col.sortIndices [IsOrd d] : @& Col d → @& Bool → IO (Col .int64)
@[extern "lean_arrow_unique"]
opaque Col.unique : @& Col d → IO (Col d)

end Arrow
