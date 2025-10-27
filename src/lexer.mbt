// Token types used by the lexer

///|
pub(all) enum Token {
  Text(String) // Plain text
  VarStart(Bool) // Start of a variable tag: {{ or {{- (with strip_left)
  VarEnd(Bool) // End of a variable tag: }} or -}}
  BlockStart(Bool) // Start of a control block: {% or {%- (with strip_left)
  BlockEnd(Bool) // End of a control block: %} or -%}
  CommentStart // Start of a comment tag: {#
  CommentEnd // End of a comment tag: #}
  Identifier(String) // Keywords or variable names
  Literal(String) // String or numeric literals
  Operator(String) // Operators: ==, +, -, etc.
  Delimiter(Char) // Symbols: (, ), :, ., ,
  EOF // End of input
}

// Equality comparison for tokens

// Convert a token to its string representation (for debugging)

///|
//fn token_to_string(tok : Token) -> String {
//  match tok {
//    Text(s) => "Text(" + s + ")"
//    VarStart(strip) => "VarStart(" + strip.to_string() + ")"
//    VarEnd(strip) => "VarEnd(" + strip.to_string() + ")"
//    BlockStart(strip) => "BlockStart(" + strip.to_string() + ")"
//    BlockEnd(strip) => "BlockEnd(" + strip.to_string() + ")"
//    CommentStart => "CommentStart"
//    CommentEnd => "CommentEnd"
//    Identifier(s) => "Identifier(" + s + ")"
//    Literal(s) => "Literal(" + s + ")"
//    Operator(s) => "Operator(" + s + ")"          // ← 加上
//    Delimiter(c) => "Delimiter(" + c.to_string() + ")"  // ← 加上
//    EOF => "EOF"
//  }
//}


// Main lexer function: converts source string into a list of tokens

///|
pub fn tokenize(source : String) -> Array[Token] raise JinjaError {
  let tokens : Ref[Array[Token]] = { val: [] }
  let chars = source.to_array()
  let i : Ref[Int] = { val: 0 }
  let len = chars.length()
  if len == 0 {
    raise LexerError("Empty source string")
  }
  while i.val < len {
    let curr = chars[i.val]
    //println("tokenize: index=\{i.val}, char='\{curr}'")

    // === Handle {{ (expression start) ===
    if i.val + 1 < len && curr == '{' && chars[i.val + 1] == '{' {
      let strip_right = i.val + 2 < len && chars[i.val + 2] == '-'
      tokens.val.push(VarStart(strip_right))
      //println("Detected VarStart (strip=\{strip_right}) at index \{i.val}")
      i.val += if strip_right { 3 } else { 2 }
      parse_expr_content(chars, i, tokens)
      continue
    }

    // === Handle {% (block start) ===
    if i.val + 1 < len && curr == '{' && chars[i.val + 1] == '%' {
      let strip_right = i.val + 2 < len && chars[i.val + 2] == '-'
      tokens.val.push(BlockStart(strip_right))
      //println("Detected BlockStart (strip=\{strip_right}) at index \{i.val}")
      i.val += if strip_right { 3 } else { 2 }
      parse_block_content(chars, i, tokens)
      continue
    }

    // === Handle {# (comment start) ===
    if i.val + 1 < len && curr == '{' && chars[i.val + 1] == '#' {
      tokens.val.push(CommentStart)
      //println("Detected CommentStart at index \{i.val}")
      i.val += 2
      skip_comment_block(chars, i, tokens)
      continue
    }

    // === Fallback: Text block ===
    let start = i.val
    while i.val < len {
      let c = chars[i.val]
      if c == '{' && i.val + 1 < len {
        let peek = chars[i.val + 1]
        if peek == '{' || peek == '%' || peek == '#' {
          break
        }
      }
      i.val += 1
    }
    if start < i.val {
      let text_chars : Array[Char] = []
      for k in start..<i.val {
        text_chars.push(chars[k])
      }
      let text = String::from_array(text_chars)
      //println("Detected Text block: '\{text}'")
      tokens.val.push(Text(text))
    }
  }
  tokens.val.push(EOF)
  //println("Final token list: \{tokens.val.map(token_to_string)}")
  return tokens.val
}

// 通用的 block / expression 内容解析函数

///|
fn parse_expr_content(
  chars : Array[Char],
  i : Ref[Int],
  tokens : Ref[Array[Token]],
) -> Unit raise JinjaError {
  parse_tag_content(chars, i, tokens, "}}")
}

///|
fn parse_block_content(
  chars : Array[Char],
  i : Ref[Int],
  tokens : Ref[Array[Token]],
) -> Unit raise JinjaError {
  parse_tag_content(chars, i, tokens, "%}")
}

// 跳过注释块 {# ... #}

///|
fn skip_comment_block(
  chars : Array[Char],
  i : Ref[Int],
  tokens : Ref[Array[Token]],
) -> Unit raise JinjaError {
  while i.val + 1 < chars.length() {
    if chars[i.val] == '#' && chars[i.val + 1] == '}' {
      i.val += 2
      return
    }
    i.val += 1
  }
  tokens.val.push(CommentEnd)
  raise LexerError("Unterminated comment block")
}

// 通用 tag 内内容解析函数（支持 expression 和 block）

