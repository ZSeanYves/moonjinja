// ============================================================
// MoonbitJinja — Parser
// ============================================================

pub struct VarPath {
  parts : Array[String]
}

pub struct Call {
  name : String
  args : Array[Expr]
}

// ==================== Operators ====================

pub(all) enum BinOp {
  Add
  Sub
  Mul
  Div
  FloorDiv
  Mod
  Eq
  Ne
  Lt
  Le
  Gt
  Ge
  And
  Or
}

fn op_to_binop(op : String) -> BinOp? {
  match op {
    "+" => Some(BinOp::Add)
    "-" => Some(BinOp::Sub)
    "*" => Some(BinOp::Mul)
    "/" => Some(BinOp::Div)
    "//" => Some(BinOp::FloorDiv)
    "%" => Some(BinOp::Mod)
    "==" => Some(BinOp::Eq)
    "!=" => Some(BinOp::Ne)
    "<" => Some(BinOp::Lt)
    "<=" => Some(BinOp::Le)
    ">" => Some(BinOp::Gt)
    ">=" => Some(BinOp::Ge)
    "and" => Some(BinOp::And)
    "or" => Some(BinOp::Or)
    _ => None
  }
}

fn precedence(op : BinOp) -> Int {
  match op {
    BinOp::Mul | BinOp::Div | BinOp::FloorDiv | BinOp::Mod => 70
    BinOp::Add | BinOp::Sub => 60
    BinOp::Lt | BinOp::Le | BinOp::Gt | BinOp::Ge => 50
    BinOp::Eq | BinOp::Ne => 40
    BinOp::And => 30
    BinOp::Or => 20
  }
}

///|
pub(all) enum UnOp {
  Not
  Neg
  Pos
}

// ==================== AST ====================

pub(all) enum Expr {
  TextNode(String, Bool, Bool)
  RawText(String)
  Var(VarPath)
  Literal(Value)
  Unary(UnOp, Expr)
  Binary(Expr, BinOp, Expr)
  FilterChain(Expr, Array[Call])
  IfBlock(Expr, Array[Expr], Array[Expr])
  ForBlock(String, Expr, Array[Expr])
  IncludeNode(String)
  BlockNode(String, Array[Expr])
  SetStmt(String, Expr)
  WithBlock(Map[String, Expr], Array[Expr])
  Break
  Continue
  Sequence(Array[Expr])
}

// 顶层模板（用于继承支持）
pub struct Template {
  parent : String?
  body   : Array[Expr]
}

///|
fn is_block_start(t : Token) -> Bool {
  match t {
    BlockStart(_) => true
    _ => false
  }
}

///|
fn is_block_end(t : Token) -> Bool {
  match t {
    BlockEnd(_) => true
    _ => false
  }
}

///|
fn is_var_end(t : Token) -> Bool {
  match t {
    VarEnd(_) => true
    _ => false
  }
}

///|调试用，
fn parse_fail(
  _i : Ref[Int],
  _tokens : Array[Token],
  _len : Int,
  msg : String,
) ->String raise JinjaError {
  //let from = if i.val >= 3 { i.val - 3 } else { 0 }
  //let to = if i.val + 3 < len { i.val + 3 } else { len - 1 }

  // 收集并拼成一行
  //let near : Array[String] = []
  //for k in from..=to {
  //  near.push(token_to_string(tokens[k]))
  //}
  ////println("PARSE ERROR at index=\{i.val}")
  ////println("NEAR TOKENS: [" + near.join(", ") + "]")
  raise ParseError(msg)
}



// ==================== Parsing Entry ====================

///|
pub fn parse(tokens : Array[Token]) -> Template raise JinjaError {
  let i = { val: 0 }
  let len = tokens.length()
  let tpl = parse_template(tokens, i, len)
  return tpl
}


