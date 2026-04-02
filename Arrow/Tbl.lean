import Arrow.Col

namespace Arrow

-- Opaque table (RecordBatch)
opaque Tbl.Pointed : NonemptyType
def Tbl : Type := Tbl.Pointed.type
instance : Nonempty Tbl := Tbl.Pointed.property

-- Existential wrapper: a column whose dtype is not statically known
-- Used for table column access where the schema isn't in the type
opaque AnyCol.Pointed : NonemptyType
def AnyCol : Type := AnyCol.Pointed.type
instance : Nonempty AnyCol := AnyCol.Pointed.property

-- Construction
@[extern "lean_arrow_tbl_make"]
opaque Tbl.make : @& Array String → @& Array AnyCol → IO Tbl

-- Erase dtype to AnyCol (needed to build tables from typed columns)
@[extern "lean_arrow_col_erase"]
opaque Col.erase : @& Col d → IO AnyCol

-- Access
@[extern "lean_arrow_tbl_num_rows"]
opaque Tbl.numRows : @& Tbl → IO Nat
@[extern "lean_arrow_tbl_num_cols"]
opaque Tbl.numCols : @& Tbl → IO Nat
@[extern "lean_arrow_tbl_col_names"]
opaque Tbl.colNames : @& Tbl → IO (Array String)
@[extern "lean_arrow_tbl_col_by_name"]
opaque Tbl.col : @& Tbl → @& String → IO AnyCol
@[extern "lean_arrow_tbl_col_by_idx"]
opaque Tbl.colIdx : @& Tbl → @& UInt64 → IO AnyCol

-- Cast AnyCol back to typed Col (runtime type check)
@[extern "lean_arrow_anycol_cast_int64"]
opaque AnyCol.castInt64 : @& AnyCol → IO (Col .int64)
@[extern "lean_arrow_anycol_cast_float64"]
opaque AnyCol.castFloat64 : @& AnyCol → IO (Col .float64)
@[extern "lean_arrow_anycol_cast_bool"]
opaque AnyCol.castBool : @& AnyCol → IO (Col .bool)
@[extern "lean_arrow_anycol_cast_string"]
opaque AnyCol.castString : @& AnyCol → IO (Col .string)

-- Operations
@[extern "lean_arrow_tbl_filter"]
opaque Tbl.filter : @& Tbl → @& Col .bool → IO Tbl
@[extern "lean_arrow_tbl_sort"]
opaque Tbl.sort : @& Tbl → @& String → @& Bool → IO Tbl
@[extern "lean_arrow_tbl_select"]
opaque Tbl.select : @& Tbl → @& Array String → IO Tbl
@[extern "lean_arrow_tbl_add_col"]
opaque Tbl.addCol : @& Tbl → @& String → @& AnyCol → IO Tbl
@[extern "lean_arrow_tbl_to_string"]
opaque Tbl.toString : @& Tbl → IO String
private unsafe def Tbl.toStringUnsafe (t : Tbl) : String :=
  match unsafeIO (Tbl.toString t) with | .ok s => s | .error _ => "<tbl>"
@[implemented_by Tbl.toStringUnsafe]
private opaque Tbl.toStringPure : Tbl → String
instance : ToString Tbl where toString := Tbl.toStringPure

end Arrow