///|
fn parse_tag_content(
  chars : Array[Char],
  i : Ref[Int],
  tokens : Ref[Array[Token]],
  end_marker : String,
) -> Unit raise JinjaError {
  let len = chars.length()
  //println("parse_tag_content start at index \{i.val}, char = \{chars[i.val]}")
  while i.val < len {
    // 跳过空白字符
    while i.val < len &&
          (chars[i.val] == ' ' || chars[i.val] == '\n' || chars[i.val] == '\t') {
      i.val += 1
    }

    // ==== 新增：优先匹配 "-%}" / "-}}" （当前位置是 '-'）====
    if i.val + 2 < len &&
      chars[i.val] == '-' &&
      chars[i.val + 1].to_int() == end_marker[0] &&
      chars[i.val + 2].to_int() == end_marker[1] {
      // 这是 strip-left 的结束
      tokens.val.push(
        if end_marker == "}}" {
          VarEnd(true)
        } else {
          BlockEnd(true)
        },
      )
      i.val += 3 // 消费 "-%}" 或 "-}}"
      return // 结束当前 tag
    }

    // ==== 原有：匹配 "%}" / "}}" （当前位置是 end_marker[0]）====
    if i.val + 1 < len &&
      chars[i.val].to_int() == end_marker[0] &&
      chars[i.val + 1].to_int() == end_marker[1] {
      // 是否有 strip-left（前一位是 '-'）
      let strip_left = i.val > 0 && chars[i.val - 1] == '-'
      if strip_left {
        tokens.val.push(
          if end_marker == "}}" {
            VarEnd(true)
          } else {
            BlockEnd(true)
          },
        )
        i.val += 3 // 注意：这里仍然消费 "-%}" / "-}}"
      } else {
        tokens.val.push(
          if end_marker == "}}" {
            VarEnd(false)
          } else {
            BlockEnd(false)
          },
        )
        i.val += 2 // 普通 "%}" / "}}"
      }
      return
    }

    //  正常匹配 token 分支
    let c = chars[i.val]
    match c {
      // 标识符
      'a'..='z' | 'A'..='Z' | '_' => {
        let (ident, next_i) = parse_identifier(chars, i.val)
        //println("Parsed Identifier: \{ident}")
        tokens.val.push(Identifier(ident))
        i.val = next_i
      }

      // 字面量（字符串或数字）
      '0'..='9' | '"' | '\'' => {
        let (lit, next_i) = parse_literal(chars, i.val)
        //println("Parsed Literal: \{lit}")
        tokens.val.push(Literal(lit))
        i.val = next_i
      }

      // 操作符
      '=' | '!' | '<' | '>' | '+' | '-' | '*' | '/' | '|' => {
        let (op, next_i) = parse_operator(chars, i.val)
        //println("Parsed Operator: \{op}")
        tokens.val.push(Operator(op))
        i.val = next_i
      }

      // 符号
      '(' | ')' | ':' | '.' | ',' => {
        //println("Parsed Delimiter: \{c}")
        tokens.val.push(Delimiter(c))
        i.val += 1
      }

      // 其他非法字符
      _ => {
        //println("Unexpected character: \{c}")
        raise LexerError("Unexpected character in tag")
      }
    }
    if i.val < len {
      //println("No end marker at index \{i.val}, char = \{chars[i.val]}")
    }
  }
  raise LexerError("Unterminated tag content")
}

///|
fn parse_identifier(
  chars : Array[Char],
  i : Int,
) -> (String, Int) raise JinjaError {
  let mut j = i
  let len = chars.length()
  if j >= len {
    raise LexerError("Unexpected end of input while parsing identifier")
  }
  let start = i
  let s = []
  while j < len &&
        (
          ('a' <= chars[j] && chars[j] <= 'z') ||
          ('A' <= chars[j] && chars[j] <= 'Z') ||
          ('0' <= chars[j] && chars[j] <= '9') ||
          chars[j] == '_'
        ) {
    j += 1
  }
  for k in start..<j {
    s.push(chars[k])
  }
  return (String::from_array(s), j)
}

///|
fn parse_literal(
  chars : Array[Char],
  i : Int,
) -> (String, Int) raise JinjaError {
  let len = chars.length()
  let mut j = i
  let s : Array[Char] = []
  if j >= len {
    raise LexerError("Unexpected end of input while parsing literal")
  }

  // 字符串字面量
  if chars[j] == '"' || chars[j] == '\'' {
    let quote = chars[j]
    j += 1
    let start = j
    while j < len {
      if chars[j] == '\\' && j + 1 < len {
        j += 2
      } else if chars[j] == quote {
        break
      } else {
        j += 1
      }
    }
    if j >= len {
      raise LexerError("Unterminated string literal")
    }
    for k in start..<j {
      s.push(chars[k])
    }
    let lit = String::from_array(s)
    return (lit, j + 1)
  }

  while j < len && '0' <= chars[j] && chars[j] <= '9' {
    s.push(chars[j])
    j += 1
  }
  return (String::from_array(s), j)
}


///|
fn parse_operator(
  chars : Array[Char],
  i : Int,
) -> (String, Int) raise JinjaError {
  let len = chars.length()
  if i >= len {
    raise LexerError("Unexpected end of input while parsing operator")
  }

  // 两字符操作符
  if i + 1 < len {
    let two = String::from_array([chars[i], chars[i + 1]])
    if ["==", "!=", ">=", "<=", "//"].contains(two) {
      return (two, i + 2)
    }
  }

  // 单字符操作符
  return (chars[i].to_string(), i + 1)
}