///|
fn parse_template(
  tokens : Array[Token],
  i : Ref[Int],
  len : Int,
) -> Template raise JinjaError {
  let mut parent : String? = None

  // optional extends at start
  if i.val + 2 < len {
    match tokens[i.val] {
      BlockStart(_) =>
        match tokens[i.val + 1] {
          Identifier(id) =>
            if id == "extends" {
              parent = Some(parse_extends_header(tokens, i, len))
            }
          _ => ()
        }
      _ => ()
    }
  }
  let body = parse_expr_list(tokens, i, len)
  // Template 是 struct；用记录字面量的“具名”写法，避免字段顺序陷阱
  let tpl : Template = { parent, body }
  return tpl
}


// 只返回 extends 文件名
///|
fn parse_extends_header(
  tokens : Array[Token],
  i : Ref[Int],
  _len : Int,
) -> String raise JinjaError {
  // 消费 BlockStart
  match tokens[i.val] {
    BlockStart(_) => i.val += 1
    _ => raise ParseError("Expected '{%' before extends")
  }

  // "extends"
  match tokens[i.val] {
    Identifier(id) => {
      if id != "extends" {
        ignore(parse_fail(i, tokens, _len, "Expected 'extends'"))
      }
      i.val += 1
    }
    _ => ignore(parse_fail(i, tokens, _len, "Expected 'extends'"))
  }

  // 字面量文件名
  let filename = match tokens[i.val] {
    Literal(s) => {
      i.val += 1
      s
    }
    _ => raise ParseError("Expected file name after 'extends'")
  }

  // 结束 "%}"（strip/非 strip 都接受）
  match tokens[i.val] {
    BlockEnd(_) => i.val += 1
    _ => raise ParseError("Expected '%}' after extends")
  }
  filename
}


// ==================== Core Helpers ====================

///|
fn peek(tokens : Array[Token], i : Int) -> Token {
  if i < tokens.length() {
    tokens[i]
  } else {
    EOF
  }
}

///|
fn advance(i : Ref[Int]) -> Unit {
  i.val += 1
}

///|
fn is_delim(tok : Token, ch : Char) -> Bool {
  match tok {
    Delimiter(c) => c == ch
    _ => false
  }
}

///|
fn expect_delim(
  tokens : Array[Token],
  i : Ref[Int],
  ch : Char,
  what : String,
) -> Unit raise JinjaError {
  if i.val >= tokens.length() || not(is_delim(tokens[i.val], ch)) {
    raise ParseError(what)
  }
  i.val += 1
}

// ==================== Value Conversion ====================

///|
fn str_to_int(s : String) -> Int {
  let chars = s.to_array()
  let mut result = 0
  let mut sign = 1
  let mut start = 0
  if chars.length() > 0 && chars[0] == '-' {
    sign = -1
    start = 1
  }
  for i in start..<chars.length() {
    let c = chars[i]
    if '0' <= c && c <= '9' {
      result = result * 10 + (c.to_int() - '0'.to_int())
    } else {
      return 0
    }
  }
  return result * sign
}

///|
fn to_value_from_token_lit(lit : String) -> Value {
  if lit == "true" {
    return BoolValue(true)
  }
  if lit == "false" {
    return BoolValue(false)
  }
  if lit == "null" {
    return Null
  }
  let chars = lit.to_array()
  let mut all_digits = true
  for c in chars {
    if not('0' <= c && c <= '9') {
      all_digits = false
      break
    }
  }
  if all_digits {
    return IntValue(str_to_int(lit))
  }
  return StrValue(lit)
}

// ==================== Expression Parsers ====================

///|
fn parse_expr(
  tokens : Array[Token],
  i : Ref[Int],
  len : Int,
) -> Expr raise JinjaError {
  parse_binary_expr(tokens, i, len, 1)
}

///|
fn parse_binary_expr(
  tokens : Array[Token],
  i : Ref[Int],
  len : Int,
  min_prec : Int,
) -> Expr raise JinjaError {
  let mut left = parse_unary_or_primary(tokens, i, len)
  while true {
    let tok = peek(tokens, i.val)
    match tok {
      Operator(op_str) => {
        let maybe = op_to_binop(op_str)
        match maybe {
          None => break
          Some(binop) => {
            let prec = precedence(binop)
            if prec < min_prec {
              break
            }
            advance(i)
            let right = parse_binary_expr(tokens, i, len, prec + 1)
            left = Expr::Binary(left, binop, right)
          }
        }
      }
      _ => break
    }
  }
  return left
}

