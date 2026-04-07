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

-- Generic element access — dispatches to typed getter via Arrow type_id
@[extern "lean_arrow_col_get"]
opaque Col.get : @& Col d → @& UInt64 → IO (Option d.Lean)

instance : GetElem (Col d) Nat (IO (Option d.Lean)) (fun _ _ => True) where
  getElem c i _ := Col.get c i.toUInt64

instance : GetElem (IO (Col d)) Nat (IO (Option d.Lean)) (fun _ _ => True) where
  getElem c i _ := do (← c).get i.toUInt64

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
@[extern "lean_arrow_abs"]
opaque Col.abs [IsNumeric d] : @& Col d → IO (Col d)
@[extern "lean_arrow_power"]
opaque Col.power [IsNumeric d] : @& Col d → @& Col d → IO (Col d)
@[extern "lean_arrow_sqrt"]
opaque Col.sqrt [IsNumeric d] : @& Col d → IO (Col d)
@[extern "lean_arrow_sign"]
opaque Col.sign [IsNumeric d] : @& Col d → IO (Col d)
@[extern "lean_arrow_ceil"]
opaque Col.ceil [IsNumeric d] : @& Col d → IO (Col d)
@[extern "lean_arrow_floor"]
opaque Col.floor [IsNumeric d] : @& Col d → IO (Col d)
@[extern "lean_arrow_trunc"]
opaque Col.trunc [IsNumeric d] : @& Col d → IO (Col d)

-- Math/trig (operate on float columns; Arrow errors on int input)
@[extern "lean_arrow_sin"]
opaque Col.sin [IsNumeric d] : @& Col d → IO (Col d)
@[extern "lean_arrow_cos"]
opaque Col.cos [IsNumeric d] : @& Col d → IO (Col d)
@[extern "lean_arrow_tan"]
opaque Col.tan [IsNumeric d] : @& Col d → IO (Col d)
@[extern "lean_arrow_asin"]
opaque Col.asin [IsNumeric d] : @& Col d → IO (Col d)
@[extern "lean_arrow_acos"]
opaque Col.acos [IsNumeric d] : @& Col d → IO (Col d)
@[extern "lean_arrow_atan"]
opaque Col.atan [IsNumeric d] : @& Col d → IO (Col d)
@[extern "lean_arrow_atan2"]
opaque Col.atan2 [IsNumeric d] : @& Col d → @& Col d → IO (Col d)
@[extern "lean_arrow_ln"]
opaque Col.ln [IsNumeric d] : @& Col d → IO (Col d)
@[extern "lean_arrow_log2"]
opaque Col.log2 [IsNumeric d] : @& Col d → IO (Col d)
@[extern "lean_arrow_log10"]
opaque Col.log10 [IsNumeric d] : @& Col d → IO (Col d)
@[extern "lean_arrow_log1p"]
opaque Col.log1p [IsNumeric d] : @& Col d → IO (Col d)

-- Bitwise (integer types only)
@[extern "lean_arrow_bit_and"]
opaque Col.bitAnd [IsIntegral d] : @& Col d → @& Col d → IO (Col d)
@[extern "lean_arrow_bit_or"]
opaque Col.bitOr [IsIntegral d] : @& Col d → @& Col d → IO (Col d)
@[extern "lean_arrow_bit_xor"]
opaque Col.bitXor [IsIntegral d] : @& Col d → @& Col d → IO (Col d)
@[extern "lean_arrow_bit_not"]
opaque Col.bitNot [IsIntegral d] : @& Col d → IO (Col d)
@[extern "lean_arrow_shift_left"]
opaque Col.shiftLeft [IsIntegral d] : @& Col d → @& Col d → IO (Col d)
@[extern "lean_arrow_shift_right"]
opaque Col.shiftRight [IsIntegral d] : @& Col d → @& Col d → IO (Col d)

instance [IsNumeric d] : HAdd (IO (Col d)) (IO (Col d)) (IO (Col d)) where hAdd a b := do Col.add (← a) (← b)
instance [IsNumeric d] : HSub (IO (Col d)) (IO (Col d)) (IO (Col d)) where hSub a b := do Col.sub (← a) (← b)
instance [IsNumeric d] : HMul (IO (Col d)) (IO (Col d)) (IO (Col d)) where hMul a b := do Col.mul (← a) (← b)
instance [IsNumeric d] : HDiv (IO (Col d)) (IO (Col d)) (IO (Col d)) where hDiv a b := do Col.div (← a) (← b)

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

