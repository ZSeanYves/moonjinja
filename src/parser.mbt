pub enum Expr {
  TextNode(String)
  VariableNode(String)
  BinaryOp(Expr, String, Expr)
  LiteralNode(String)
  IfBlock(Expr, Array[Expr])
  ForBlock(String, Expr, Array[Expr])
  Sequence(Array[Expr])
}

fn parse(tokens: Array[Token]) -> Expr!ParseError {
  let mut i = 0
  let len = tokens.length()

  fn peek() -> Token {
    if i < len {
      return tokens[i]
    } else {
      return EOF
    }
  }

  fn advance() {
    i += 1
  }

  fn get_precedence(op: String) -> Int {
    match op {
      "==" => 1
      "+" | "-" => 2
      "*" | "/" => 3
      _ => 0
    }
  }

  fn parse_primary() -> Expr!ParseError {
    let tok = peek()
    match tok {
      Text(s) => {
        advance()
        return TextNode(s)
      }
      Identifier(name) => {
        advance()
        return VariableNode(name)
      }
      Literal(value) => {
        advance()
        return LiteralNode(value)
      }
      _ => raise UnexpectedToken("Unsupported token: if-block start")
    }
  }

  fn parse_binary_expr(min_prec: Int) -> Expr!ParseError {
    let mut left = parse_primary!()

    while true {
      let tok = peek()
      match tok {
        Operator(op) => {
          let prec = get_precedence(op)
          if prec < min_prec {
            break
          }
          advance()

          let right = parse_binary_expr!(prec + 1)
          left = BinaryOp(left, op, right)
        }
        _ => break
      }
    }
    return left
  }

  fn parse_expr() -> Expr!ParseError {
    return parse_binary_expr!(1)
  }

  fn parse_if_block() -> Expr!ParseError {
    advance()  // BlockStart
    if peek() != Identifier("if") {
      raise UnexpectedToken("Expected 'if' after '{%'")
    }
    advance()

    let condition = parse_expr!()
    if peek() != BlockEnd {
      raise UnexpectedToken("Expected '%}' after if condition")
    }
    advance()

    let then_body = parse_expr_list!()

    if peek() == BlockStart {
      advance()
      if peek() != Identifier("endif") {
        raise UnexpectedToken("Expected 'endif'")
      }
      advance()
      if peek() != BlockEnd {
        raise UnexpectedToken("Expected '%}' after 'endif'")
      }
      advance()
    } else {
      raise UnexpectedToken("Expected '{% endif %}'")
    }

    return IfBlock(condition, then_body)
  }

  fn parse_for_block() -> Expr!ParseError {
    advance() // BlockStart
    if peek() != Identifier("for") {
      raise UnexpectedToken("Expected 'for' after '{%'")
    }
    advance()

    let var_tok = peek()
    let loop_var = match var_tok {
      Identifier(name) => name
      _ => raise UnexpectedToken("Expected loop variable name")
    }
    advance()

    if peek() != Identifier("in") {
      raise UnexpectedToken("Expected 'in' in for loop")
    }
    advance()

    let iterable = parse_expr!()

    if peek() != BlockEnd {
      raise UnexpectedToken("Expected '%}' after for loop header")
    }
    advance()

    let body = parse_expr_list!()

    if peek() == BlockStart {
      advance()
      if peek() != Identifier("endfor") {
        raise UnexpectedToken("Expected 'endfor'")
      }
      advance()
      if peek() != BlockEnd {
        raise UnexpectedToken("Expected '%}' after 'endfor'")
      }
      advance()
    } else {
      raise UnexpectedToken("Expected '{% endfor %}'")
    }

    return ForBlock(loop_var, iterable, body)
  }

  fn parse_expr_list() -> Array[Expr]!ParseError {
    let exprs = []
    while i < len && not(peek() == EOF) {
      let tok = peek()
      if tok == BlockStart {
        let next = if i + 1 < len { tokens[i + 1] } else { EOF }
        match next {
          Identifier("if") => {
            let expr = parse_if_block!()
            exprs.push(expr)
          }
          Identifier("for") => {
            let expr = parse_for_block!()
            exprs.push(expr)
          }
          _ => raise UnexpectedToken("Unknown block tag")
        }
      } else {
        let expr = parse_expr!()
        exprs.push(expr)
      }
    }
    return exprs
  }

  fn parse_template() -> Expr!ParseError {
    let body = parse_expr_list!()
    return Sequence(body)
  }

  return parse_template!()
}