///|
fn parse_unary_or_primary(
  tokens : Array[Token],
  i : Ref[Int],
  len : Int,
) -> Expr raise JinjaError {
  let base = parse_primary(tokens, i, len)
  parse_postfix(tokens, i, len, base)
}



///|
fn parse_call_args(
  tokens : Array[Token],
  i : Ref[Int],
  len : Int,
) -> Array[Expr] raise JinjaError {
  expect_delim(tokens, i, '(', "Expected '(' after filter name")
  let args : Array[Expr] = []
  // 空实参 ()
  if is_delim(peek(tokens, i.val), ')') {
    i.val += 1
    return args
  }
  // 至少一个参数
  args.push(parse_expr(tokens, i, len))
  while i.val < len && is_delim(peek(tokens, i.val), ',') {
    i.val += 1
    args.push(parse_expr(tokens, i, len))
  }
  expect_delim(tokens, i, ')', "Expected ')' to close argument list")
  args
}


///|
fn parse_postfix(
  tokens : Array[Token],
  i : Ref[Int],
  len : Int,
  base0 : Expr,
) -> Expr raise JinjaError {
  let base = base0
  let filters : Array[Call] = []
  while i.val < len {
    match tokens[i.val] {
      Operator(op) => {
        if op != "|" {
          break
        } // ← 只在分支体里判断
        i.val += 1 // 吃掉 '|'
        let fname = match tokens[i.val] {
          Identifier(s) => {
            i.val += 1
            s
          }
          _ => raise ParseError("Expected filter name after '|'")
        }
        let args = if is_delim(tokens[i.val], '(') {
          parse_call_args(tokens, i, len)
        } else {
          []
        }
        let call : Call = { name: fname, args }
        filters.push(call)
      }
      _ => break
    }
  }
  if filters.length() > 0 {
    Expr::FilterChain(base, filters)
  } else {
    base
  }
}




///|
fn parse_primary(
  tokens : Array[Token],
  i : Ref[Int],
  len : Int,
) -> Expr raise JinjaError {
  let tok = peek(tokens, i.val)
  match tok {
    Text(s) => {
      let strip_left = if i.val > 0 {
        match tokens[i.val - 1] {
          VarEnd(true) | BlockEnd(true) => true // ← 左边看 End(true)
          _ => false
        }
      } else {
        false
      }
      let strip_right = if i.val + 1 < len {
        match tokens[i.val + 1] {
          VarStart(true) | BlockStart(true) => true // ← 右边看 Start(true)
          _ => false
        }
      } else {
        false
      }
      i.val += 1
      Expr::TextNode(s, strip_left, strip_right)
    }
    Identifier(first) => {
      i.val += 1
      let parts : Array[String] = Array::new()
      parts.push(first)
      while i.val + 1 < len {
        if is_delim(tokens[i.val], '.') {
          match tokens[i.val + 1] {
            Identifier(seg) => {
              i.val += 2
              parts.push(seg)
              continue
            }
            _ => raise ParseError("Expected identifier after '.'")
          }
        }
        break
      }
      let a : VarPath = { parts, }
      Expr::Var(a)
    }
    Literal(raw) => {
      i.val += 1
      let v = to_value_from_token_lit(raw)
      Expr::Literal(v)
    }
    Delimiter('(') => {
      i.val += 1
      let e = parse_expr(tokens, i, len)
      expect_delim(tokens, i, ')', "Expected ')'")
      e
    }
    _ => raise ParseError("Unsupported token in primary")
  }
}

// ==================== Expression Lists ====================

///|
//fn debug_token_at(tokens : Array[Token], len : Int, idx : Int) -> String {
//  if idx < 0 || idx >= len {
//    "<out-of-range>"
//  } else {
//    token_to_string(tokens[idx])
//  }
//}

