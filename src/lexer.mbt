// Token types used by the lexer
pub enum Token  {
  Text(String)               // Plain text
  VarStart(Bool)             // Start of a variable tag: {{ or {{- (with strip_left)
  VarEnd(Bool)               // End of a variable tag: }} or -}}
  BlockStart(Bool)           // Start of a control block: {% or {%- (with strip_left)
  BlockEnd(Bool)             // End of a control block: %} or -%}
  CommentStart               // Start of a comment tag: {#
  CommentEnd                 // End of a comment tag: #}
  Identifier(String)         // Keywords or variable names
  Literal(String)            // String or numeric literals
  Operator(String)           // Operators: ==, +, -, etc.
  Delimiter(Char)            // Symbols: (, ), :, ., ,
  EOF                        // End of input
}

// Equality comparison for tokens
impl Eq for Token with op_equal(self, other) {
  match (self, other) {
    (Text(s1), Text(s2)) => s1 == s2
    (VarStart(a), VarStart(b)) => a == b
    (VarEnd(a), VarEnd(b)) => a == b
    (BlockStart(a), BlockStart(b)) => a == b
    (BlockEnd(a), BlockEnd(b)) => a == b
    (CommentStart, CommentStart) => true
    (CommentEnd, CommentEnd) => true
    (Identifier(s1), Identifier(s2)) => s1 == s2
    (Literal(s1), Literal(s2)) => s1 == s2
    (Operator(s1), Operator(s2)) => s1 == s2
    (Delimiter(c1), Delimiter(c2)) => c1 == c2
    (EOF, EOF) => true
    _ => false
  }
}

// Convert a token to its string representation (for debugging)
fn token_to_string(tok: Token) -> String {
  match tok {
    Text(s) => "Text(" + s + ")"
    VarStart(strip) => "VarStart(" + strip.to_string() + ")"
    VarEnd(strip) => "VarEnd(" + strip.to_string() + ")"
    BlockStart(strip) => "BlockStart(" + strip.to_string() + ")"
    BlockEnd(strip) => "BlockEnd(" + strip.to_string() + ")"
    Identifier(s) => "Identifier(" + s + ")"
    Literal(s) => "Literal(" + s + ")"
    EOF => "EOF"
    _ => "Other"
  }
}


// Main lexer function: converts source string into a list of tokens
fn tokenize(source: String) -> Array[Token]!JinjaError {
  let tokens: Ref[Array[Token]] = { val: [] }
  let chars = source.to_array()
  let i: Ref[Int] = { val: 0 }
  let len = chars.length()

  if len == 0 {
    raise LexerError("Empty source string")
  }

  while i.val < len {
    let curr = chars[i.val]
    println("tokenize: index=\{i.val}, char='\{curr}'")

    // === Handle {{ (expression start) ===
    if i.val + 1 < len && curr == '{' && chars[i.val + 1] == '{' {
      let strip_right = i.val + 2 < len && chars[i.val + 2] == '-'
      tokens.val.push(VarStart(strip_right))
      println("Detected VarStart (strip=\{strip_right}) at index \{i.val}")
      i.val += if strip_right { 3 } else { 2 }

      parse_expr_content!(chars, i, tokens)
      continue
    }

    // === Handle {% (block start) ===
    if i.val + 1 < len && curr == '{' && chars[i.val + 1] == '%' {
      let strip_right = i.val + 2 < len && chars[i.val + 2] == '-'
      tokens.val.push(BlockStart(strip_right))
      println("Detected BlockStart (strip=\{strip_right}) at index \{i.val}")
      i.val += if strip_right { 3 } else { 2 }

      parse_block_content!(chars, i, tokens)
      continue
    }

    // === Handle {# (comment start) ===
    if i.val + 1 < len && curr == '{' && chars[i.val + 1] == '#' {
      tokens.val.push(CommentStart)
      println("Detected CommentStart at index \{i.val}")
      i.val += 2
      skip_comment_block!(chars, i, tokens)
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
      let text_chars: Array[Char] = []
      for k in start..<i.val {
        text_chars.push(chars[k])
      }
      let text = String::from_array(text_chars)
      println("Detected Text block: '\{text}'")
      tokens.val.push(Text(text))
    }
  }

  tokens.val.push(EOF)
  println("Final token list: \{tokens.val.map(token_to_string)}")
  return tokens.val
}




// 通用的 block / expression 内容解析函数
fn parse_expr_content(chars: Array[Char], i: Ref[Int], tokens: Ref[Array[Token]]) -> Unit!JinjaError {
  parse_tag_content!(chars, i, tokens, "}}")
}