-- IO-level comparison operators (element-wise → Col .bool)
def Col.eqIO (a b : IO (Col d)) : IO (Col .bool) := do Col.eq (← a) (← b)
def Col.neqIO (a b : IO (Col d)) : IO (Col .bool) := do Col.neq (← a) (← b)
def Col.ltIO [IsOrd d] (a b : IO (Col d)) : IO (Col .bool) := do Col.lt (← a) (← b)
def Col.gtIO [IsOrd d] (a b : IO (Col d)) : IO (Col .bool) := do Col.gt (← a) (← b)
def Col.lteIO [IsOrd d] (a b : IO (Col d)) : IO (Col .bool) := do Col.lte (← a) (← b)
def Col.gteIO [IsOrd d] (a b : IO (Col d)) : IO (Col .bool) := do Col.gte (← a) (← b)
infixl:50 " =. " => Col.eqIO
infixl:50 " ≠. " => Col.neqIO
infixl:50 " <. " => Col.ltIO
infixl:50 " >. " => Col.gtIO
infixl:50 " ≤. " => Col.lteIO
infixl:50 " ≥. " => Col.gteIO

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

-- Validity / null handling
@[extern "lean_arrow_is_nulls"]
opaque Col.isNulls : @& Col d → IO (Col .bool)
@[extern "lean_arrow_is_valids"]
opaque Col.isValids : @& Col d → IO (Col .bool)
@[extern "lean_arrow_is_nan"]
opaque Col.isNan [IsNumeric d] : @& Col d → IO (Col .bool)
@[extern "lean_arrow_is_inf"]
opaque Col.isInf [IsNumeric d] : @& Col d → IO (Col .bool)
@[extern "lean_arrow_is_finite"]
opaque Col.isFinite [IsNumeric d] : @& Col d → IO (Col .bool)
@[extern "lean_arrow_drop_null"]
opaque Col.dropNull : @& Col d → IO (Col d)
@[extern "lean_arrow_fill_null"]
opaque Col.fillNull : @& Col d → @& Col d → IO (Col d)

-- Conditional
@[extern "lean_arrow_if_else"]
opaque Col.ifElse : @& Col .bool → @& Col d → @& Col d → IO (Col d)

-- Set membership
@[extern "lean_arrow_is_in"]
opaque Col.isIn : @& Col d → @& Col d → IO (Col .bool)

-- String operations (monomorphic on Col .string)
@[extern "lean_arrow_str_upper"]
opaque Col.upper : @& Col .string → IO (Col .string)
@[extern "lean_arrow_str_lower"]
opaque Col.lower : @& Col .string → IO (Col .string)
@[extern "lean_arrow_str_length"]
opaque Col.strLen : @& Col .string → IO (Col .int32)
@[extern "lean_arrow_str_reverse"]
opaque Col.reverse : @& Col .string → IO (Col .string)
@[extern "lean_arrow_str_trim"]
opaque Col.trim : @& Col .string → @& String → IO (Col .string)
@[extern "lean_arrow_str_starts_with"]
opaque Col.startsWith : @& Col .string → @& String → IO (Col .bool)
@[extern "lean_arrow_str_ends_with"]
opaque Col.endsWith : @& Col .string → @& String → IO (Col .bool)
@[extern "lean_arrow_str_contains"]
opaque Col.contains : @& Col .string → @& String → IO (Col .bool)
@[extern "lean_arrow_str_replace"]
opaque Col.replace : @& Col .string → @& String → @& String → IO (Col .string)