///|
fn parse_expr_list(
  tokens : Array[Token],
  i : Ref[Int],
  len : Int,
) -> Array[Expr] raise JinjaError {
  let out : Array[Expr] = Array::new()
  while i.val < len {
    let cur = tokens[i.val]
    match cur {
      EOF => {
        return out
      }
      VarStart(_) => {
        i.val += 1
        let e = parse_expr(tokens, i, len)
        if i.val >= len || not(is_var_end(tokens[i.val])) {
          raise ParseError("Expected '}}' to close variable tag")
        }
        i.val += 1
        out.push(e)
      }
      BlockStart(_) => {
        // lookahead：这些交给外层块解析器处理
        if i.val + 1 < len {
          match tokens[i.val + 1] {
            Identifier(id) =>
              if id == "endif" ||
                 id == "endfor" ||
                 id == "endwith" ||
                 id == "endblock" ||
                 id == "else" ||
                 id == "elif" {
                return out
              }
            _ => ()
          }
        }
        if i.val + 1 >= len {
          raise ParseError("Unexpected EOF inside block")
        }
        match tokens[i.val + 1] {
          Identifier(id) =>
            if id == "if" {
              let e = parse_if_block(tokens, i, len)
              out.push(e)
            } else if id == "for" {
              let e = parse_for_block(tokens, i, len)
              out.push(e)
            } else if id == "with" {
              let e = parse_with_block(tokens, i, len)
              out.push(e)
            } else if id == "include" {
              let e = parse_include(tokens, i, len)
              out.push(e)
            } else if id == "block" {
              let e = parse_block(tokens, i, len)
              out.push(e)
            } else if id == "set" {
              let e = parse_set_block(tokens, i, len)
              out.push(e)
            } else if id == "break" {
              // 期望：BlockStart(_), Identifier("break"), BlockEnd(_)
              i.val += 1 // {%
              i.val += 1 // break
              if i.val >= len || not(is_block_end(tokens[i.val])) {
                raise ParseError("Expected '%}' after break")
              }
              i.val += 1
              out.push(Expr::Break)
            } else if id == "continue" {
              i.val += 1 // {%
              i.val += 1 // continue
              if i.val >= len || not(is_block_end(tokens[i.val])) {
                raise ParseError("Expected '%}' after continue")
              }
              i.val += 1
              out.push(Expr::Continue)
            } else {
              raise ParseError("Unknown block tag")
            }
          _ => raise ParseError("Expected block identifier after '{%'")
        }
      }
      _ => {
        let e = parse_primary(tokens, i, len)
        out.push(e)
      }
    }
  }
  out
}




// ==================== Block Parsers ====================
///|
fn parse_if_block(
  tokens : Array[Token],
  i : Ref[Int],
  len : Int,
) -> Expr raise JinjaError {
  // 进入 "{% if"
  match tokens[i.val] {
    BlockStart(_) => i.val += 1
    _ => ignore(parse_fail(i, tokens, len, "Expected '{%' before if"))
  }
  match tokens[i.val] {
    Identifier(id) => {
      if id != "if" {
        ignore(parse_fail(i, tokens, len, "Expected 'if'"))
      }
      i.val += 1
    }
    _ => ignore(parse_fail(i, tokens, len, "Expected 'if'"))
  }
  let cond = parse_expr(tokens, i, len)
  if i.val >= len || not(is_block_end(tokens[i.val])) {
    ignore(parse_fail(i, tokens, len, "Expected '%}' after if condition"))
  }
  i.val += 1
  let then_body = parse_expr_list(tokens, i, len)
  // else 分支（可选）
  let mut else_body : Array[Expr] = Array::new()
  if i.val + 1 < len && is_block_start(tokens[i.val]) {
    match tokens[i.val + 1] {
      Identifier(id) =>
        if id == "else" {
          i.val += 2 // {%, else
          if i.val >= len || not(is_block_end(tokens[i.val])) {
            ignore(parse_fail(i, tokens, len, "Expected '%}' after else"))
          }
          i.val += 1
          else_body = parse_expr_list(tokens, i, len)
        }
      _ => ()
    }
  }

  // 结束：endif
  match tokens[i.val] {
    BlockStart(_) => i.val += 1
    _ => ignore(parse_fail(i, tokens, len, "Expected '{%' before endif"))
  }
  match tokens[i.val] {
    Identifier(id) => {
      if id != "endif" {
        ignore(parse_fail(i, tokens, len, "Expected 'endif'"))
      }
      i.val += 1
    }
    _ => ignore(parse_fail(i, tokens, len, "Expected 'endif'"))
  }
  if i.val >= len || not(is_block_end(tokens[i.val])) {
    ignore(parse_fail(i, tokens, len, "Expected '%}' after endif"))
  }
  i.val += 1
  Expr::IfBlock(cond, then_body, else_body)
}



