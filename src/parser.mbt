// AST expression definitions with whitespace control and scope management
pub enum Expr {
  TextNode(String, Bool, Bool)        // Plain text, with strip_left and strip_right
  VariableNode(String)                // {{ variable }}
  BinaryOp(Expr, String, Expr)        // Expressions like a + b
  LiteralNode(String)                 // Quoted or numeric literals
  IfBlock(Expr, Array[Expr], Array[Expr])  // if ... else ...
  ForBlock(String, Expr, Array[Expr])      // for item in list
  IncludeNode(String)                // include "file.html"
  BlockNode(String, Array[Expr])     // block content ... endblock
  Sequence(Array[Expr])              // List of expressions
  ExtendsNode(String, Map[String, Array[Expr]])  // extends base.html
  SetStmt(String, Expr)              // set variable = value
  WithBlock(String, Expr, Array[Expr])  // with variable = value ... endwith
}

// Alias for use in inheritance merging
pub type BlockMap Map[String, Array[Expr]]

// Entry point: parse a list of tokens into a full AST
fn parse(tokens: Array[Token]) -> Expr!JinjaError {
  let i = { val: 0 }
  let len = tokens.length()
  return parse_template!(tokens, i, len)
}

// Parse the full template (including optional 'extends')
fn parse_template(tokens: Array[Token], i: Ref[Int], len: Int) -> Expr!JinjaError {
  if i.val + 2 < len {
    match tokens[i.val] {
      BlockStart(_) => {
        if tokens[i.val + 1] == Identifier("extends") {
          return parse_extends!(tokens, i, len)
        }
      }
      _ => ignore(0)
    }
  }
  let body = parse_expr_list!(tokens, i, len)
  return Sequence(body)
}

// Parse a list of expressions
fn parse_expr_list(tokens: Array[Token], i: Ref[Int], len: Int) -> Array[Expr]!JinjaError {
  let exprs = []
  while i.val < len && not(peek(tokens, i.val) == EOF) {
    match peek(tokens, i.val) {
      BlockStart(_) => {
        let next = if i.val + 1 < len { tokens[i.val + 1] } else { EOF }
        match next {
          Identifier("if") => exprs.push(parse_if_block!(tokens, i, len))
          Identifier("for") => exprs.push(parse_for_block!(tokens, i, len))
          Identifier("include") => exprs.push(parse_include!(tokens, i, len))
          Identifier("block") => exprs.push(parse_block!(tokens, i, len))
          Identifier("set") => exprs.push(parse_set_block!(tokens, i, len))
          Identifier("with") => exprs.push(parse_with_block!(tokens, i, len))
          _ => raise ParseError("Unknown block tag")
        }
      }
      _ => exprs.push(parse_expr!(tokens, i, len))
    }
  }
  return exprs
}

// Parse binary expressions with precedence
fn parse_expr(tokens: Array[Token], i: Ref[Int], len: Int) -> Expr!JinjaError {
  return parse_binary_expr!(tokens, i, len, 1)
}

// Parse left-associative binary operations
fn parse_binary_expr(tokens: Array[Token], i: Ref[Int], len: Int, min_prec: Int) -> Expr!JinjaError {
  let mut left = parse_primary!(tokens, i, len)
  while true {
    let tok = peek(tokens, i.val)
    match tok {
      Operator(op) => {
        let prec = get_precedence(op)
        if prec < min_prec { break }
        advance(i)
        let right = parse_binary_expr!(tokens, i, len, prec + 1)
        left = BinaryOp(left, op, right)
      }
      _ => break
    }
  }
  return left
}
// Parse literals, text, or variable names
fn parse_primary(tokens: Array[Token], i: Ref[Int], len: Int) -> Expr!JinjaError {
  let tok = peek(tokens, i.val)
  match tok {
      Text(s) => {
        let strip_left = if i.val > 0 {
          match tokens[i.val - 1] {
            VarStart(true) | BlockStart(true) => true
            _ => false
          }
        } else { false }

        let strip_right = if i.val + 1 < len {
          match tokens[i.val + 1] {
            VarEnd(true) | BlockEnd(true) => true
            _ => false
          }
        } else { false }

        advance(i)
        return TextNode(s, strip_left, strip_right)
    }
    Identifier(name) => {
      advance(i)
      return VariableNode(name)
    }
    Literal(value) => {
      advance(i)
      return LiteralNode(value)
    }
    _ => raise ParseError("Unsupported token: if-block start")
  }
}