fn parse_block_content(chars: Array[Char], i: Ref[Int], tokens: Ref[Array[Token]]) -> Unit!JinjaError {
  parse_tag_content!(chars, i, tokens, "%}")
}

// 跳过注释块 {# ... #}
fn skip_comment_block(chars: Array[Char], i: Ref[Int], tokens: Ref[Array[Token]]) -> Unit!JinjaError {
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
fn parse_tag_content(chars: Array[Char], i: Ref[Int], tokens: Ref[Array[Token]], end_marker: String) -> Unit!JinjaError {
  let len = chars.length()
  println("parse_tag_content start at index \{i.val}, char = \{chars[i.val]}")
  while i.val < len {
        //  跳过空白字符以便正确识别结尾符
    while i.val < len && (chars[i.val] == ' ' || chars[i.val] == '\n' || chars[i.val] == '\t') {
      i.val += 1
    }
    //  检查是否遇到结束符（支持 -%} 和 -}}）
    if i.val + 1 < len && chars[i.val] == end_marker[0] && chars[i.val + 1] == end_marker[1] {
      // 检查是否有 strip_left 标记
      let strip_left = i.val + 2 < len && chars[i.val - 1] == '-'
      if strip_left {
        tokens.val.push( if end_marker == "}}" { VarEnd(true) } else { BlockEnd(true) })
        i.val += 3
      } else {
        tokens.val.push( if end_marker == "}}" { VarEnd(false) } else { BlockEnd(false) })
        i.val += 2
      }
      println("Detected \{end_marker} at index \{i.val}, strip_left = \{strip_left}")
      return
    }


    // 🔽 正常匹配 token 分支
    let c = chars[i.val]
    match c {
      'a'..='z' | 'A'..='Z' | '_' => {
        let (ident, next_i) = parse_identifier!(chars, i.val)
        println("Parsed Identifier: \{ident}")
        tokens.val.push(Identifier(ident))
        i.val = next_i
      }
      '0'..='9' | '"' => {
        let (lit, next_i) = parse_literal!(chars, i.val)
        println("Parsed Literal: \{lit}")
        tokens.val.push(Literal(lit))
        i.val = next_i
      }
      '=' | '!' | '<' | '>' | '+' | '-' | '*' | '/' | '|' => {
        let (op, next_i) = parse_operator!(chars, i.val)
        println("Parsed Operator: \{op}")
        tokens.val.push(Operator(op))
        i.val = next_i
      }
      '(' | ')' | ':' | '.' | ',' => {
        println("Parsed Delimiter: \{c}")
        tokens.val.push(Delimiter(c))
        i.val += 1
      }
      _ => {
        println("Unexpected character: \{c}")
        raise LexerError("Unexpected character in tag")
      }
    }
    println("No end marker at index \{i.val}, char = \{chars[i.val]}")
  }

  raise LexerError("Unterminated tag content")
}




fn parse_identifier(chars: Array[Char], i: Int) -> (String, Int)!JinjaError {
  let mut j = i
  let len = chars.length()
  if j >= len {
    raise LexerError("Unexpected end of input while parsing identifier")
  }
  let start = i
  let s = []
  while j < len && (
    ('a' <= chars[i] && chars[i] <= 'z') ||
    ('A' <= chars[i] && chars[i] <= 'Z') ||
    ('0' <= chars[i] && chars[i] <= '9') ||
    chars[i] == '_'
  ) {
    j += 1
  }
  for k in start..<j {
    s.push(chars[k])
  }
  return (String::from_array(s), j)
}

fn parse_literal(chars: Array[Char], i: Int) -> (String, Int)!JinjaError {
  let len = chars.length()
  let mut j = i
  let s = []
  if j >= len {
    raise LexerError("Unexpected end of input while parsing literal")
  }
  if chars[j] == '"' {
    j += 1
    let start = j
    while j < len {
      if chars[j] == '\\' && j + 1 < len {
        j += 2  // 跳过转义字符
      } else if chars[j] == '"' {
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
  let start = i
  while j < len && '0' <= chars[j] && chars[j] <= '9' {
    j += 1
  }
  for k in start..<j {
    s.push(chars[k])
  }
  return (String::from_array(s), j)
}

fn parse_operator(chars: Array[Char], i: Int) -> (String, Int)!JinjaError {
  let len = chars.length()
  if i >= len {
    raise LexerError("Unexpected end of input while parsing operator")
  }
  if i + 1 < len && ["==", "!=", ">=", "<="].contains(String::from_array([chars[i], chars[i+1]])) {
    return (String::from_array([chars[i], chars[i+1]]), i + 2)
  }
  return (chars[i].to_string(), i + 1)
}