///|
fn parse_for_block(
  tokens : Array[Token],
  i : Ref[Int],
  len : Int,
) -> Expr raise JinjaError {
  match tokens[i.val] {
    BlockStart(_) => i.val += 1
    _ => ignore(parse_fail(i, tokens, len, "Expected '{%' before for"))
  }
  match tokens[i.val] {
    Identifier(id) => { if id != "for" { ignore(parse_fail(i, tokens, len, "Expected 'for'")) } 
    i.val += 1 }
    _ => ignore(parse_fail(i, tokens, len, "Expected 'for'"))
  }
  let loop_var = match tokens[i.val] {
    Identifier(n) => { i.val += 1; n }
    _ => parse_fail(i, tokens, len, "Expected loop variable")
  }
  match tokens[i.val] {
    Identifier(id) => { if id != "in" { ignore(parse_fail(i, tokens, len, "Expected 'in' in for")) } 
    i.val += 1 }
    _ => ignore(parse_fail(i, tokens, len, "Expected 'in' in for"))
  }
  let iterable = parse_expr(tokens, i, len)
  if i.val >= len || not(is_block_end(tokens[i.val])) {
    ignore(parse_fail(i, tokens, len, "Expected '%}' after for header"))
  }
  i.val += 1

  let body = parse_expr_list(tokens, i, len)

  // "{% endfor %}"
  match tokens[i.val] {
    BlockStart(_) => i.val += 1
    _ => ignore(parse_fail(i, tokens, len, "Expected '{%' before endfor"))
  }
  match tokens[i.val] {
    Identifier(id) => { if id != "endfor" { ignore(parse_fail(i, tokens, len, "Expected 'endfor'")) } 
    i.val += 1 }
    _ => ignore(parse_fail(i, tokens, len, "Expected 'endfor'"))
  }
  if i.val >= len || not(is_block_end(tokens[i.val])) {
    ignore(parse_fail(i, tokens, len, "Expected '%}' after endfor"))
  }
  i.val += 1
  Expr::ForBlock(loop_var, iterable, body)

}


///|
fn parse_include(
  tokens : Array[Token],
  i : Ref[Int],
  _len : Int,
) -> Expr raise JinjaError {
  match tokens[i.val] {
    BlockStart(_) => i.val += 1
    _ => raise ParseError("Expected '{%' before include")
  }
  match tokens[i.val] {
    Identifier(id) => {
      if id != "include" {
        raise ParseError("Expected 'include'")
      }
      i.val += 1
    }
    _ => raise ParseError("Expected 'include'")
  }
  let filename = match tokens[i.val] {
    Literal(s) => {
      i.val += 1
      s
    }
    _ => raise ParseError("Expected filename in include")
  }
  match tokens[i.val] {
    BlockEnd(_) => i.val += 1
    _ => raise ParseError("Expected '%}' after include")
  }
  Expr::IncludeNode(filename)
}


