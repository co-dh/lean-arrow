# lean-arrow architecture

## Overview

Lean 4 bindings to Apache Arrow C++ with dependent types. `Col d` is a column indexed by `Dtype` — the type parameter
ensures at compile time that you can't add an int column to a string column, or sort a binary column. At runtime, the
index is erased and all columns are opaque pointers to `shared_ptr<arrow::Array>`.

## Layer diagram

```
Lean (Arrow/*.lean)
│  Col d, Val d, Tbl — dependent typed, compile-time safety
│  @[extern] opaque declarations
│
├─ lean_external_object ─────────────────────────────────┐
│                                                        │
C++ shim (ffi/arrow_lean.cpp, extern "C")                │
│  wrap/unwrap shared_ptr ↔ lean_external_object         │
│  delegates to arrow::compute::CallFunction             │
│                                                        │
Arrow C++ (libarrow.so, libarrow_compute.so)             │
   shared_ptr<Array>, RecordBatch, compute kernels       │
```

## Files

```
Arrow/Dtype.lean      Dtype inductive (25 types), IsNumeric/IsOrd/IsTemporal typeclasses
Arrow/Col.lean        Col d — construction, element access, arithmetic, comparison, vector ops
Arrow/Val.lean        Val d — aggregation (sum/min/max/mean/count), scalar extraction
Arrow/Tbl.lean        Tbl — RecordBatch wrapper; AnyCol for type-erased columns
Arrow.lean            re-exports all modules
ffi/arrow_lean.cpp    extern "C" shim — all FFI entry points (~500 lines)
Test.lean             smoke test exercising all operations
lakefile.lean         Lake build: compiles C++ shim, links Arrow shared libs
```

## Type design

```lean
inductive Dtype where
  | bool | int8 | int16 | int32 | int64 | uint8 | uint16 | uint32 | uint64
  | float32 | float64 | string | binary
  | date32 | date64 | time32s | time32ms | time64us | time64ns
  | timestamp_s | timestamp_ms | timestamp_us | timestamp_ns
  | duration_s | duration_ms | duration_us | duration_ns

opaque Col.Pointed (d : Dtype) : NonemptyType
def Col (d : Dtype) : Type := (Col.Pointed d).type
-- same pattern for Val d, Tbl, AnyCol

class IsNumeric (d : Dtype)   -- gates arithmetic (add/sub/mul/div/neg)
class IsOrd (d : Dtype)       -- gates comparison/sort (all types except binary)
class IsTemporal (d : Dtype)  -- temporal-specific ops (future)
```

The `d` parameter exists only at the Lean level. The compiler compiles `Dtype` to `uint8_t` and passes it to extern
functions, but the C++ shim ignores it — all columns are `shared_ptr<arrow::Array>` regardless of type.

## FFI calling convention

Lean 4's `@[extern]` convention differs from typical C FFI:

| Lean parameter               | C parameter            |
|-------------------------------|------------------------|
| (none — IO world token)       | **not passed**         |
| `{d : Dtype}` (implicit)      | `uint8_t`              |
| `[IsNumeric d]` (instance)    | `lean_object*` (ignored) |
| `@& Col d` (borrowed)         | `b_lean_obj_arg`       |
| `@& UInt64`                   | `uint64_t` (unboxed)   |
| `@& Bool`                     | `uint8_t` (unboxed)    |

To verify signatures, check the generated C in `.lake/build/ir/*.c`.

**Int64/UInt64 boxing**: values may exceed 63 bits, so use `lean_box_uint64`/`lean_unbox_uint64` (not `lean_box`/`lean_unbox`).

## C++ shim internals

**External classes** — 4 registered in `lean_arrow_init`:

| Class            | Wraps                            | Lean type |
|------------------|----------------------------------|-----------|
| `g_col_class`    | `shared_ptr<arrow::Array>`       | `Col d`   |
| `g_val_class`    | `shared_ptr<arrow::Scalar>`      | `Val d`   |
| `g_tbl_class`    | `shared_ptr<arrow::RecordBatch>` | `Tbl`     |
| `g_anycol_class` | `shared_ptr<arrow::Array>`       | `AnyCol`  |

Each stores a heap-allocated `shared_ptr` inside `lean_external_object`. The finalizer calls `delete` on the
`shared_ptr`, which decrements the Arrow refcount.

**Compute kernels** — Lean's linker doesn't run `libarrow_compute.so` static constructors, so
`lean_arrow_init` explicitly calls all 33 `RegisterXXX()` functions to populate the compute function registry.

**Linking workarounds** — Lean ships its own sysroot with bundled glibc/clang. System libraries (`libarrow.so`,
`libstdc++.so`) are linked by full path to bypass sysroot resolution. A `__libc_single_threaded` stub satisfies a
missing glibc symbol.

## Build

Requires: `sudo pacman -S arrow` (Arrow C++ 23.0, provides libarrow + libarrow_compute)

```
lake build && lake exe test
```

Lake compiles `ffi/arrow_lean.cpp` with system `c++` (not Lean's bundled clang), then static-links it into
`libleanarrow.a`. The final executable dynamically links `libarrow.so` and `libarrow_compute.so`.