// Other block parsers (if, for, include, block, set, with...) follow
// All are implemented similarly by matching tokens and collecting body content
fn parse_if_block(tokens: Array[Token], i: Ref[Int], len: Int) -> Expr!JinjaError {
  advance(i)
  if peek(tokens, i.val) != Identifier("if") {
    raise ParseError("Expected 'if' after '{%'")
  }
  advance(i)

  let condition = parse_expr!(tokens, i, len)
  match peek(tokens, i.val){
    BlockEnd(_) => ignore(0)
    _ => raise ParseError("Expected '%}' after if condition")
  }
  advance(i)

  let then_body = parse_expr_list!(tokens, i, len)
  let else_body = []

  match peek(tokens, i.val) {
    BlockStart(_) if i.val + 1 < len && tokens[i.val + 1] == Identifier("else") => {
      advance(i)  // BlockStart
      advance(i)  // else
      match peek(tokens, i.val) {
        BlockEnd(_) => advance(i)
        _ => raise ParseError("Expected '%}' after 'else'")
      }
      let parsed_else = parse_expr_list!(tokens, i, len)
      for e in parsed_else { else_body.push(e) }
    }
    _ => ignore(0)
  }

  match peek(tokens, i.val) {
    BlockStart(_) => {
      advance(i)
      if peek(tokens, i.val) != Identifier("endif") {
        raise ParseError("Expected 'endif'")
      }
      advance(i)
      match peek(tokens, i.val) {
        BlockEnd(_) => advance(i)
        _ => raise ParseError("Expected '%}' after 'endif'")
      }
    }
    _ => raise ParseError("Expected '{% endif %}'")
  }

  return IfBlock(condition, then_body, else_body)
}

fn parse_for_block(tokens: Array[Token], i: Ref[Int], len: Int) -> Expr!JinjaError {
  advance(i)
  if peek(tokens, i.val) != Identifier("for") {
    raise ParseError("Expected 'for' after '{%'")
  }
  advance(i)

  let var_tok = peek(tokens, i.val)
  let loop_var = match var_tok {
    Identifier(name) => name
    _ => raise ParseError("Expected loop variable name")
  }
  advance(i)

  if peek(tokens, i.val) != Identifier("in") {
    raise ParseError("Expected 'in' in for loop")
  }
  advance(i)

  let iterable = parse_expr!(tokens, i, len)

  match peek(tokens, i.val) {
    BlockEnd(_) => advance(i)
    _ => raise ParseError("Expected '%}' after for loop header")
  }

  let body = parse_expr_list!(tokens, i, len)

  match peek(tokens, i.val) {
    BlockStart(_) => {
      advance(i)
      if peek(tokens, i.val) != Identifier("endfor") {
        raise ParseError("Expected 'endfor'")
      }
      advance(i)
      match peek(tokens, i.val) {
        BlockEnd(_) => advance(i)
        _ => raise ParseError("Expected '%}' after 'endfor'")
      }
    }
    _ => raise ParseError("Expected '{% endfor %}'")
  }


  return ForBlock(loop_var, iterable, body)
}

fn peek(tokens: Array[Token], i: Int) -> Token {
  if i < tokens.length() {
    return tokens[i]
  } else {
    return EOF
  }
}

fn advance(i: Ref[Int]) -> Unit {
  i.val += 1
}

fn get_precedence(op: String) -> Int {
  match op {
    "==" => 1
    "+" | "-" => 2
    "*" | "/" => 3
    _ => 0
  }
}

/// 解析 include
fn parse_include(tokens: Array[Token], i: Ref[Int], len: Int) -> Expr!JinjaError {
  advance(i)
  let tok = peek(tokens, i.val)
  match tok {
    Literal(filename) => {
      advance(i)
      match peek(tokens, i.val) {
        BlockEnd(_) => advance(i)
        _ => raise ParseError("Expected '%}' after include")
      }
      return IncludeNode(filename)
    }
    _ => raise ParseError("Expected file name in include")
  }
}

