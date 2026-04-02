// Lean's bundled glibc lacks newer symbols that system libstdc++ references
extern "C" char __libc_single_threaded = 1;

#include <lean/lean.h>
#include <arrow/api.h>
#include <arrow/c/bridge.h>
#include <arrow/compute/api.h>
#include <sstream>

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

static lean_external_class* g_col_class = nullptr;
static lean_external_class* g_val_class = nullptr;
static lean_external_class* g_tbl_class = nullptr;
static lean_external_class* g_anycol_class = nullptr;

using ColPtr = std::shared_ptr<arrow::Array>;
using ValPtr = std::shared_ptr<arrow::Scalar>;
using TblPtr = std::shared_ptr<arrow::RecordBatch>;

static void col_fin(void* p) { delete static_cast<ColPtr*>(p); }
static void val_fin(void* p) { delete static_cast<ValPtr*>(p); }
static void tbl_fin(void* p) { delete static_cast<TblPtr*>(p); }
static void noop_foreach(void*, b_lean_obj_arg) {}

static inline lean_obj_res wrap_col(ColPtr arr) {
    return lean_alloc_external(g_col_class, new ColPtr(std::move(arr)));
}
static inline ColPtr& unwrap_col(b_lean_obj_arg o) {
    return *static_cast<ColPtr*>(lean_get_external_data(o));
}
static inline lean_obj_res wrap_val(ValPtr s) {
    return lean_alloc_external(g_val_class, new ValPtr(std::move(s)));
}
static inline ValPtr& unwrap_val(b_lean_obj_arg o) {
    return *static_cast<ValPtr*>(lean_get_external_data(o));
}
static inline lean_obj_res wrap_tbl(TblPtr t) {
    return lean_alloc_external(g_tbl_class, new TblPtr(std::move(t)));
}
static inline TblPtr& unwrap_tbl(b_lean_obj_arg o) {
    return *static_cast<TblPtr*>(lean_get_external_data(o));
}
static inline lean_obj_res wrap_anycol(ColPtr arr) {
    return lean_alloc_external(g_anycol_class, new ColPtr(std::move(arr)));
}
static inline ColPtr& unwrap_anycol(b_lean_obj_arg o) {
    return *static_cast<ColPtr*>(lean_get_external_data(o));
}

static lean_obj_res io_err(const std::string& msg) {
    return lean_io_result_mk_error(lean_mk_io_user_error(lean_mk_string(msg.c_str())));
}

