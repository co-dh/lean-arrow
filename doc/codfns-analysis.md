# Co-dfns → lean-arrow: Feasibility Analysis

## Co-dfns Overview

Aaron Hsu's PhD thesis (Indiana University, ~2019) presents **Co-dfns**, an APL compiler written entirely in Dyalog APL.
The compiler itself is a data-parallel program — no recursion, no loops, just flat array operations.

**Key insight**: the AST is a **columnar table**, not a tree of pointers.

| Column | Type  | Purpose                                     |
|--------|-------|---------------------------------------------|
| `p`    | int32 | Parent vector — `p[i]` = parent of node `i` |
| `t`    | uint8 | Node type (Function, Expression, Binding...) |
| `k`    | uint8 | Kind/arity subtype                           |
| `n`    | int32 | Symbol table index                           |
| `lx`   | int8  | Lexical scope marker                         |

Tree operations = filter + index arithmetic on columns. No pointers, no recursion.

## Compiler Pipeline

```
Source → PS (Parse) → TT (Tree Transform) → GC (Code Gen) → CC (C Compile)
```

- **PS**: Tokenize via character classification, bracket-match via plus-scan, build parent vector from depth
- **TT**: Dead code elimination, operator normalization, function lifting, variable analysis, register allocation
- **GC**: Columnar AST → C source code
- **CC**: Shell out to system C compiler

## Critical APL Primitives Used

| APL          | Name           | lean-arrow Status                                  |
|--------------|----------------|----------------------------------------------------|
| `+⍀`        | Plus-scan      | `Col.cumulativeSum` — **have**                     |
| `⍋`          | Grade (sort)   | `Col.sortIndices` — **have**                       |
| `⌿⍨`        | Compress       | `Col.filter` — **have**                            |
| `p[v]`       | Gather         | `Col.take` — **have**                              |
| `= < + -`    | Element-wise   | `Col.eq`, `Col.lt`, `Col.add`, etc. — **have**     |
| `∪`          | Unique         | `Col.unique` — **have**                            |
| `⍸`          | Where          | `Col.where` — **added**                            |
| `⍳n`         | Iota/range     | `Col.iota` — **added**                             |
| `⍳` (dyadic) | Index-of       | `Col.indexOf` — **added**                          |
| `≠⍀`        | XOR-scan       | `Col.cumulativeXor` — **added**                    |
| `∧⍀`        | AND-scan       | `Col.cumulativeAnd` — **added**                    |
| `∨⍀`        | OR-scan        | `Col.cumulativeOr` — **added**                     |
| `∧ ∨ ~`      | Logical ops    | `Col.logAnd`, `Col.logOr`, `Col.logNot` — **added** |
| `@`          | Scatter        | `Col.scatter` — **added**                          |
| `/`          | Replicate      | `Col.replicate` — **added**                        |
| `⌸`          | Key/group-by   | Not yet — moderate to add via Arrow GroupBy         |
| `∘.=`        | Outer product  | Not yet — O(n²), only used in register allocation  |
| `⍣≡`        | Fixed-point    | Lean `do` loop — **have** (host language)           |

## Why lean-arrow Maps Well

1. **AST-as-table** maps directly to Arrow's columnar model (RecordBatch / parallel Col arrays)
2. **Tree surgery** (mask + compress + renumber) = `Col.filter` + index arithmetic on parent column
3. **Lean's dependent types** add safety APL lacks: parent vector is `Col .int32`, type column is `Col .uint8`,
   can't accidentally mix them
4. **Fixed-point iteration** is a natural Lean `do` loop; the body is pure Arrow compute

## Gaps

- **General scan**: Arrow only has cumulative sum; we added XOR/AND/OR scans as custom C++ kernels
- **Outer product**: O(n²) — only used for register allocation; can substitute different algorithm
- **Group-by (⌸)**: Arrow has the machinery but API is complex; not needed for basic compiler passes

## Implementation Strategy

1. Add missing array primitives (iota, where, scatter, scans, replicate) — **done**
2. Build APL tokenizer using character classification + Arrow ops
3. Build APL parser (right-to-left, standard APL parsing)
4. Build APL evaluator dispatching to Arrow compute kernels
5. Later: port Co-dfns tree transforms for columnar AST manipulation

## References

- [Co-dfns GitHub](https://github.com/Co-dfns/Co-dfns)
- [A Data Parallel Compiler Hosted on the GPU (PhD Thesis)](https://scholarworks.iu.edu/dspace/handle/2022/24749)
- [The Key to a Data Parallel Compiler (ARRAY 2016)](https://dl.acm.org/doi/10.1145/2935323.2935331)
