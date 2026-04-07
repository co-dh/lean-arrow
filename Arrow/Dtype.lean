namespace Arrow

inductive Dtype where
  | bool
  | int8 | int16 | int32 | int64
  | uint8 | uint16 | uint32 | uint64
  | float32 | float64
  | string | binary
  | date32 | date64
  | time32s | time32ms | time64us | time64ns
  | timestamp_s | timestamp_ms | timestamp_us | timestamp_ns
  | duration_s | duration_ms | duration_us | duration_ns
  deriving Repr, BEq, Inhabited

-- Lean host type for each Dtype
@[reducible] def Dtype.Lean : Dtype → Type
  | .bool => Bool
  | .int8 => Int8 | .int16 => Int16 | .int32 => Int32 | .int64 => Int64
  | .uint8 => UInt8 | .uint16 => UInt16 | .uint32 => UInt32 | .uint64 => UInt64
  | .float32 => Float32 | .float64 => Float
  | .string => String | .binary => ByteArray
  | .date32 => Int32 | .date64 => Int64
  | .time32s | .time32ms => Int32
  | .time64us | .time64ns => Int64
  | .timestamp_s | .timestamp_ms | .timestamp_us | .timestamp_ns => Int64
  | .duration_s | .duration_ms | .duration_us | .duration_ns => Int64

-- Numeric types: support arithmetic
class IsNumeric (d : Dtype) where
instance : IsNumeric .int8 where
instance : IsNumeric .int16 where
instance : IsNumeric .int32 where
instance : IsNumeric .int64 where
instance : IsNumeric .uint8 where
instance : IsNumeric .uint16 where
instance : IsNumeric .uint32 where
instance : IsNumeric .uint64 where
instance : IsNumeric .float32 where
instance : IsNumeric .float64 where
instance : IsNumeric .duration_s where
instance : IsNumeric .duration_ms where
instance : IsNumeric .duration_us where
instance : IsNumeric .duration_ns where

-- Integral types: support bitwise operations
class IsIntegral (d : Dtype) where
instance : IsIntegral .int8 where
instance : IsIntegral .int16 where
instance : IsIntegral .int32 where
instance : IsIntegral .int64 where
instance : IsIntegral .uint8 where
instance : IsIntegral .uint16 where
instance : IsIntegral .uint32 where
instance : IsIntegral .uint64 where

-- Orderable types: support comparison and sort
class IsOrd (d : Dtype) where
instance : IsOrd .bool where
instance : IsOrd .int8 where
instance : IsOrd .int16 where
instance : IsOrd .int32 where
instance : IsOrd .int64 where
instance : IsOrd .uint8 where
instance : IsOrd .uint16 where
instance : IsOrd .uint32 where
instance : IsOrd .uint64 where
instance : IsOrd .float32 where
instance : IsOrd .float64 where
instance : IsOrd .string where
instance : IsOrd .date32 where
instance : IsOrd .date64 where
instance : IsOrd .time32s where
instance : IsOrd .time32ms where
instance : IsOrd .time64us where
instance : IsOrd .time64ns where
instance : IsOrd .timestamp_s where
instance : IsOrd .timestamp_ms where
instance : IsOrd .timestamp_us where
instance : IsOrd .timestamp_ns where
instance : IsOrd .duration_s where
instance : IsOrd .duration_ms where
instance : IsOrd .duration_us where
instance : IsOrd .duration_ns where

-- Temporal types
class IsTemporal (d : Dtype) where
instance : IsTemporal .date32 where
instance : IsTemporal .date64 where
instance : IsTemporal .time32s where
instance : IsTemporal .time32ms where
instance : IsTemporal .time64us where
instance : IsTemporal .time64ns where
instance : IsTemporal .timestamp_s where
instance : IsTemporal .timestamp_ms where
instance : IsTemporal .timestamp_us where
instance : IsTemporal .timestamp_ns where
instance : IsTemporal .duration_s where
instance : IsTemporal .duration_ms where
instance : IsTemporal .duration_us where
instance : IsTemporal .duration_ns where

end Arrow
