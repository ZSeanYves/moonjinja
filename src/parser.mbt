pub enum Expr {
  TextNode(String)
  VariableNode(String)
  BinaryOp(Expr, String, Expr)
  LiteralNode(String)
  IfBlock(Expr, Array[Expr], Array[Expr])
  ForBlock(String, Expr, Array[Expr])
  Sequence(Array[Expr])
}

fn parse(tokens: Array[Token]) -> Expr!ParseError {
  let i = { val: 0 }
  let len = tokens.length()
  return parse_template!(tokens, i, len)
}

fn parse_template(tokens: Array[Token], i: Ref[Int], len: Int) -> Expr!ParseError {
  let body = parse_expr_list!(tokens, i, len)
  return Sequence(body)
}

fn parse_expr_list(tokens: Array[Token], i: Ref[Int], len: Int) -> Array[Expr]!ParseError {
  let exprs = []
  while i.val < len && not(peek(tokens, i.val) == EOF) {
    let tok = peek(tokens, i.val)
    if tok == BlockStart {
      let next = if i.val + 1 < len { tokens[i.val + 1] } else { EOF }
      match next {
        Identifier("if") => {
          let expr = parse_if_block!(tokens, i, len)
          exprs.push(expr)
        }
        Identifier("for") => {
          let expr = parse_for_block!(tokens, i, len)
          exprs.push(expr)
        }
        _ => raise UnexpectedToken("Unknown block tag")
      }
    } else {
      let expr = parse_expr!(tokens, i, len)
      exprs.push(expr)
    }
  }
  return exprs
}

fn parse_expr(tokens: Array[Token], i: Ref[Int], len: Int) -> Expr!ParseError {
  return parse_binary_expr!(tokens, i, len, 1)
}

fn parse_binary_expr(tokens: Array[Token], i: Ref[Int], len: Int, min_prec: Int) -> Expr!ParseError {
  let mut left = parse_primary!(tokens, i, len)

  while true {
    let tok = peek(tokens, i.val)
    match tok {
      Operator(op) => {
        let prec = get_precedence(op)
        if prec < min_prec {
          break
        }
        advance(i)

        let right = parse_binary_expr!(tokens, i, len, prec + 1)
        left = BinaryOp(left, op, right)
      }
      _ => break
    }
  }
  return left
}

fn parse_primary(tokens: Array[Token], i: Ref[Int], len: Int) -> Expr!ParseError {
  let tok = peek(tokens, i.val)
  match tok {
    Text(s) => {
      advance(i)
      return TextNode(s)
    }
    Identifier(name) => {
      advance(i)
      return VariableNode(name)
    }
    Literal(value) => {
      advance(i)
      return LiteralNode(value)
    }
    _ => raise UnexpectedToken("Unsupported token: if-block start")
  }
}

fn parse_if_block(tokens: Array[Token], i: Ref[Int], len: Int) -> Expr!ParseError {
  advance(i)
  if peek(tokens, i.val) != Identifier("if") {
    raise UnexpectedToken("Expected 'if' after '{%'")
  }
  advance(i)

  let condition = parse_expr!(tokens, i, len)
  if peek(tokens, i.val) != BlockEnd {
    raise UnexpectedToken("Expected '%}' after if condition")
  }
  advance(i)

  let then_body = parse_expr_list!(tokens, i, len)
  let else_body = []

  if peek(tokens, i.val) == BlockStart && i.val + 1 < len && tokens[i.val + 1] == Identifier("else") {
    advance(i)  // BlockStart
    advance(i)  // else
    if peek(tokens, i.val) != BlockEnd {
      raise UnexpectedToken("Expected '%}' after 'else'")
    }
    advance(i)
    let parsed_else = parse_expr_list!(tokens, i, len)
    for e in parsed_else { else_body.push(e) }
  }

  if peek(tokens, i.val) == BlockStart {
    advance(i)
    if peek(tokens, i.val) != Identifier("endif") {
      raise UnexpectedToken("Expected 'endif'")
    }
    advance(i)
    if peek(tokens, i.val) != BlockEnd {
      raise UnexpectedToken("Expected '%}' after 'endif'")
    }
    advance(i)
  } else {
    raise UnexpectedToken("Expected '{% endif %}'")
  }

  return IfBlock(condition, then_body, else_body)
}

fn parse_for_block(tokens: Array[Token], i: Ref[Int], len: Int) -> Expr!ParseError {
  advance(i)
  if peek(tokens, i.val) != Identifier("for") {
    raise UnexpectedToken("Expected 'for' after '{%'")
  }
  advance(i)

  let var_tok = peek(tokens, i.val)
  let loop_var = match var_tok {
    Identifier(name) => name
    _ => raise UnexpectedToken("Expected loop variable name")
  }
  advance(i)

  if peek(tokens, i.val) != Identifier("in") {
    raise UnexpectedToken("Expected 'in' in for loop")
  }
  advance(i)

  let iterable = parse_expr!(tokens, i, len)

  if peek(tokens, i.val) != BlockEnd {
    raise UnexpectedToken("Expected '%}' after for loop header")
  }
  advance(i)

  let body = parse_expr_list!(tokens, i, len)

  if peek(tokens, i.val) == BlockStart {
    advance(i)
    if peek(tokens, i.val) != Identifier("endfor") {
      raise UnexpectedToken("Expected 'endfor'")
    }
    advance(i)
    if peek(tokens, i.val) != BlockEnd {
      raise UnexpectedToken("Expected '%}' after 'endfor'")
    }
    advance(i)
  } else {
    raise UnexpectedToken("Expected '{% endfor %}'")
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
