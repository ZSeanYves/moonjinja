fn parse(tokens: Array[Token]) -> Expr!JinjaError {
  let i = { val: 0 }
  let len = tokens.length()
  return parse_template!(tokens, i, len)
}

fn parse_template(tokens: Array[Token], i: Ref[Int], len: Int) -> Expr!JinjaError {
  // 检查是否是 extends 开头
  if i.val + 2 < len && tokens[i.val] == BlockStart && tokens[i.val + 1] == Identifier("extends") {
    return parse_extends!(tokens, i, len)
  }
  let body = parse_expr_list!(tokens, i, len)
  return Sequence(body)
}

fn parse_expr_list(tokens: Array[Token], i: Ref[Int], len: Int) -> Array[Expr]!JinjaError {
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
        Identifier("include") => {
          let expr = parse_include!(tokens, i, len)
          exprs.push(expr)
        }
        Identifier("block") => {
          let expr = parse_block!(tokens, i, len)
          exprs.push(expr)
        }
        _ => raise ParseError("Unknown block tag")
      }
    } else {
      let expr = parse_expr!(tokens, i, len)
      exprs.push(expr)
    }
  }
  return exprs
}


fn parse_expr(tokens: Array[Token], i: Ref[Int], len: Int) -> Expr!JinjaError {
  return parse_binary_expr!(tokens, i, len, 1)
}

fn parse_binary_expr(tokens: Array[Token], i: Ref[Int], len: Int, min_prec: Int) -> Expr!JinjaError {
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

fn parse_primary(tokens: Array[Token], i: Ref[Int], _len: Int) -> Expr!JinjaError {
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
    _ => raise ParseError("Unsupported token: if-block start")
  }
}

fn parse_if_block(tokens: Array[Token], i: Ref[Int], len: Int) -> Expr!JinjaError {
  advance(i)
  if peek(tokens, i.val) != Identifier("if") {
    raise ParseError("Expected 'if' after '{%'")
  }
  advance(i)

  let condition = parse_expr!(tokens, i, len)
  if peek(tokens, i.val) != BlockEnd {
    raise ParseError("Expected '%}' after if condition")
  }
  advance(i)

  let then_body = parse_expr_list!(tokens, i, len)
  let else_body = []

  if peek(tokens, i.val) == BlockStart && i.val + 1 < len && tokens[i.val + 1] == Identifier("else") {
    advance(i)  // BlockStart
    advance(i)  // else
    if peek(tokens, i.val) != BlockEnd {
      raise ParseError("Expected '%}' after 'else'")
    }
    advance(i)
    let parsed_else = parse_expr_list!(tokens, i, len)
    for e in parsed_else { else_body.push(e) }
  }

  if peek(tokens, i.val) == BlockStart {
    advance(i)
    if peek(tokens, i.val) != Identifier("endif") {
      raise ParseError("Expected 'endif'")
    }
    advance(i)
    if peek(tokens, i.val) != BlockEnd {
      raise ParseError("Expected '%}' after 'endif'")
    }
    advance(i)
  } else {
    raise ParseError("Expected '{% endif %}'")
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

  if peek(tokens, i.val) != BlockEnd {
    raise ParseError("Expected '%}' after for loop header")
  }
  advance(i)

  let body = parse_expr_list!(tokens, i, len)

  if peek(tokens, i.val) == BlockStart {
    advance(i)
    if peek(tokens, i.val) != Identifier("endfor") {
      raise ParseError("Expected 'endfor'")
    }
    advance(i)
    if peek(tokens, i.val) != BlockEnd {
      raise ParseError("Expected '%}' after 'endfor'")
    }
    advance(i)
  } else {
    raise ParseError("Expected '{% endfor %}'")
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
      if peek(tokens, i.val) != BlockEnd {
        raise ParseError("Expected '%}' after include")
      }
      advance(i)
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
      if peek(tokens, i.val) != BlockEnd {
        raise ParseError("Expected '%}' after block name")
      }
      advance(i)

      let body = parse_expr_list!(tokens, i, len)

      if peek(tokens, i.val) == BlockStart {
        advance(i)
        if peek(tokens, i.val) != Identifier("endblock") {
          raise ParseError("Expected 'endblock'")
        }
        advance(i)
        if peek(tokens, i.val) != BlockEnd {
          raise ParseError("Expected '%}' after 'endblock'")
        }
        advance(i)
      } else {
        raise ParseError("Expected '{% endblock %}'")
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
      if peek(tokens, i.val) != BlockEnd {
        raise ParseError("Expected '%}' after extends")
      }
      advance(i)

      // 收集所有 block 定义
      let blocks = Map::new()
      while i.val < len && not(peek(tokens, i.val) == EOF) {
        if peek(tokens, i.val) == BlockStart {
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
            // extends 模板中不能有非 block 结构
            raise ParseError("Only 'block' allowed in child template with extends")
          }
        } else {
          // 非 block 开头也非法
          raise ParseError("Unexpected content in child template with extends")
        }
      }

      return ExtendsNode(filename, blocks)
    }
    _ => raise ParseError("Expected file name after 'extends'")
  }
}