/// 解析 block
fn parse_block(tokens: Array[Token], i: Ref[Int], len: Int) -> Expr!JinjaError {
  advance(i)
  let tok = peek(tokens, i.val)
  match tok {
    Identifier(name) => {
      advance(i)
      match peek(tokens, i.val) {
        BlockEnd(_) => advance(i)
        _ => raise ParseError("Expected '%}' after block name")
      }

      let body = parse_expr_list!(tokens, i, len)

      match peek(tokens, i.val) {
        BlockStart(_) => {
          advance(i)
          if peek(tokens, i.val) != Identifier("endblock") {
            raise ParseError("Expected 'endblock'")
          }
          advance(i)
          match peek(tokens, i.val) {
            BlockEnd(_) => advance(i)
            _ => raise ParseError("Expected '%}' after 'endblock'")
          }
        }
        _ => raise ParseError("Expected '{% endblock %}'")
      }

      return BlockNode(name, body)
    }
    _ => raise ParseError("Expected block name")
  }
}

fn parse_extends(tokens: Array[Token], i: Ref[Int], len: Int) -> Expr!JinjaError {
  advance(i)  // 跳过 BlockStart
  let tok = peek(tokens, i.val)
  match tok {
    Literal(filename) => {
      advance(i)
      match peek(tokens, i.val) {
        BlockEnd(_) => advance(i)
        _ => raise ParseError("Expected '%}' after extends")
      }

      // 收集所有 block 定义
      let blocks = Map::new()
      while i.val < len && not(peek(tokens, i.val) == EOF) {
        match peek(tokens, i.val) {
          BlockStart(_) => {
            let next = if i.val + 1 < len { tokens[i.val + 1] } else { EOF }
            if next == Identifier("block") {
              let block_expr = parse_block!(tokens, i, len)
              match block_expr {
                BlockNode(name, content) => {
                  blocks[name] = content
                }
                _ => raise ParseError("Expected block node")
              }
            } else {
              raise ParseError("Only 'block' allowed in child template with extends")
            }
          }
          _ => raise ParseError("Unexpected content in child template with extends")
        }
      }

      return ExtendsNode(filename, blocks)
    }
    _ => raise ParseError("Expected file name after 'extends'")
  }
}

fn parse_set_block(tokens: Array[Token], i: Ref[Int], len: Int) -> Expr!JinjaError {
  advance(i)  // BlockStart
  if peek(tokens, i.val) != Identifier("set") {
    raise ParseError("Expected 'set'")
  }
  advance(i)

  let name = match peek(tokens, i.val) {
    Identifier(n) => n
    _ => raise ParseError("Expected variable name after 'set'")
  }
  advance(i)

  if peek(tokens, i.val) != Operator("=") {
    raise ParseError("Expected '=' after variable name")
  }
  advance(i)

  let value = parse_expr!(tokens, i, len)

  match peek(tokens, i.val) {
    BlockEnd(_) => advance(i)
    _ => raise ParseError("Expected '%}' after set expression")
  }

  return SetStmt(name, value)
}

fn parse_with_block(tokens: Array[Token], i: Ref[Int], len: Int) -> Expr!JinjaError {
  advance(i)  // BlockStart
  if peek(tokens, i.val) != Identifier("with") {
    raise ParseError("Expected 'with'")
  }
  advance(i)

  let name = match peek(tokens, i.val) {
    Identifier(n) => n
    _ => raise ParseError("Expected variable name")
  }
  advance(i)

  if peek(tokens, i.val) != Operator("=") {
    raise ParseError("Expected '=' after variable name")
  }
  advance(i)

  let value = parse_expr!(tokens, i, len)

  match peek(tokens, i.val) {
    BlockEnd(_) => advance(i)
    _ => raise ParseError("Expected '%}' after with")
  }

  let body = parse_expr_list!(tokens, i, len)

  match peek(tokens, i.val) {
    BlockStart(_) => {
      advance(i)
      if peek(tokens, i.val) != Identifier("endwith") {
        raise ParseError("Expected 'endwith'")
      }
      advance(i)
      match peek(tokens, i.val) {
        BlockEnd(_) => advance(i)
        _ => raise ParseError("Expected '%}' after 'endwith'")
      }
    }
    _ => raise ParseError("Expected '{% endwith %}'")
  }

  return WithBlock(name, value, body)
}