-- Temporal extraction (IsTemporal → Col .int64)
@[extern "lean_arrow_year"]
opaque Col.year [IsTemporal d] : @& Col d → IO (Col .int64)
@[extern "lean_arrow_month"]
opaque Col.month [IsTemporal d] : @& Col d → IO (Col .int64)
@[extern "lean_arrow_day"]
opaque Col.day [IsTemporal d] : @& Col d → IO (Col .int64)
@[extern "lean_arrow_day_of_week"]
opaque Col.dayOfWeek [IsTemporal d] : @& Col d → IO (Col .int64)
@[extern "lean_arrow_day_of_year"]
opaque Col.dayOfYear [IsTemporal d] : @& Col d → IO (Col .int64)
@[extern "lean_arrow_hour"]
opaque Col.hour [IsTemporal d] : @& Col d → IO (Col .int64)
@[extern "lean_arrow_minute"]
opaque Col.minute [IsTemporal d] : @& Col d → IO (Col .int64)
@[extern "lean_arrow_second"]
opaque Col.second [IsTemporal d] : @& Col d → IO (Col .int64)
@[extern "lean_arrow_millisecond"]
opaque Col.millisecond [IsTemporal d] : @& Col d → IO (Col .int64)
@[extern "lean_arrow_microsecond"]
opaque Col.microsecond [IsTemporal d] : @& Col d → IO (Col .int64)
@[extern "lean_arrow_nanosecond"]
opaque Col.nanosecond [IsTemporal d] : @& Col d → IO (Col .int64)

-- Cumulative
@[extern "lean_arrow_cumulative_sum"]
opaque Col.cumulativeSum [IsNumeric d] : @& Col d → IO (Col d)

-- Slice / cast
@[extern "lean_arrow_slice"]
opaque Col.slice : @& Col d → @& UInt64 → @& UInt64 → IO (Col d)
@[extern "lean_arrow_cast"]
opaque Col.cast (d2 : Dtype) : @& Col d → IO (Col d2)

-- ---------------------------------------------------------------------------
-- Array primitives (for APL compiler support)
-- ---------------------------------------------------------------------------

-- iota: [0, 1, ..., n-1]
@[extern "lean_arrow_iota"]
opaque Col.iota : @& UInt64 → IO (Col .int64)

-- where: bool mask → indices where true
@[extern "lean_arrow_where"]
opaque Col.where : @& Col .bool → IO (Col .int64)

-- indexOf: for each element of needles, position in haystack (null if absent)
@[extern "lean_arrow_index_of"]
opaque Col.indexOf : @& Col d → @& Col d → IO (Col .int32)

-- scatter: result[indices[i]] = values[i], else from original
@[extern "lean_arrow_scatter"]
opaque Col.scatter : @& Col d → @& Col .int64 → @& Col d → IO (Col d)

-- Logical ops on bool columns
@[extern "lean_arrow_log_and"]
opaque Col.logAnd : @& Col .bool → @& Col .bool → IO (Col .bool)
@[extern "lean_arrow_log_or"]
opaque Col.logOr : @& Col .bool → @& Col .bool → IO (Col .bool)
@[extern "lean_arrow_log_xor"]
opaque Col.logXor : @& Col .bool → @& Col .bool → IO (Col .bool)
@[extern "lean_arrow_log_not"]
opaque Col.logNot : @& Col .bool → IO (Col .bool)

-- Cumulative boolean scans
@[extern "lean_arrow_cumulative_xor"]
opaque Col.cumulativeXor : @& Col .bool → IO (Col .bool)
@[extern "lean_arrow_cumulative_and"]
opaque Col.cumulativeAnd : @& Col .bool → IO (Col .bool)
@[extern "lean_arrow_cumulative_or"]
opaque Col.cumulativeOr : @& Col .bool → IO (Col .bool)

-- reverse (generic)
@[extern "lean_arrow_reverse_col"]
opaque Col.reverseCol : @& Col d → IO (Col d)

-- replicate: expand col by integer counts
@[extern "lean_arrow_replicate"]
opaque Col.replicate : @& Col d → @& Col .int64 → IO (Col d)

-- fill: constant array
@[extern "lean_arrow_fill_int64"]
opaque Col.fillInt64 : @& UInt64 → @& Int64 → IO (Col .int64)
@[extern "lean_arrow_fill_float64"]
opaque Col.fillFloat64 : @& UInt64 → @& Float → IO (Col .float64)

-- fromString: String → byte array
@[extern "lean_arrow_from_string"]
opaque Col.fromString : @& String → IO (Col .uint8)

end Arrow
