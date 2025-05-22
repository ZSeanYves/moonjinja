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
  let tokens = []
  let chars = source.to_array()
  if chars.length() == 0 {
    raise LexerError("Empty source string")
  }
  let mut i = 0
  let len = chars.length()

  while i < len {
    // --- Variable tag: {{ or {{- ---
    if i + 1 < len && chars[i] == '{' && chars[i + 1] == '{' {
      let strip_left = (i > 0 && chars[i - 1] == '-')
      tokens.push(VarStart(strip_left))
      i += if strip_left { 3 } else { 2 }

      // Tokenize contents inside {{ ... }}
      while i + 1 < len && not(chars[i] == '}' && chars[i + 1] == '}') {
        while i < len && " \n\t".to_array().contains(chars[i]) {
          i += 1
        }
        if i >= len {
          raise LexerError("Unterminated variable block")
        }

        let c = chars[i]
        if c == '"' || c == '\'' {
          let (token, new_i) = read_string!(chars, i)
          tokens.push(token)
          i = new_i
        } else if ('a' <= c && c <= 'z') || ('A' <= c && c <= 'Z') || c == '_' {
          let (token, new_i) = read_identifier(chars, i)
          tokens.push(token)
          i = new_i
        } else if '0' <= c && c <= '9' {
          let (token, new_i) = read_number(chars, i)
          tokens.push(token)
          i = new_i
        } else if "+-*/%=!><".to_array().contains(c) {
          let (token, new_i) = read_operator!(chars, i)
          tokens.push(token)
          i = new_i
        } else if "(),.:".to_array().contains(c) {
          tokens.push(read_delimiter(c))
          i += 1
        } else {
          raise LexerError("Unexpected character in expression")
        }
      }

      let strip_right = (i > 0 && chars[i - 1] == '-')
      tokens.push(VarEnd(strip_right))
      i += 2

    } else if i + 1 < len && chars[i] == '{' && chars[i + 1] == '%' {
      let strip_left = (i > 0 && chars[i - 1] == '-')
      tokens.push(BlockStart(strip_left))
      i += if strip_left { 3 } else { 2 }

      // 读取 block 内容直到 %} 出现
      while i + 1 < len && not(chars[i] == '%' && chars[i + 1] == '}') {
        while i < len && " \n\t".to_array().contains(chars[i]) {
          i += 1
        }
        if i >= len {
          raise LexerError("Unterminated block tag")
        }

        let c = chars[i]
        if c == '"' || c == '\'' {
          let (token, new_i) = read_string!(chars, i)
          tokens.push(token)
          i = new_i
        } else if ('a' <= c && c <= 'z') || ('A' <= c && c <= 'Z') || c == '_' {
          let (token, new_i) = read_identifier(chars, i)
          tokens.push(token)
          i = new_i
        } else if '0' <= c && c <= '9' {
          let (token, new_i) = read_number(chars, i)
          tokens.push(token)
          i = new_i
        } else if "+-*/%=!><".to_array().contains(c) {
          let (token, new_i) = read_operator!(chars, i)
          tokens.push(token)
          i = new_i
        } else if "(),.:".to_array().contains(c) {
          tokens.push(read_delimiter(c))
          i += 1
        } else {
          raise LexerError("Unexpected character in block tag")
        }
      }

      if i + 1 >= len {
        raise LexerError("Unterminated block tag")
      }

      // 检查是否是 -%}
      let strip_right = (i >= 2 && chars[i - 1] == '-' && chars[i] == '%')
      tokens.push(BlockEnd(strip_right))

      i += if strip_right { 3 } else { 2 }
      continue
    
    // --- Comment tag: {# ... #} ---
    } else if i + 1 < len && chars[i] == '{' && chars[i + 1] == '#' {
      i += 2
      while i + 1 < len && not(chars[i] == '#' && chars[i + 1] == '}') {
        i += 1
      }
      if i + 1 >= len {
        raise LexerError("Unterminated comment")
      }
      i += 2
      tokens.push(CommentEnd)

    // --- Plain text ---
    } else {
      let start = i
      while i < len && not(i + 1 < len && chars[i] == '{' &&
        ("{#%".to_array().contains(chars[i + 1]))) {
        i += 1
      }
      let text_chars = []
      for j in start..<i {
        text_chars.push(chars[j])
      }
      let text = String::from_array(text_chars)
      tokens.push(Text(text))
    }
  }

  tokens.push(EOF)
  return tokens
}



// Read a quoted string like "hello"
fn read_string(chars: Array[Char], i: Int) -> (Token, Int)!JinjaError {
  let quote = chars[i]
  let j = i + 1
  let str_chars = []

  let mut k = j
  while k < chars.length() && chars[k] != quote {
    str_chars.push(chars[k])
    k += 1
  }

  if k >= chars.length() {
    raise LexerError("Unterminated string literal")
  }

  let s = String::from_array(str_chars)
  return (Literal(s), k + 1)
}

// Read an operator like ==, !=, and, or, not
fn read_operator(chars: Array[Char], i: Int) -> (Token, Int)!JinjaError {
  let len = chars.length()

  // Two-character operators first
  if i + 1 < len {
    let c1 = chars[i]
    let c2 = chars[i + 1]
    if (c1 == '=' && c2 == '=') ||
       (c1 == '!' && c2 == '=') ||
       (c1 == '>' && c2 == '=') ||
       (c1 == '<' && c2 == '=') ||
       (c1 == '/' && c2 == '/') {
      let op_str = String::from_array([c1, c2])
      return (Operator(op_str), i + 2)
    }
  }

  // Keyword operators
  let try_keywords = ["and", "or", "not"]
  for kw in try_keywords {
    let chars_kw = kw.to_array()
    let len_kw = chars_kw.length()

    if i + len_kw <= len {
      let slice = []
      for j in 0..<len_kw {
        slice.push(chars[i + j])
      }
      if slice == chars_kw {
        return (Operator(kw), i + len_kw)
      }
    }
  }

  // One-character operators
  let one_char_ops = ['+', '-', '*', '/', '%', '=', '>', '<', '!']
  if one_char_ops.contains(chars[i]) {
    return (Operator(String::from_array([chars[i]])), i + 1)
  }

  raise LexerError("Unrecognized operator near: " + String::from_array([chars[i]]))
}

// Read delimiters like (, ), :, ., ,
fn read_delimiter(c: Char) -> Token {
  return Delimiter(c)
}

// Read identifiers like variable or keyword names
fn read_identifier(chars: Array[Char], i: Int) -> (Token, Int) {
  let mut j = i
  let len = chars.length()

  while j < len && (
    ('a' <= chars[j] && chars[j] <= 'z') ||
    ('A' <= chars[j] && chars[j] <= 'Z') ||
    ('0' <= chars[j] && chars[j] <= '9') ||
    chars[j] == '_'
  ) {
    j += 1
  }

  let id_chars = []
  for k in i..<j {
    id_chars.push(chars[k])
  }

  return (Identifier(String::from_array(id_chars)), j)
}

// Read numeric literals (supports integers and floats)
fn read_number(chars: Array[Char], i: Int) -> (Token, Int) {
  let mut j = i
  let len = chars.length()

  while j < len && ('0' <= chars[j] && chars[j] <= '9') {
    j += 1
  }

  if j < len && chars[j] == '.' {
    j += 1
    while j < len && ('0' <= chars[j] && chars[j] <= '9') {
      j += 1
    }
  }

  let num_chars = []
  for k in i..<j {
    num_chars.push(chars[k])
  }

  return (Literal(String::from_array(num_chars)), j)
}
