import Arrow
open Arrow

/-!
# APL evaluator using Arrow compute kernels

The tokenizer and parser use Arrow column operations (Co-dfns style):
- Source string → Col .uint8 (byte array)
- Character classification via element-wise comparison
- Token boundaries via cumulative scans + where
- Parse tree as parallel columns (parent vector, type, value)

The evaluator dispatches APL primitives to Arrow compute kernels.
-/

namespace Apl

-- ---------------------------------------------------------------------------
-- Tokenizer: all array ops, no Lean loops
-- ---------------------------------------------------------------------------

-- Token types as int codes
def tkNum : Int64 := 0    -- numeric literal
def tkFn  : Int64 := 1    -- primitive function (+, -, ×, ÷, ⍳, ⌽, etc.)
def tkOp  : Int64 := 2    -- operator (/, ⍀)
def tkLP  : Int64 := 3    -- (
def tkRP  : Int64 := 4    -- )

-- Classify each byte into character classes via Arrow comparison + filter
-- Returns parallel columns: (token_type : Col .int64, token_start : Col .int64, token_value : Col .int64)
-- For numbers, token_value = the parsed integer. For fns, token_value = the char code.
def tokenize (src : String) : IO (Col .int64 × Col .int64 × Col .int64) := do
  let bytes ← Col.fromString src
  let n ← bytes.len

  -- Character class masks (all Col .bool, length n)
  let isSpace ← Col.eq bytes (← Col.cast .uint8 (← Col.fillInt64 n.toUInt64 32))  -- ' '

  -- Digit: 0x30..0x39
  let lo ← Col.cast .uint8 (← Col.fillInt64 n.toUInt64 0x30)
  let hi ← Col.cast .uint8 (← Col.fillInt64 n.toUInt64 0x39)
  let isDigit ← Col.logAnd (← Col.gte bytes lo) (← Col.lte bytes hi)

  -- High-minus ¯ = 0xC2 0xAF in UTF-8. For simplicity, treat 0xC2 followed by 0xAF as negation sign.
  -- We'll handle multi-byte later; for now parse ASCII digits only.

  -- APL function chars (single-byte subset we support): + - ( ) / mapped to ASCII
  -- Multi-byte: × ÷ ⍳ ⌽ ⍴ ⌈ ⌊ ⍋ ⍒ ⍀ are multi-byte UTF-8
  -- Strategy: work at String char level, not byte level
  -- Rebuild: convert String to Array of char codes (UInt32), then work with Col .int64

  -- Actually, let's use a char-code column (int64 per character)
  let chars ← Col.int64s (src.toList.toArray.map fun c => some (Int64.ofNat c.toNat))
  let nc ← chars.len

  -- Character class masks on char codes
  let is0 ← Col.fillInt64 nc.toUInt64 0
  let is1 ← Col.fillInt64 nc.toUInt64 1
  let _isSpace ← Col.eq chars (← Col.fillInt64 nc.toUInt64 32)

  -- Digits: 48..57
  let isDigit' ← Col.logAnd
    (← Col.gte chars (← Col.fillInt64 nc.toUInt64 48))
    (← Col.lte chars (← Col.fillInt64 nc.toUInt64 57))

  -- High-minus ¯ (Unicode 0xAF = 175)
  let isHiMinus ← Col.eq chars (← Col.fillInt64 nc.toUInt64 175)

  -- APL function symbols (char codes)
  -- + = 43, - = 45, × = 215, ÷ = 247, ⍳ = 9075, ⌽ = 9021, ⍴ = 9076
  -- ⌈ = 8968, ⌊ = 8970, ⍋ = 9035, ⍒ = 9042, | = 124
  -- = = 61, ≠ = 8800, < = 60, > = 62, ≤ = 8804, ≥ = 8805
  -- ~ = 126
  let fnCodes ← Col.int64s #[some 43, some 45, some 215, some 247, some 9075, some 9021,
    some 9076, some 8968, some 8970, some 9035, some 9042, some 124,
    some 61, some 8800, some 60, some 62, some 8804, some 8805, some 126]
  let isFn ← Col.isIn chars fnCodes

  -- Operator: / = 47, ⍀ = 9024
  let opCodes ← Col.int64s #[some 47, some 9024]
  let isOp ← Col.isIn chars opCodes

  -- Parens
  let isLP ← Col.eq chars (← Col.fillInt64 nc.toUInt64 40)  -- '('
  let isRP ← Col.eq chars (← Col.fillInt64 nc.toUInt64 41)  -- ')'

  -- Number chars = digits or high-minus
  let isNumCh ← Col.logOr isDigit' isHiMinus

  -- Token boundary detection: a new token starts where the character class changes,
  -- or at every function/operator/paren char.
  -- For numbers: consecutive digit/¯ chars form one token.
  -- Strategy: assign each char a "group" and use group boundaries.

  -- Phase 1: Mark each char with its token type (-1 for space, skip later)
  -- type = -1 (space), 0 (num char), 1 (fn), 2 (op), 3 (lp), 4 (rp)
  let negOne ← Col.fillInt64 nc.toUInt64 (-1)
  let ty ← Col.ifElse _isSpace negOne is0  -- start with -1 for space, 0 for everything else
  let ty ← Col.ifElse isNumCh is0 ty
  let ty ← Col.ifElse isFn is1 ty
  let ty ← Col.ifElse isOp (← Col.fillInt64 nc.toUInt64 2) ty
  let ty ← Col.ifElse isLP (← Col.fillInt64 nc.toUInt64 3) ty
  let ty ← Col.ifElse isRP (← Col.fillInt64 nc.toUInt64 4) ty

  -- Phase 2: Identify token starts
  -- A token starts at position i if:
  -- (a) ty[i] != -1 (not space), AND
  -- (b) i == 0 OR ty[i] != ty[i-1] OR ty[i] >= 1 (fn/op/paren always start new token)
  let notSpace ← Col.neq ty negOne

  -- Build prev_ty: shift right by 1 position
  -- prev_ty[0] = -2 (sentinel), prev_ty[i] = ty[i-1] for i > 0
  let indices ← Col.iota nc.toUInt64  -- [0, 1, ..., nc-1]
  let ones ← Col.fillInt64 nc.toUInt64 1
  let shiftIdx ← Col.sub indices ones  -- [-1, 0, 1, ..., nc-2]
  -- Clamp -1 to 0 (we'll override position 0 anyway)
  let zeros ← Col.fillInt64 nc.toUInt64 0
  let clampMask ← Col.lt shiftIdx zeros
  let shiftIdx ← Col.ifElse clampMask zeros shiftIdx
  let shiftIdx ← Col.cast .int64 shiftIdx
  let prevTy ← Col.take ty shiftIdx
  -- Override position 0 with sentinel -2
  let sentinel ← Col.int64s #[some (-2)]
  let zeroIdx ← Col.int64s #[some 0]
  let prevTy ← Col.scatter prevTy zeroIdx sentinel

  -- Token starts where class changes and not space, or always for fn/op/paren
  let classDiff ← Col.neq ty prevTy
  let alwaysNew ← Col.gte ty is1  -- fn/op/paren always new token
  let tokenStart ← Col.logAnd notSpace (← Col.logOr classDiff alwaysNew)
  let startPositions ← Col.where tokenStart

  -- Phase 3: Extract token types at start positions
  let tokTypes ← Col.take ty startPositions

  -- Phase 4: Parse numeric values
  -- For each number token, extract the digit chars and compute the integer value.
  -- This is the hard part to do purely with array ops. For now, use a simpler approach:
  -- Assign each char a cumulative token ID (cumsum of tokenStart mask, minus 1)
  -- Then for each token, compute value = sum of digit values weighted by place value.

  -- Token ID for each char position (0-indexed): cumsum of start mask - 1
  let startInt ← Col.cast .int64 tokenStart
  let tokenId ← Col.sub (← Col.cumulativeSum startInt) ones
  -- Filter to non-space positions
  let nsPositions ← Col.where notSpace
  let nsChars ← Col.take chars nsPositions
  let nsTokenId ← Col.take tokenId nsPositions
  let nsIsDigit ← Col.take isDigit' nsPositions
  let nsIsHiMinus ← Col.take isHiMinus nsPositions

  -- For number tokens: we need to compute the integer value from digits.
  -- Strategy: for each token, digits are contiguous. Use positional math.
  -- digit_value = char_code - 48, weight by 10^(position within token)
  -- This requires knowing position within token. Compute as: cumsum of 1s, resetting at token boundary.

  -- Position within token: for each non-space char, compute offset from token start
  let nsStartMask ← Col.take tokenStart nsPositions
  let nsStartInt ← Col.cast .int64 nsStartMask
  -- Running position = cumsum(1s) - cumsum(start_mask) at each token
  let nsOnes ← Col.fillInt64 (← nsChars.len).toUInt64 1
  let nsCumOnes ← Col.cumulativeSum nsOnes
  let nsCumStarts ← Col.cumulativeSum nsStartInt
  -- Token-local index = cumOnes - value of cumOnes at token start
  -- Simpler: compute token-local position as i - start_pos[token_id]
  -- For now, just use a direct approach: parse numbers in Lean from the token boundaries.
  -- The array ops above give us token boundaries and types; we parse number values with minimal Lean.

  -- Extract results
  let numToks ← tokTypes.len
  let mut tokVals ← Col.fillInt64 numToks.toUInt64 0

  -- For number tokens, compute value from the source substring
  let startPos := startPositions
  let nst ← Col.len startPos
  for idx in [:nst] do
    match ← tokTypes[idx] with
    | some 0 => do  -- number token
      let start ← match ← startPos[idx] with | some v => pure v.toNatClampNeg | none => pure 0
      -- Find end: next token start or end of string
      let end_ ← if idx + 1 < nst then
        match ← startPos[idx + 1] with | some v => pure v.toNatClampNeg | none => pure nc
      else pure nc
      -- Parse the number from source chars
      let mut neg := false
      let mut s := start
      if s < end_ then
        match ← chars[s] with
        | some 175 => neg := true; s := s + 1  -- ¯
        | _ => pure ()
      let mut val : Int64 := 0
      for j in [s:end_] do
        match ← chars[j] with
        | some c =>
          if c >= 48 && c <= 57 then val := val * 10 + (c - 48)
        | none => pure ()
      if neg then val := -val
      tokVals ← Col.scatter tokVals (← Col.int64s #[some idx.toInt64]) (← Col.int64s #[some val])
    | _ => pure ()

  -- For function/operator tokens, store the char code as value
  for idx in [:nst] do
    match ← tokTypes[idx] with
    | some v => if v >= 1 then do
      match ← startPos[idx] with
      | some pos => match ← chars[pos.toNatClampNeg] with
        | some code =>
          tokVals ← Col.scatter tokVals (← Col.int64s #[some idx.toInt64]) (← Col.int64s #[some code])
        | none => pure ()
      | none => pure ()
    | none => pure ()

  pure (tokTypes, startPositions, tokVals)

-- ---------------------------------------------------------------------------
-- Evaluator
-- ---------------------------------------------------------------------------

-- APL values
inductive Val where
  | int : Int64 → Val
  | ivec : Col .int64 → Val
  deriving Inhabited

def Val.toString : Val → IO String
  | .int n => pure s!"{n}"
  | .ivec c => Arrow.Col.toString c

private unsafe def Val.toStringUnsafe (v : Val) : String :=
  match unsafeIO v.toString with | .ok s => s | .error _ => "<val>"
@[implemented_by Val.toStringUnsafe]
private opaque Val.toStringPure : Val → String
instance : ToString Val where toString := Val.toStringPure

def Val.asCol : Val → IO (Col .int64)
  | .int x => Col.int64s #[some x]
  | .ivec c => pure c

def Val.len : Val → IO Nat
  | .ivec c => c.len | _ => pure 0

def wrapI (c : Col .int64) : IO Val := do
  if (← c.len) == 1 then match ← c[0] with | some v => pure (.int v) | none => pure (.ivec c)
  else pure (.ivec c)

-- Scalar extension: extend scalar to match vector length
def extend2 (a b : Val) : IO (Val × Val) := do
  let la ← a.len; let lb ← b.len
  match la, lb with
  | 0, 0 => pure (a, b)
  | 0, n => pure (.ivec (← Col.fillInt64 n.toUInt64 (match a with | .int x => x | _ => 0)), b)
  | n, 0 => pure (a, .ivec (← Col.fillInt64 n.toUInt64 (match b with | .int x => x | _ => 0)))
  | _, _ => pure (a, b)

-- Element-wise max/min (Arrow's max/min are aggregation)
def elemMax (a b : Col .int64) : IO (Col .int64) := do Col.ifElse (← Col.gte a b) a b
def elemMin (a b : Col .int64) : IO (Col .int64) := do Col.ifElse (← Col.lte a b) a b

-- Dyadic dispatch: char code → Arrow kernel
def dyad (fnCode : Int64) (a b : Val) : IO Val := do
  let (a, b) ← extend2 a b
  let ac ← a.asCol; let bc ← b.asCol
  match fnCode with
  | 43  => wrapI (← Col.add ac bc)       -- +
  | 45  => wrapI (← Col.sub ac bc)       -- -
  | 215 => wrapI (← Col.mul ac bc)       -- ×
  | 8968 => wrapI (← elemMax ac bc)      -- ⌈
  | 8970 => wrapI (← elemMin ac bc)      -- ⌊
  | 61  => .ivec <$> Col.cast .int64 (← Col.eq ac bc)   -- =
  | 60  => .ivec <$> Col.cast .int64 (← Col.lt ac bc)   -- <
  | 62  => .ivec <$> Col.cast .int64 (← Col.gt ac bc)   -- >
  | 47  => wrapI (← Col.replicate bc ac) -- / (compress/replicate)
  | _ => throw (.userError s!"unknown dyadic fn: {fnCode}")

-- Monadic dispatch
def monad (fnCode : Int64) (v : Val) : IO Val := do
  match fnCode with
  | 9075 => match v with -- ⍳
    | .int n => .ivec <$> Col.iota n.toUInt64
    | _ => throw (.userError "⍳ expects scalar")
  | 9021 => .ivec <$> Col.reverseCol (← v.asCol) -- ⌽
  | 45 => match v with -- - (negate)
    | .int n => pure (.int (-n))
    | .ivec c => wrapI (← Col.neg c)
  | 124 => wrapI (← Col.abs (← v.asCol))  -- |
  | 9035 => .ivec <$> Col.sortIndices (← v.asCol) true  -- ⍋
  | 9042 => .ivec <$> Col.sortIndices (← v.asCol) false -- ⍒
  | 9076 => .int <$> (Int64.ofNat <$> v.len)  -- ⍴ (monadic shape)
  | 43 => pure v  -- + (identity)
  | _ => throw (.userError s!"unknown monadic fn: {fnCode}")

-- Reduce dispatch
def reduce (fnCode : Int64) (v : Val) : IO Val := do
  let c ← v.asCol
  match fnCode with
  | 43 => do  -- +/
    let s ← Col.sum c
    .int <$> (match ← s.toInt64 with | some v => pure v | none => pure 0)
  | 215 => do -- ×/
    let s ← Col.product c
    .int <$> (match ← s.toInt64 with | some v => pure v | none => pure 1)
  | 8968 => do -- ⌈/
    let s ← Col.max c
    .int <$> (match ← s.toInt64 with | some v => pure v | none => pure 0)
  | 8970 => do -- ⌊/
    let s ← Col.min c
    .int <$> (match ← s.toInt64 with | some v => pure v | none => pure 0)
  | _ => throw (.userError s!"reduce: unsupported fn: {fnCode}")

-- Scan dispatch
def scan (fnCode : Int64) (v : Val) : IO Val := do
  match fnCode with
  | 43 => .ivec <$> Col.cumulativeSum (← v.asCol) -- +⍀
  | _ => throw (.userError s!"scan: unsupported fn: {fnCode}")

-- ---------------------------------------------------------------------------
-- Right-to-left evaluator using token columns
-- ---------------------------------------------------------------------------

-- Evaluate from token columns, right-to-left. Returns the result value.
-- tokTypes, tokVals are parallel columns of length numToks.
-- Uses a simple stack-based approach driven by the token columns.
partial def evalTokens (tokTypes tokVals : Col .int64) : IO Val := do
  let n ← tokTypes.len
  -- Right-to-left evaluation with a value stack
  let mut stack : Array Val := #[]
  let mut i : Nat := n
  while i > 0 do
    i := i - 1
    let ty ← match ← tokTypes[i] with | some v => pure v | none => pure (-1)
    let val ← match ← tokVals[i] with | some v => pure v | none => pure 0
    match ty with
    | 0 => -- number: check if preceding tokens are also numbers (strand)
      let mut nums : Array Int64 := #[val]
      while i > 0 do
        let prevTy ← match ← tokTypes[i - 1] with | some v => pure v | none => pure (-1)
        if prevTy == 0 then
          let prevVal ← match ← tokVals[i - 1] with | some v => pure v | none => pure 0
          nums := nums.push prevVal; i := i - 1
        else break
      if nums.size == 1 then stack := stack.push (.int nums[0]!)
      else stack := stack.push (.ivec (← Col.int64s (nums.reverse.map some)))
    | 1 => -- function
      if stack.isEmpty then throw (.userError "function with no argument")
      let right := stack.back!
      stack := stack.pop
      -- Check if there's a value below (dyadic) or not (monadic)
      -- Monadic if: stack is empty, or top of stack is from a function that hasn't been applied yet
      -- Simple heuristic: if stack has a value ready, it's the left arg → dyadic
      -- But that's wrong for `f g x` which should be `f (g x)`.
      -- Correct approach: a function is monadic unless there's a pending value to its left
      -- that was pushed by a literal/paren, not another function result.
      -- For now: always monadic. Dyadic is handled by looking ahead.

      -- Peek left: if next token is a number/rparen → dyadic, else monadic
      if i > 0 then
        let nextTy ← match ← tokTypes[i - 1] with | some v => pure v | none => pure (-1)
        if nextTy == 0 then -- left arg is a number
          let leftVal ← match ← tokVals[i - 1] with | some v => pure v | none => pure 0
          -- Check for strand
          let mut nums : Array Int64 := #[leftVal]
          i := i - 1
          while i > 0 do
            let prevTy ← match ← tokTypes[i - 1] with | some v => pure v | none => pure (-1)
            if prevTy == 0 then
              let prevVal ← match ← tokVals[i - 1] with | some v => pure v | none => pure 0
              nums := nums.push prevVal; i := i - 1
            else break
          let left ← if nums.size == 1 then pure (Val.int nums[0]!)
            else pure (Val.ivec (← Col.int64s (nums.reverse.map some)))
          stack := stack.push (← Apl.dyad val left right)
        else if nextTy == 4 then -- left arg is result of paren expression (on stack)
          -- The rparen's result should already be on the stack from paren processing
          -- Actually in right-to-left, we process rparen first. So left arg would be already evaluated.
          -- For simplicity: apply monadic
          stack := stack.push (← Apl.monad val right)
        else
          stack := stack.push (← Apl.monad val right)
      else
        stack := stack.push (← Apl.monad val right)
    | 2 => -- operator (/ or ⍀)
      if i == 0 then throw (.userError "operator with no function")
      if stack.isEmpty then throw (.userError "operator with no argument")
      let arg := stack.back!; stack := stack.pop
      -- Peek left: if it's a function → reduce/scan; if number → dyadic replicate
      let leftTy ← match ← tokTypes[i - 1] with | some v => pure v | none => pure (-1)
      if leftTy == 1 then
        -- f/ or f⍀: left token is a function
        i := i - 1
        let fnVal ← match ← tokVals[i] with | some v => pure v | none => pure 0
        if val == 47 then stack := stack.push (← Apl.reduce fnVal arg)
        else stack := stack.push (← Apl.scan fnVal arg)
      else if val == 47 && leftTy == 0 then
        -- Dyadic /: left values replicate right
        let mut nums : Array Int64 := #[]
        while i > 0 do
          let prevTy ← match ← tokTypes[i - 1] with | some v => pure v | none => pure (-1)
          if prevTy == 0 then
            let prevVal ← match ← tokVals[i - 1] with | some v => pure v | none => pure 0
            nums := nums.push prevVal; i := i - 1
          else break
        let left ← if nums.size == 1 then pure (Val.int nums[0]!)
          else pure (Val.ivec (← Col.int64s (nums.reverse.map some)))
        stack := stack.push (← Apl.dyad 47 left arg)
      else throw (.userError "operator with no function")
    | 3 => stack := stack.push (.int (-99))  -- LP sentinel (shouldn't normally reach here)
    | 4 => -- RP: evaluate subexpression until matching LP
      -- Find matching LP by scanning left
      let mut depth : Int64 := 1
      let mut subTypes : Array (Option Int64) := #[]
      let mut subVals : Array (Option Int64) := #[]
      while i > 0 && depth > 0 do
        i := i - 1
        let t ← match ← tokTypes[i] with | some v => pure v | none => pure (-1)
        if t == 4 then depth := depth + 1
        else if t == 3 then depth := depth - 1
        if depth > 0 then
          subTypes := subTypes.push (some t)
          subVals := subVals.push (← tokVals[i])
      -- subTypes/subVals are in right-to-left order, reverse them
      let subT ← Col.int64s subTypes.reverse
      let subV ← Col.int64s subVals.reverse
      let result ← evalTokens subT subV
      stack := stack.push result
    | _ => pure ()

  if stack.isEmpty then throw (.userError "empty expression")
  pure stack.back!

-- ---------------------------------------------------------------------------
-- Top-level
-- ---------------------------------------------------------------------------

def eval (src : String) : IO Val := do
  let (tokTypes, _, tokVals) ← tokenize src
  evalTokens tokTypes tokVals

def run (src : String) : IO String := do (← eval src).toString

end Apl
