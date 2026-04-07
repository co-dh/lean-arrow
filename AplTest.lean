import Apl

def test (label src expected : String) : IO Unit := do
  let result ← Apl.run src
  let got := result.trimAscii.toString
  unless got == expected do
    throw (.userError s!"{label}: «{src}» → got «{got}», expected «{expected}»")

def main : IO Unit := do
  IO.println "=== APL Test Suite ==="

  -- Scalars
  test "literal" "42" "42"
  test "negative" "¯5" "-5"

  -- Iota
  test "iota 5" "⍳5" "[\n  0,\n  1,\n  2,\n  3,\n  4\n]"

  -- Arithmetic
  test "add" "3+4" "7"
  test "sub" "10-3" "7"
  test "mul" "6×7" "42"

  -- Reduce
  test "sum reduce" "+/⍳10" "45"
  test "product" "×/1 2 3 4 5" "120"
  test "max reduce" "⌈/3 1 4 1 5" "5"
  test "min reduce" "⌊/3 1 4 1 5" "1"

  -- Reverse
  test "reverse" "⌽1 2 3" "[\n  3,\n  2,\n  1\n]"

  -- Negate
  test "negate" "-5" "-5"

  -- Abs
  test "abs" "|¯7" "7"

  -- Sum 1..100
  test "sum 100" "+/⍳101" "5050"

  -- Compress
  test "compress" "1 0 1/10 20 30" "[\n  10,\n  30\n]"

  -- Grade
  test "grade up" "⍋3 1 4 1 5" "[\n  1,\n  3,\n  0,\n  2,\n  4\n]"

  IO.println "=== all APL tests passed ==="