#define LEAN_ARROW_TRY(var, expr) \
    auto var##_res_ = (expr); \
    if (!var##_res_.ok()) return io_err(var##_res_.status().message()); \
    auto var = std::move(*var##_res_);

#define LEAN_ARROW_STATUS(expr) \
    { auto s_ = (expr); if (!s_.ok()) return io_err(s_.message()); }

static inline bool opt_is_none(b_lean_obj_arg o) { return lean_is_scalar(o); }
static inline b_lean_obj_arg opt_get(b_lean_obj_arg o) { return lean_ctor_get(o, 0); }

static inline lean_obj_res mk_none() { return lean_box(0); }
static inline lean_obj_res mk_some(lean_obj_arg v) {
    lean_obj_res r = lean_alloc_ctor(1, 1, 0);
    lean_ctor_set(r, 0, v);
    return r;
}

// ---------------------------------------------------------------------------
// Init — Lean signature: IO Unit (no args, no world token)
// ---------------------------------------------------------------------------

// Forward-declare Arrow compute registration functions (in libarrow_compute.so)
namespace arrow::compute::internal {
void RegisterScalarArithmetic(FunctionRegistry*);
void RegisterScalarComparison(FunctionRegistry*);
void RegisterScalarBoolean(FunctionRegistry*);
void RegisterScalarValidity(FunctionRegistry*);
void RegisterScalarAggregateBasic(FunctionRegistry*);
void RegisterVectorSort(FunctionRegistry*);
void RegisterVectorArraySort(FunctionRegistry*);
void RegisterScalarSetLookup(FunctionRegistry*);
void RegisterScalarIfElse(FunctionRegistry*);
void RegisterScalarNested(FunctionRegistry*);
void RegisterScalarTemporalUnary(FunctionRegistry*);
void RegisterScalarTemporalBinary(FunctionRegistry*);
void RegisterScalarRoundArithmetic(FunctionRegistry*);
void RegisterVectorRank(FunctionRegistry*);
void RegisterVectorReplace(FunctionRegistry*);
void RegisterVectorSelectK(FunctionRegistry*);
void RegisterVectorPairwise(FunctionRegistry*);
void RegisterVectorCumulativeSum(FunctionRegistry*);
void RegisterVectorNested(FunctionRegistry*);
void RegisterVectorRunEndEncode(FunctionRegistry*);
void RegisterVectorRunEndDecode(FunctionRegistry*);
void RegisterVectorStatistics(FunctionRegistry*);
void RegisterScalarRandom(FunctionRegistry*);
void RegisterScalarStringAscii(FunctionRegistry*);
void RegisterScalarStringUtf8(FunctionRegistry*);
void RegisterScalarAggregateMode(FunctionRegistry*);
void RegisterScalarAggregatePivot(FunctionRegistry*);
void RegisterScalarAggregateQuantile(FunctionRegistry*);
void RegisterScalarAggregateVariance(FunctionRegistry*);
void RegisterScalarAggregateTDigest(FunctionRegistry*);
void RegisterHashAggregateBasic(FunctionRegistry*);
void RegisterHashAggregateNumeric(FunctionRegistry*);
void RegisterHashAggregatePivot(FunctionRegistry*);
}

extern "C" LEAN_EXPORT lean_obj_res lean_arrow_init() {
    g_col_class = lean_register_external_class(col_fin, noop_foreach);
    g_val_class = lean_register_external_class(val_fin, noop_foreach);
    g_tbl_class = lean_register_external_class(tbl_fin, noop_foreach);
    g_anycol_class = lean_register_external_class(col_fin, noop_foreach);

    // Register all compute kernels — static constructors don't run under Lean's linker
    auto* reg = arrow::compute::GetFunctionRegistry();
    arrow::compute::internal::RegisterScalarArithmetic(reg);
    arrow::compute::internal::RegisterScalarComparison(reg);
    arrow::compute::internal::RegisterScalarBoolean(reg);
    arrow::compute::internal::RegisterScalarValidity(reg);
    arrow::compute::internal::RegisterScalarAggregateBasic(reg);
    arrow::compute::internal::RegisterVectorSort(reg);
    arrow::compute::internal::RegisterVectorArraySort(reg);
    arrow::compute::internal::RegisterScalarSetLookup(reg);
    arrow::compute::internal::RegisterScalarIfElse(reg);
    arrow::compute::internal::RegisterScalarNested(reg);
    arrow::compute::internal::RegisterScalarTemporalUnary(reg);
    arrow::compute::internal::RegisterScalarTemporalBinary(reg);
    arrow::compute::internal::RegisterScalarRoundArithmetic(reg);
    arrow::compute::internal::RegisterVectorRank(reg);
    arrow::compute::internal::RegisterVectorReplace(reg);
    arrow::compute::internal::RegisterVectorSelectK(reg);
    arrow::compute::internal::RegisterVectorPairwise(reg);
    arrow::compute::internal::RegisterVectorCumulativeSum(reg);
    arrow::compute::internal::RegisterVectorNested(reg);
    arrow::compute::internal::RegisterVectorRunEndEncode(reg);
    arrow::compute::internal::RegisterVectorRunEndDecode(reg);
    arrow::compute::internal::RegisterVectorStatistics(reg);
    arrow::compute::internal::RegisterScalarRandom(reg);
    arrow::compute::internal::RegisterScalarStringAscii(reg);
    arrow::compute::internal::RegisterScalarStringUtf8(reg);
    arrow::compute::internal::RegisterScalarAggregateMode(reg);
    arrow::compute::internal::RegisterScalarAggregatePivot(reg);
    arrow::compute::internal::RegisterScalarAggregateQuantile(reg);
    arrow::compute::internal::RegisterScalarAggregateVariance(reg);
    arrow::compute::internal::RegisterScalarAggregateTDigest(reg);
    arrow::compute::internal::RegisterHashAggregateBasic(reg);
    arrow::compute::internal::RegisterHashAggregateNumeric(reg);
    arrow::compute::internal::RegisterHashAggregatePivot(reg);

    return lean_io_result_mk_ok(lean_box(0));
}

// ---------------------------------------------------------------------------
// Col construction helpers
// ---------------------------------------------------------------------------

// Unbox helpers — Int64/UInt64 need lean_unbox_uint64 (may be boxed big nat)
static int8_t   unbox_int8 (b_lean_obj_arg o) { return (int8_t) lean_unbox(o); }
static int16_t  unbox_int16(b_lean_obj_arg o) { return (int16_t)lean_unbox(o); }
static int32_t  unbox_int32(b_lean_obj_arg o) { return (int32_t)lean_unbox(o); }
static int64_t  unbox_int64(b_lean_obj_arg o) { return (int64_t)lean_unbox_uint64(o); }
static uint8_t  unbox_uint8 (b_lean_obj_arg o) { return (uint8_t) lean_unbox(o); }
static uint16_t unbox_uint16(b_lean_obj_arg o) { return (uint16_t)lean_unbox(o); }
static uint32_t unbox_uint32(b_lean_obj_arg o) { return (uint32_t)lean_unbox(o); }
static uint64_t unbox_uint64(b_lean_obj_arg o) { return lean_unbox_uint64(o); }
static float    unbox_float32(b_lean_obj_arg o) { return lean_unbox_float32(o); }
static double   unbox_float64(b_lean_obj_arg o) { return lean_unbox_float(o); }

// Boxing helpers for element getters
static inline lean_obj_res box_i8 (int8_t  v) { return lean_box((uint8_t)v); }
static inline lean_obj_res box_i16(int16_t v) { return lean_box((uint16_t)v); }
static inline lean_obj_res box_i32(int32_t v) { return lean_box((uint32_t)v); }
static inline lean_obj_res box_i64(int64_t v) { return lean_box_uint64((uint64_t)v); }
static inline lean_obj_res box_u8 (uint8_t  v) { return lean_box(v); }
static inline lean_obj_res box_u16(uint16_t v) { return lean_box(v); }
static inline lean_obj_res box_u32(uint32_t v) { return lean_box(v); }
static inline lean_obj_res box_u64(uint64_t v) { return lean_box_uint64(v); }

// Template for building int-like arrays from Array (Option IntN)
// Lean signature: @& Array (Option T) → IO (Col .dtype) — 1 arg, no world
template <typename BuilderT, typename CType>
static lean_obj_res build_int_col(b_lean_obj_arg arr,
                                  std::shared_ptr<arrow::DataType> dt,
                                  CType (*unbox)(b_lean_obj_arg)) {
    size_t n = lean_array_size(arr);
    BuilderT builder(dt, arrow::default_memory_pool());
    LEAN_ARROW_STATUS(builder.Reserve(n));
    for (size_t i = 0; i < n; i++) {
        b_lean_obj_arg elem = lean_array_get_core(arr, i);
        if (opt_is_none(elem)) {
            builder.UnsafeAppendNull();
        } else {
            builder.UnsafeAppend(static_cast<typename BuilderT::value_type>(unbox(opt_get(elem))));
        }
    }
    LEAN_ARROW_TRY(result, builder.Finish());
    return lean_io_result_mk_ok(wrap_col(result));
}

// ---------------------------------------------------------------------------
// Col constructors — all take 1 arg (Array), no world token
// ---------------------------------------------------------------------------

extern "C" LEAN_EXPORT lean_obj_res lean_arrow_col_bool(b_lean_obj_arg arr) {
    size_t n = lean_array_size(arr);
    arrow::BooleanBuilder builder;
    LEAN_ARROW_STATUS(builder.Reserve(n));
    for (size_t i = 0; i < n; i++) {
        b_lean_obj_arg elem = lean_array_get_core(arr, i);
        if (opt_is_none(elem))
            builder.UnsafeAppendNull();
        else
            builder.UnsafeAppend(lean_unbox(opt_get(elem)) != 0);
    }
    LEAN_ARROW_TRY(result, builder.Finish());
    return lean_io_result_mk_ok(wrap_col(result));
}

extern "C" LEAN_EXPORT lean_obj_res lean_arrow_col_int8(b_lean_obj_arg arr) {
    return build_int_col<arrow::Int8Builder, int8_t>(arr, arrow::int8(), unbox_int8);
}
extern "C" LEAN_EXPORT lean_obj_res lean_arrow_col_int16(b_lean_obj_arg arr) {
    return build_int_col<arrow::Int16Builder, int16_t>(arr, arrow::int16(), unbox_int16);
}
extern "C" LEAN_EXPORT lean_obj_res lean_arrow_col_int32(b_lean_obj_arg arr) {
    return build_int_col<arrow::Int32Builder, int32_t>(arr, arrow::int32(), unbox_int32);
}
extern "C" LEAN_EXPORT lean_obj_res lean_arrow_col_int64(b_lean_obj_arg arr) {
    return build_int_col<arrow::Int64Builder, int64_t>(arr, arrow::int64(), unbox_int64);
}
extern "C" LEAN_EXPORT lean_obj_res lean_arrow_col_uint8(b_lean_obj_arg arr) {
    return build_int_col<arrow::UInt8Builder, uint8_t>(arr, arrow::uint8(), unbox_uint8);
}
extern "C" LEAN_EXPORT lean_obj_res lean_arrow_col_uint16(b_lean_obj_arg arr) {
    return build_int_col<arrow::UInt16Builder, uint16_t>(arr, arrow::uint16(), unbox_uint16);
}
extern "C" LEAN_EXPORT lean_obj_res lean_arrow_col_uint32(b_lean_obj_arg arr) {
    return build_int_col<arrow::UInt32Builder, uint32_t>(arr, arrow::uint32(), unbox_uint32);
}
extern "C" LEAN_EXPORT lean_obj_res lean_arrow_col_uint64(b_lean_obj_arg arr) {
    return build_int_col<arrow::UInt64Builder, uint64_t>(arr, arrow::uint64(), unbox_uint64);
}

extern "C" LEAN_EXPORT lean_obj_res lean_arrow_col_float32(b_lean_obj_arg arr) {
    size_t n = lean_array_size(arr);
    arrow::FloatBuilder builder;
    LEAN_ARROW_STATUS(builder.Reserve(n));
    for (size_t i = 0; i < n; i++) {
        b_lean_obj_arg elem = lean_array_get_core(arr, i);
        if (opt_is_none(elem))
            builder.UnsafeAppendNull();
        else
            builder.UnsafeAppend(unbox_float32(opt_get(elem)));
    }
    LEAN_ARROW_TRY(result, builder.Finish());
    return lean_io_result_mk_ok(wrap_col(result));
}

extern "C" LEAN_EXPORT lean_obj_res lean_arrow_col_float64(b_lean_obj_arg arr) {
    size_t n = lean_array_size(arr);
    arrow::DoubleBuilder builder;
    LEAN_ARROW_STATUS(builder.Reserve(n));
    for (size_t i = 0; i < n; i++) {
        b_lean_obj_arg elem = lean_array_get_core(arr, i);
        if (opt_is_none(elem))
            builder.UnsafeAppendNull();
        else
            builder.UnsafeAppend(unbox_float64(opt_get(elem)));
    }
    LEAN_ARROW_TRY(result, builder.Finish());
    return lean_io_result_mk_ok(wrap_col(result));
}

extern "C" LEAN_EXPORT lean_obj_res lean_arrow_col_strings(b_lean_obj_arg arr) {
    size_t n = lean_array_size(arr);
    arrow::StringBuilder builder;
    LEAN_ARROW_STATUS(builder.Reserve(n));
    for (size_t i = 0; i < n; i++) {
        b_lean_obj_arg elem = lean_array_get_core(arr, i);
        if (opt_is_none(elem)) {
            LEAN_ARROW_STATUS(builder.AppendNull());
        } else {
            b_lean_obj_arg val = opt_get(elem);
            const char* s = lean_string_cstr(val);
            LEAN_ARROW_STATUS(builder.Append(s, lean_string_size(val) - 1));
        }
    }
    LEAN_ARROW_TRY(result, builder.Finish());
    return lean_io_result_mk_ok(wrap_col(result));
}

// Temporal constructors
extern "C" LEAN_EXPORT lean_obj_res lean_arrow_col_date32(b_lean_obj_arg arr) {
    return build_int_col<arrow::Date32Builder, int32_t>(arr, arrow::date32(), unbox_int32);
}
extern "C" LEAN_EXPORT lean_obj_res lean_arrow_col_date64(b_lean_obj_arg arr) {
    return build_int_col<arrow::Date64Builder, int64_t>(arr, arrow::date64(), unbox_int64);
}
extern "C" LEAN_EXPORT lean_obj_res lean_arrow_col_ts_s(b_lean_obj_arg arr) {
    return build_int_col<arrow::TimestampBuilder, int64_t>(arr, arrow::timestamp(arrow::TimeUnit::SECOND), unbox_int64);
}
extern "C" LEAN_EXPORT lean_obj_res lean_arrow_col_ts_ms(b_lean_obj_arg arr) {
    return build_int_col<arrow::TimestampBuilder, int64_t>(arr, arrow::timestamp(arrow::TimeUnit::MILLI), unbox_int64);
}
extern "C" LEAN_EXPORT lean_obj_res lean_arrow_col_ts_us(b_lean_obj_arg arr) {
    return build_int_col<arrow::TimestampBuilder, int64_t>(arr, arrow::timestamp(arrow::TimeUnit::MICRO), unbox_int64);
}
extern "C" LEAN_EXPORT lean_obj_res lean_arrow_col_ts_ns(b_lean_obj_arg arr) {
    return build_int_col<arrow::TimestampBuilder, int64_t>(arr, arrow::timestamp(arrow::TimeUnit::NANO), unbox_int64);
}
extern "C" LEAN_EXPORT lean_obj_res lean_arrow_col_dur_s(b_lean_obj_arg arr) {
    return build_int_col<arrow::DurationBuilder, int64_t>(arr, arrow::duration(arrow::TimeUnit::SECOND), unbox_int64);
}
extern "C" LEAN_EXPORT lean_obj_res lean_arrow_col_dur_ms(b_lean_obj_arg arr) {
    return build_int_col<arrow::DurationBuilder, int64_t>(arr, arrow::duration(arrow::TimeUnit::MILLI), unbox_int64);
}
extern "C" LEAN_EXPORT lean_obj_res lean_arrow_col_dur_us(b_lean_obj_arg arr) {
    return build_int_col<arrow::DurationBuilder, int64_t>(arr, arrow::duration(arrow::TimeUnit::MICRO), unbox_int64);
}
extern "C" LEAN_EXPORT lean_obj_res lean_arrow_col_dur_ns(b_lean_obj_arg arr) {
    return build_int_col<arrow::DurationBuilder, int64_t>(arr, arrow::duration(arrow::TimeUnit::NANO), unbox_int64);
}
extern "C" LEAN_EXPORT lean_obj_res lean_arrow_col_time32s(b_lean_obj_arg arr) {
    return build_int_col<arrow::Time32Builder, int32_t>(arr, arrow::time32(arrow::TimeUnit::SECOND), unbox_int32);
}
extern "C" LEAN_EXPORT lean_obj_res lean_arrow_col_time32ms(b_lean_obj_arg arr) {
    return build_int_col<arrow::Time32Builder, int32_t>(arr, arrow::time32(arrow::TimeUnit::MILLI), unbox_int32);
}
extern "C" LEAN_EXPORT lean_obj_res lean_arrow_col_time64us(b_lean_obj_arg arr) {
    return build_int_col<arrow::Time64Builder, int64_t>(arr, arrow::time64(arrow::TimeUnit::MICRO), unbox_int64);
}
extern "C" LEAN_EXPORT lean_obj_res lean_arrow_col_time64ns(b_lean_obj_arg arr) {
    return build_int_col<arrow::Time64Builder, int64_t>(arr, arrow::time64(arrow::TimeUnit::NANO), unbox_int64);
}

// ---------------------------------------------------------------------------
// Col access — generic over d: first param is uint8_t (Dtype enum)
// UInt64 args are unboxed uint64_t, not lean_object*
// ---------------------------------------------------------------------------

extern "C" LEAN_EXPORT lean_obj_res lean_arrow_col_len(uint8_t /*d*/, b_lean_obj_arg col) {
    return lean_io_result_mk_ok(lean_uint64_to_nat(unwrap_col(col)->length()));
}

extern "C" LEAN_EXPORT lean_obj_res lean_arrow_col_null_count(uint8_t /*d*/, b_lean_obj_arg col) {
    return lean_io_result_mk_ok(lean_uint64_to_nat(unwrap_col(col)->null_count()));
}

extern "C" LEAN_EXPORT lean_obj_res lean_arrow_col_is_null(uint8_t /*d*/, b_lean_obj_arg col, uint64_t idx) {
    auto& a = unwrap_col(col);
    if ((int64_t)idx >= a->length()) return io_err("index out of bounds");
    return lean_io_result_mk_ok(lean_box(a->IsNull(idx)));
}

extern "C" LEAN_EXPORT lean_obj_res lean_arrow_col_is_valid(uint8_t /*d*/, b_lean_obj_arg col, uint64_t idx) {
    auto& a = unwrap_col(col);
    if ((int64_t)idx >= a->length()) return io_err("index out of bounds");
    return lean_io_result_mk_ok(lean_box(a->IsValid(idx)));
}

extern "C" LEAN_EXPORT lean_obj_res lean_arrow_col_to_string(uint8_t /*d*/, b_lean_obj_arg col) {
    return lean_io_result_mk_ok(lean_mk_string(unwrap_col(col)->ToString().c_str()));
}

// ---------------------------------------------------------------------------
// Typed element getters — no implicit d, UInt64 idx is unboxed
// ---------------------------------------------------------------------------

extern "C" LEAN_EXPORT lean_obj_res lean_arrow_col_get_bool(b_lean_obj_arg col, uint64_t idx) {
    auto& a = unwrap_col(col);
    if ((int64_t)idx >= a->length()) return io_err("index out of bounds");
    if (a->IsNull(idx)) return lean_io_result_mk_ok(mk_none());
    return lean_io_result_mk_ok(mk_some(lean_box(
        static_cast<const arrow::BooleanArray&>(*a).Value(idx))));
}

#define DEF_INT_GETTER(name, ArrayT, box_fn) \
extern "C" LEAN_EXPORT lean_obj_res name(b_lean_obj_arg col, uint64_t idx) { \
    auto& a = unwrap_col(col); \
    if ((int64_t)idx >= a->length()) return io_err("index out of bounds"); \
    if (a->IsNull(idx)) return lean_io_result_mk_ok(mk_none()); \
    auto v = static_cast<const ArrayT&>(*a).Value(idx); \
    return lean_io_result_mk_ok(mk_some(box_fn(v))); \
}

DEF_INT_GETTER(lean_arrow_col_get_int8,   arrow::Int8Array,   box_i8)
DEF_INT_GETTER(lean_arrow_col_get_int16,  arrow::Int16Array,  box_i16)
DEF_INT_GETTER(lean_arrow_col_get_int32,  arrow::Int32Array,  box_i32)
DEF_INT_GETTER(lean_arrow_col_get_int64,  arrow::Int64Array,  box_i64)
DEF_INT_GETTER(lean_arrow_col_get_uint8,  arrow::UInt8Array,  box_u8)
DEF_INT_GETTER(lean_arrow_col_get_uint16, arrow::UInt16Array, box_u16)
DEF_INT_GETTER(lean_arrow_col_get_uint32, arrow::UInt32Array, box_u32)
DEF_INT_GETTER(lean_arrow_col_get_uint64, arrow::UInt64Array, box_u64)

extern "C" LEAN_EXPORT lean_obj_res lean_arrow_col_get_float32(b_lean_obj_arg col, uint64_t idx) {
    auto& a = unwrap_col(col);
    if ((int64_t)idx >= a->length()) return io_err("index out of bounds");
    if (a->IsNull(idx)) return lean_io_result_mk_ok(mk_none());
    float v = static_cast<const arrow::FloatArray&>(*a).Value(idx);
    return lean_io_result_mk_ok(mk_some(lean_box_float32(v)));
}

extern "C" LEAN_EXPORT lean_obj_res lean_arrow_col_get_float64(b_lean_obj_arg col, uint64_t idx) {
    auto& a = unwrap_col(col);
    if ((int64_t)idx >= a->length()) return io_err("index out of bounds");
    if (a->IsNull(idx)) return lean_io_result_mk_ok(mk_none());
    double v = static_cast<const arrow::DoubleArray&>(*a).Value(idx);
    return lean_io_result_mk_ok(mk_some(lean_box_float(v)));
}

extern "C" LEAN_EXPORT lean_obj_res lean_arrow_col_get_string(b_lean_obj_arg col, uint64_t idx) {
    auto& a = unwrap_col(col);
    if ((int64_t)idx >= a->length()) return io_err("index out of bounds");
    if (a->IsNull(idx)) return lean_io_result_mk_ok(mk_none());
    auto sv = static_cast<const arrow::StringArray&>(*a).GetView(idx);
    return lean_io_result_mk_ok(mk_some(lean_mk_string_from_bytes(sv.data(), sv.size())));
}

// ---------------------------------------------------------------------------
// Compute: Arithmetic — d (uint8_t) + [IsNumeric d] instance + operands
// ---------------------------------------------------------------------------

static lean_obj_res compute_binary(b_lean_obj_arg a, b_lean_obj_arg b, const char* fn_name) {
    LEAN_ARROW_TRY(result, arrow::compute::CallFunction(fn_name, {unwrap_col(a), unwrap_col(b)}));
    return lean_io_result_mk_ok(wrap_col(result.make_array()));
}

static lean_obj_res compute_unary(b_lean_obj_arg a, const char* fn_name) {
    LEAN_ARROW_TRY(result, arrow::compute::CallFunction(fn_name, {unwrap_col(a)}));
    return lean_io_result_mk_ok(wrap_col(result.make_array()));
}

// add/sub/mul/div: (uint8_t d, lean_object* inst, lean_object* a, lean_object* b)
extern "C" LEAN_EXPORT lean_obj_res lean_arrow_add(uint8_t, b_lean_obj_arg, b_lean_obj_arg a, b_lean_obj_arg b) {
    return compute_binary(a, b, "add");
}
extern "C" LEAN_EXPORT lean_obj_res lean_arrow_sub(uint8_t, b_lean_obj_arg, b_lean_obj_arg a, b_lean_obj_arg b) {
    return compute_binary(a, b, "subtract");
}
extern "C" LEAN_EXPORT lean_obj_res lean_arrow_mul(uint8_t, b_lean_obj_arg, b_lean_obj_arg a, b_lean_obj_arg b) {
    return compute_binary(a, b, "multiply");
}
extern "C" LEAN_EXPORT lean_obj_res lean_arrow_div(uint8_t, b_lean_obj_arg, b_lean_obj_arg a, b_lean_obj_arg b) {
    return compute_binary(a, b, "divide");
}
// neg: (uint8_t d, lean_object* inst, lean_object* a)
extern "C" LEAN_EXPORT lean_obj_res lean_arrow_neg(uint8_t, b_lean_obj_arg, b_lean_obj_arg a) {
    return compute_unary(a, "negate");
}

// ---------------------------------------------------------------------------
// Compute: Comparison
// eq/neq: (uint8_t d, lean_object* a, lean_object* b) — no typeclass
// lt/gt/lte/gte: (uint8_t d, lean_object* inst, lean_object* a, lean_object* b) — [IsOrd d]
// ---------------------------------------------------------------------------

extern "C" LEAN_EXPORT lean_obj_res lean_arrow_eq(uint8_t, b_lean_obj_arg a, b_lean_obj_arg b) {
    return compute_binary(a, b, "equal");
}
extern "C" LEAN_EXPORT lean_obj_res lean_arrow_neq(uint8_t, b_lean_obj_arg a, b_lean_obj_arg b) {
    return compute_binary(a, b, "not_equal");
}
extern "C" LEAN_EXPORT lean_obj_res lean_arrow_lt(uint8_t, b_lean_obj_arg, b_lean_obj_arg a, b_lean_obj_arg b) {
    return compute_binary(a, b, "less");
}
extern "C" LEAN_EXPORT lean_obj_res lean_arrow_gt(uint8_t, b_lean_obj_arg, b_lean_obj_arg a, b_lean_obj_arg b) {
    return compute_binary(a, b, "greater");
}
extern "C" LEAN_EXPORT lean_obj_res lean_arrow_lte(uint8_t, b_lean_obj_arg, b_lean_obj_arg a, b_lean_obj_arg b) {
    return compute_binary(a, b, "less_equal");
}
extern "C" LEAN_EXPORT lean_obj_res lean_arrow_gte(uint8_t, b_lean_obj_arg, b_lean_obj_arg a, b_lean_obj_arg b) {
    return compute_binary(a, b, "greater_equal");
}

// ---------------------------------------------------------------------------
// Compute: Vector ops
// filter/take: (uint8_t d, lean_object* col, lean_object* arg)
// sort/sortIndices: (uint8_t d, lean_object* inst, lean_object* col, uint8_t ascending)
// unique: (uint8_t d, lean_object* col)
// ---------------------------------------------------------------------------

extern "C" LEAN_EXPORT lean_obj_res lean_arrow_filter(uint8_t, b_lean_obj_arg col, b_lean_obj_arg mask) {
    return compute_binary(col, mask, "filter");
}

extern "C" LEAN_EXPORT lean_obj_res lean_arrow_take(uint8_t, b_lean_obj_arg col, b_lean_obj_arg indices) {
    return compute_binary(col, indices, "take");
}

extern "C" LEAN_EXPORT lean_obj_res lean_arrow_sort(uint8_t, b_lean_obj_arg, b_lean_obj_arg col, uint8_t ascending) {
    auto order = ascending ? arrow::compute::SortOrder::Ascending : arrow::compute::SortOrder::Descending;
    LEAN_ARROW_TRY(indices, arrow::compute::SortIndices(unwrap_col(col),
        arrow::compute::SortOptions({arrow::compute::SortKey("", order)})));
    LEAN_ARROW_TRY(result, arrow::compute::Take(unwrap_col(col), indices));
    return lean_io_result_mk_ok(wrap_col(result.make_array()));
}

extern "C" LEAN_EXPORT lean_obj_res lean_arrow_sort_indices(uint8_t, b_lean_obj_arg, b_lean_obj_arg col, uint8_t ascending) {
    auto order = ascending ? arrow::compute::SortOrder::Ascending : arrow::compute::SortOrder::Descending;
    LEAN_ARROW_TRY(result, arrow::compute::SortIndices(unwrap_col(col),
        arrow::compute::SortOptions({arrow::compute::SortKey("", order)})));
    return lean_io_result_mk_ok(wrap_col(result));
}

extern "C" LEAN_EXPORT lean_obj_res lean_arrow_unique(uint8_t, b_lean_obj_arg col) {
    return compute_unary(col, "unique");
}

// ---------------------------------------------------------------------------
// Val: Aggregation
// sum/mean: (uint8_t d, lean_object* inst, lean_object* col) — [IsNumeric d]
// min/max: (uint8_t d, lean_object* inst, lean_object* col) — [IsOrd d]
// count/countDistinct: (uint8_t d, lean_object* col) — no typeclass
// ---------------------------------------------------------------------------

extern "C" LEAN_EXPORT lean_obj_res lean_arrow_sum(uint8_t, b_lean_obj_arg, b_lean_obj_arg col) {
    LEAN_ARROW_TRY(result, arrow::compute::Sum(unwrap_col(col)));
    return lean_io_result_mk_ok(wrap_val(result.scalar()));
}

extern "C" LEAN_EXPORT lean_obj_res lean_arrow_min_val(uint8_t, b_lean_obj_arg, b_lean_obj_arg col) {
    LEAN_ARROW_TRY(result, arrow::compute::CallFunction("min", {unwrap_col(col)}));
    return lean_io_result_mk_ok(wrap_val(result.scalar()));
}

extern "C" LEAN_EXPORT lean_obj_res lean_arrow_max_val(uint8_t, b_lean_obj_arg, b_lean_obj_arg col) {
    LEAN_ARROW_TRY(result, arrow::compute::CallFunction("max", {unwrap_col(col)}));
    return lean_io_result_mk_ok(wrap_val(result.scalar()));
}

extern "C" LEAN_EXPORT lean_obj_res lean_arrow_mean(uint8_t, b_lean_obj_arg, b_lean_obj_arg col) {
    LEAN_ARROW_TRY(result, arrow::compute::Mean(unwrap_col(col)));
    return lean_io_result_mk_ok(wrap_val(result.scalar()));
}

extern "C" LEAN_EXPORT lean_obj_res lean_arrow_count(uint8_t, b_lean_obj_arg col) {
    LEAN_ARROW_TRY(result, arrow::compute::CallFunction("count", {unwrap_col(col)}));
    auto count_scalar = std::static_pointer_cast<arrow::Int64Scalar>(result.scalar());
    return lean_io_result_mk_ok(lean_uint64_to_nat(count_scalar->value));
}

extern "C" LEAN_EXPORT lean_obj_res lean_arrow_count_distinct(uint8_t, b_lean_obj_arg col) {
    LEAN_ARROW_TRY(result, arrow::compute::CallFunction("count_distinct", {unwrap_col(col)}));
    auto count_scalar = std::static_pointer_cast<arrow::Int64Scalar>(result.scalar());
    return lean_io_result_mk_ok(lean_uint64_to_nat(count_scalar->value));
}

// ---------------------------------------------------------------------------
// Val: access
// toString/isValid: (uint8_t d, lean_object* val)
// typed getters: (lean_object* val) — no d, fixed type
// ---------------------------------------------------------------------------

extern "C" LEAN_EXPORT lean_obj_res lean_arrow_val_to_string(uint8_t, b_lean_obj_arg val) {
    return lean_io_result_mk_ok(lean_mk_string(unwrap_val(val)->ToString().c_str()));
}

extern "C" LEAN_EXPORT lean_obj_res lean_arrow_val_is_valid(uint8_t, b_lean_obj_arg val) {
    return lean_io_result_mk_ok(lean_box(unwrap_val(val)->is_valid));
}

extern "C" LEAN_EXPORT lean_obj_res lean_arrow_val_get_int64(b_lean_obj_arg val) {
    auto& s = unwrap_val(val);
    if (!s->is_valid) return lean_io_result_mk_ok(mk_none());
    auto v = std::static_pointer_cast<arrow::Int64Scalar>(s)->value;
    return lean_io_result_mk_ok(mk_some(box_i64(v)));
}

extern "C" LEAN_EXPORT lean_obj_res lean_arrow_val_get_float64(b_lean_obj_arg val) {
    auto& s = unwrap_val(val);
    if (!s->is_valid) return lean_io_result_mk_ok(mk_none());
    auto v = std::static_pointer_cast<arrow::DoubleScalar>(s)->value;
    return lean_io_result_mk_ok(mk_some(lean_box_float(v)));
}

extern "C" LEAN_EXPORT lean_obj_res lean_arrow_val_get_bool(b_lean_obj_arg val) {
    auto& s = unwrap_val(val);
    if (!s->is_valid) return lean_io_result_mk_ok(mk_none());
    auto v = std::static_pointer_cast<arrow::BooleanScalar>(s)->value;
    return lean_io_result_mk_ok(mk_some(lean_box(v)));
}

extern "C" LEAN_EXPORT lean_obj_res lean_arrow_val_get_string(b_lean_obj_arg val) {
    auto& s = unwrap_val(val);
    if (!s->is_valid) return lean_io_result_mk_ok(mk_none());
    auto& buf = std::static_pointer_cast<arrow::StringScalar>(s)->value;
    return lean_io_result_mk_ok(mk_some(
        lean_mk_string_from_bytes(reinterpret_cast<const char*>(buf->data()), buf->size())));
}

// ---------------------------------------------------------------------------
// Tbl: Table (RecordBatch)
// ---------------------------------------------------------------------------

// make: (lean_object* names, lean_object* cols)
extern "C" LEAN_EXPORT lean_obj_res lean_arrow_tbl_make(b_lean_obj_arg names, b_lean_obj_arg cols) {
    size_t n = lean_array_size(names);
    if (n != lean_array_size(cols)) return io_err("names and columns must have same length");

    arrow::FieldVector fields;
    arrow::ArrayVector arrays;
    fields.reserve(n);
    arrays.reserve(n);

    for (size_t i = 0; i < n; i++) {
        auto& arr = unwrap_anycol(lean_array_get_core(cols, i));
        const char* name = lean_string_cstr(lean_array_get_core(names, i));
        fields.push_back(arrow::field(name, arr->type()));
        arrays.push_back(arr);
    }

    int64_t num_rows = n > 0 ? arrays[0]->length() : 0;
    auto schema = arrow::schema(fields);
    auto batch = arrow::RecordBatch::Make(schema, num_rows, arrays);
    return lean_io_result_mk_ok(wrap_tbl(batch));
}

extern "C" LEAN_EXPORT lean_obj_res lean_arrow_tbl_num_rows(b_lean_obj_arg tbl) {
    return lean_io_result_mk_ok(lean_uint64_to_nat(unwrap_tbl(tbl)->num_rows()));
}

extern "C" LEAN_EXPORT lean_obj_res lean_arrow_tbl_num_cols(b_lean_obj_arg tbl) {
    return lean_io_result_mk_ok(lean_uint64_to_nat(unwrap_tbl(tbl)->num_columns()));
}

extern "C" LEAN_EXPORT lean_obj_res lean_arrow_tbl_col_names(b_lean_obj_arg tbl) {
    auto& t = unwrap_tbl(tbl);
    auto schema = t->schema();
    lean_obj_res arr = lean_alloc_array(schema->num_fields(), schema->num_fields());
    for (int i = 0; i < schema->num_fields(); i++) {
        lean_array_set_core(arr, i, lean_mk_string(schema->field(i)->name().c_str()));
    }
    return lean_io_result_mk_ok(arr);
}

// col by name: (lean_object* tbl, lean_object* name)
extern "C" LEAN_EXPORT lean_obj_res lean_arrow_tbl_col_by_name(b_lean_obj_arg tbl, b_lean_obj_arg name) {
    auto& t = unwrap_tbl(tbl);
    const char* n = lean_string_cstr(name);
    auto col = t->GetColumnByName(n);
    if (!col) return io_err(std::string("column not found: ") + n);
    return lean_io_result_mk_ok(wrap_anycol(col));
}

// col by idx: (lean_object* tbl, uint64_t idx) — UInt64 unboxed
extern "C" LEAN_EXPORT lean_obj_res lean_arrow_tbl_col_by_idx(b_lean_obj_arg tbl, uint64_t idx) {
    auto& t = unwrap_tbl(tbl);
    if ((int64_t)idx >= t->num_columns()) return io_err("column index out of bounds");
    return lean_io_result_mk_ok(wrap_anycol(t->column(idx)));
}

// erase: (uint8_t d, lean_object* col)
extern "C" LEAN_EXPORT lean_obj_res lean_arrow_col_erase(uint8_t, b_lean_obj_arg col) {
    return lean_io_result_mk_ok(wrap_anycol(unwrap_col(col)));
}

// AnyCol casts — no d, fixed target type
static lean_obj_res cast_anycol(b_lean_obj_arg any, arrow::Type::type expected) {
    auto& arr = unwrap_anycol(any);
    if (arr->type_id() != expected)
        return io_err(std::string("type mismatch: expected ") +
                      arrow::internal::ToString(expected) + " but got " +
                      arr->type()->ToString());
    return lean_io_result_mk_ok(wrap_col(arr));
}

extern "C" LEAN_EXPORT lean_obj_res lean_arrow_anycol_cast_int64(b_lean_obj_arg any) {
    return cast_anycol(any, arrow::Type::INT64);
}
extern "C" LEAN_EXPORT lean_obj_res lean_arrow_anycol_cast_float64(b_lean_obj_arg any) {
    return cast_anycol(any, arrow::Type::DOUBLE);
}
extern "C" LEAN_EXPORT lean_obj_res lean_arrow_anycol_cast_bool(b_lean_obj_arg any) {
    return cast_anycol(any, arrow::Type::BOOL);
}
extern "C" LEAN_EXPORT lean_obj_res lean_arrow_anycol_cast_string(b_lean_obj_arg any) {
    return cast_anycol(any, arrow::Type::STRING);
}

// Table operations
// filter: (lean_object* tbl, lean_object* mask)
extern "C" LEAN_EXPORT lean_obj_res lean_arrow_tbl_filter(b_lean_obj_arg tbl, b_lean_obj_arg mask) {
    LEAN_ARROW_TRY(result, arrow::compute::Filter(unwrap_tbl(tbl), unwrap_col(mask)));
    return lean_io_result_mk_ok(wrap_tbl(result.record_batch()));
}

// sort: (lean_object* tbl, lean_object* col_name, uint8_t ascending) — Bool unboxed
extern "C" LEAN_EXPORT lean_obj_res lean_arrow_tbl_sort(b_lean_obj_arg tbl, b_lean_obj_arg col_name, uint8_t ascending) {
    auto& t = unwrap_tbl(tbl);
    const char* cn = lean_string_cstr(col_name);
    auto order = ascending ? arrow::compute::SortOrder::Ascending : arrow::compute::SortOrder::Descending;
    LEAN_ARROW_TRY(indices, arrow::compute::SortIndices(
        arrow::Datum(t), arrow::compute::SortOptions({arrow::compute::SortKey(cn, order)})));
    LEAN_ARROW_TRY(result, arrow::compute::Take(arrow::Datum(t), indices));
    return lean_io_result_mk_ok(wrap_tbl(result.record_batch()));
}

// select: (lean_object* tbl, lean_object* col_names)
extern "C" LEAN_EXPORT lean_obj_res lean_arrow_tbl_select(b_lean_obj_arg tbl, b_lean_obj_arg col_names) {
    auto& t = unwrap_tbl(tbl);
    size_t n = lean_array_size(col_names);
    std::vector<int> indices;
    indices.reserve(n);
    for (size_t i = 0; i < n; i++) {
        const char* name = lean_string_cstr(lean_array_get_core(col_names, i));
        int idx = t->schema()->GetFieldIndex(name);
        if (idx < 0) return io_err(std::string("column not found: ") + name);
        indices.push_back(idx);
    }
    LEAN_ARROW_TRY(result, t->SelectColumns(indices));
    return lean_io_result_mk_ok(wrap_tbl(result));
}

// addCol: (lean_object* tbl, lean_object* name, lean_object* col)
extern "C" LEAN_EXPORT lean_obj_res lean_arrow_tbl_add_col(b_lean_obj_arg tbl, b_lean_obj_arg name, b_lean_obj_arg col) {
    auto& t = unwrap_tbl(tbl);
    auto& arr = unwrap_anycol(col);
    const char* n = lean_string_cstr(name);
    auto f = arrow::field(n, arr->type());
    LEAN_ARROW_TRY(result, t->AddColumn(t->num_columns(), f, arr));
    return lean_io_result_mk_ok(wrap_tbl(result));
}

// toString: (lean_object* tbl)
extern "C" LEAN_EXPORT lean_obj_res lean_arrow_tbl_to_string(b_lean_obj_arg tbl) {
    return lean_io_result_mk_ok(lean_mk_string(unwrap_tbl(tbl)->ToString().c_str()));
}