///|
fn parse_block(
  tokens : Array[Token],
  i : Ref[Int],
  len : Int,
) -> Expr raise JinjaError {
  match tokens[i.val] {
    BlockStart(_) => i.val += 1
    _ => raise ParseError("Expected '{%' before block")
  }
  match tokens[i.val] {
    Identifier(id) => {
      if id != "block" {
        raise ParseError("Expected 'block'")
      }
      i.val += 1
    }
    _ => raise ParseError("Expected 'block'")
  }
  let name = match tokens[i.val] {
    Identifier(n) => {
      i.val += 1
      n
    }
    _ => raise ParseError("Expected block name")
  }
  if i.val >= len || not(is_block_end(tokens[i.val])) {
    raise ParseError("Expected '%}' after block")
  }
  i.val += 1
  let body = parse_expr_list(tokens, i, len)
  match tokens[i.val] {
    BlockStart(_) => i.val += 1
    _ => raise ParseError("Expected '{%' before endblock")
  }
  match tokens[i.val] {
    Identifier(id) => {
      if id != "endblock" {
        raise ParseError("Expected 'endblock'")
      }
      i.val += 1
    }
    _ => raise ParseError("Expected 'endblock'")
  }
  if i.val >= len || not(is_block_end(tokens[i.val])) {
    raise ParseError("Expected '%}' after endblock")
  }
  i.val += 1
  Expr::BlockNode(name, body)
}


///|
fn parse_set_block(
  tokens : Array[Token],
  i : Ref[Int],
  len : Int,
) -> Expr raise JinjaError {
  match tokens[i.val] {
    BlockStart(_) => i.val += 1
    _ => raise ParseError("Expected '{%' before set")
  }
  match tokens[i.val] {
    Identifier(id) => {
      if id != "set" {
        raise ParseError("Expected 'set'")
      }
      i.val += 1
    }
    _ => raise ParseError("Expected 'set'")
  }
  let name = match tokens[i.val] {
    Identifier(n) => {
      i.val += 1
      n
    }
    _ => raise ParseError("Expected var name")
  }
  match tokens[i.val] {
    Operator(op) => {
      if op != "=" {
        raise ParseError("Expected '=' after var name")
      }
      i.val += 1
    }
    _ => raise ParseError("Expected '=' after var name")
  }
  let value = parse_expr(tokens, i, len)
  if i.val >= len || not(is_block_end(tokens[i.val])) {
    raise ParseError("Expected '%}' after set")
  }
  i.val += 1
  Expr::SetStmt(name, value)
}


///|
fn parse_with_block(
  tokens : Array[Token],
  i : Ref[Int],
  len : Int,
) -> Expr raise JinjaError {
  // "{% with"
  match tokens[i.val] {
    BlockStart(_) => i.val += 1
    _ => raise ParseError("Expected '{%' before with")
  }
  match tokens[i.val] {
    Identifier(id) => {
      if id != "with" {
        raise ParseError("Expected 'with'")
      }
      i.val += 1
    }
    _ => raise ParseError("Expected 'with'")
  }
  let assigns = Map::new()
  while true {
    // name
    let name = match tokens[i.val] {
      Identifier(n) => {
        i.val += 1
        n
      }
      _ => raise ParseError("Expected var name in 'with'")
    }
    // "="
    match tokens[i.val] {
      Operator(op) => {
        if op != "=" {
          raise ParseError("Expected '=' after var name")
        }
        i.val += 1
      }
      _ => raise ParseError("Expected '=' after var name")
    }
    // value expr
    let value = parse_expr(tokens, i, len)
    assigns[name] = value

    // ',' 继续，或 '%}' 结束
    if i.val < len {
      match tokens[i.val] {
        Delimiter(',') => {
          i.val += 1
          continue
        }
        BlockEnd(_) => {
          i.val += 1
          break
        }
        _ => raise ParseError("Expected ',' or '%}' in with")
      }
    } else {
      raise ParseError("Unexpected EOF in with")
    }
  }
  let body = parse_expr_list(tokens, i, len)

  // "{% endwith %}"
  match tokens[i.val] {
    BlockStart(_) => i.val += 1
    _ => raise ParseError("Expected '{%' before endwith")
  }
  match tokens[i.val] {
    Identifier(id) => {
      if id != "endwith" {
        raise ParseError("Expected 'endwith'")
      }
      i.val += 1
    }
    _ => raise ParseError("Expected 'endwith'")
  }
  if i.val >= len || not(is_block_end(tokens[i.val])) {
    raise ParseError("Expected '%}' after endwith")
  }
  i.val += 1
  Expr::WithBlock(assigns, body)
}
