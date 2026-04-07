import Apl

-- Normalize Arrow's multi-line array format to flat APL-style output
-- "[\n  1,\n  2,\n  3\n]" → "1 2 3"
def normalize (s : String) : String :=
  let s := s.trimAscii.toString
  if s.startsWith "[" then
    let s := s.replace "[" "" |>.replace "]" "" |>.replace "," "" |>.replace "\n" " "
    -- collapse multiple spaces
    let parts := s.splitOn " " |>.filter (· ≠ "")
    " ".intercalate parts
  else s

def test (label src expected : String) : IO Unit := do
  let result ← Apl.run src
  let got := normalize result
  unless got == expected do
    throw (.userError s!"{label}: «{src}» → got «{got}», expected «{expected}»")

def main : IO Unit := do
  IO.println "=== APL vs Dyalog (⎕IO←0) ==="

  -- Verified against Dyalog APL 19.0, ⎕IO←0
  test "sum ⍳10"       "+/⍳10"                        "45"
  test "sum ⍳101"      "+/⍳101"                       "5050"
  test "max reduce"    "⌈/3 1 4 1 5 9 2 6"            "9"
  test "min reduce"    "⌊/3 1 4 1 5 9 2 6"            "1"
  test "reverse iota"  "⌽⍳5"                          "4 3 2 1 0"
  test "scan iota"     "+⍀⍳6"                         "0 1 3 6 10 15"
  test "grade up"      "⍋3 1 4 1 5 9"                 "1 3 0 2 4 5"
  test "grade down"    "⍒3 1 4 1 5 9"                 "5 4 2 0 1 3"  -- Dyalog: 5 4 2 0 1 3
  test "count eq"      "+/1=3 1 4 1 5 1"              "3"
  test "range"         "(⌈/7 2 9 4 1)-(⌊/7 2 9 4 1)" "8"
  test "shape"         "⍴⍳8"                          "8"
  test "replicate"     "2 3 1/4 5 6"                  "4 4 5 5 5 6"
  test "sum abs"       "+/|5 ¯3 ¯7 2 ¯1"             "18"
  test "compress"      "1 0 1/10 20 30"               "10 30"
  test "double grade"  "⍋⍋3 1 4 1 5 9"               "2 0 3 1 4 5"  -- Dyalog: 2 0 3 1 4 5
  test "scalar×iota"   "3×⍳5"                         "0 3 6 9 12"
  test "scalar+iota"   "10+⍳4"                        "10 11 12 13"
  test "iota squared"  "(⍳5)×⍳5"                      "0 1 4 9 16"
  test "sum of sq"     "+/(⍳5)×⍳5"                    "30"
  test "factorial 6"   "×/1+⍳6"                       "720"

  IO.println "=== all passed ==="
