pub enum Token  {
  Text(String)             // 普通文本
  VarStart                      // {{
  VarEnd                        // }}
  BlockStart                    // {%
  BlockEnd                      // %}
  CommentStart                  // {#
  CommentEnd                    // #}
  Identifier(String)      // 变量名或关键字
  Literal(String)        // 字符串/数字常量
  Operator(String)          // 操作符：如 ==, +, -, etc.
  Delimiter(Char)           // 如 (, ), :, ., ,
  EOF                           // 结束标志
}
 
impl Eq for Token with op_equal(self, other) {
  match (self, other) {
    (Text(s1), Text(s2)) => s1 == s2
    (VarStart, VarStart) => true
    (VarEnd, VarEnd) => true
    (BlockStart, BlockStart) => true
    (BlockEnd, BlockEnd) => true
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

fn token_to_string(tok: Token) -> String {
  match tok {
    Text(s) => "Text(" + s + ")"
    VarStart => "VarStart"
    VarEnd => "VarEnd"
    Identifier(s) => "Identifier(" + s + ")"
    Literal(s) => "Literal(" + s + ")"
    EOF => "EOF"
    _ => "Other"
  }
}


fn tokenize(source: String) -> Array[Token]!LexerError {
  let tokens = []
  let chars = source.to_array()
  if chars.length() == 0 {
    raise InvalidToken("Empty source string")
  }
  let mut i = 0
  let len = chars.length()

  while i < len {
    if i + 1 < len && chars[i] == '{' && chars[i + 1] == '{' {
      tokens.push(VarStart)
      i += 2

      // 解析表达式直到 }}
      while i + 1 < len && not(chars[i] == '}' && chars[i + 1] == '}') {
        // 跳过空白符
        while i < len && (chars[i] == ' ' || chars[i] == '\n' || chars[i] == '\t') {
          i += 1
        }
        if i >= len {
          raise UnterminatedTag("Unterminated variable block")
        }

        let c = chars[i]

        if c == '"' || c == '\'' {
          let (token, new_i) = (read_string!(chars, i))
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
          raise UnexpectedChar("Unexpected character in expression")
        }
      }

      i += 2
      tokens.push(VarEnd)

    } else if i + 1 < len && chars[i] == '{' && chars[i + 1] == '%' {
      tokens.push(BlockStart)
      i += 2

      // 同样处理 block 表达式
      while i + 1 < len && not(chars[i] == '%' && chars[i + 1] == '}') {
        while i < len && (chars[i] == ' ' || chars[i] == '\n' || chars[i] == '\t') {
          i += 1
        }
        if i >= len {
          raise UnterminatedTag("Unterminated block tag")
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
          raise UnexpectedChar("Unexpected character in block tag")
        }
      }

      i += 2
      tokens.push(BlockEnd)

    } else if i + 1 < len && chars[i] == '{' && chars[i + 1] == '#' {
      i += 2
      while i + 1 < len && not(chars[i] == '#' && chars[i + 1] == '}') {
        i += 1
      }
      if i + 1 >= len {
        raise UnterminatedTag("Unterminated comment")
      }
      i += 2
      tokens.push(CommentEnd)

    } else if i + 1 < len && chars[i] == '}' && chars[i + 1] == '}' {
      tokens.push(VarEnd)
      i += 2
    } else if i + 1 < len && chars[i] == '%' && chars[i + 1] == '}' {
      tokens.push(BlockEnd)
      i += 2
    } else if i + 1 < len && chars[i] == '#' && chars[i + 1] == '}' {
      tokens.push(CommentEnd)
      i += 2
    } else if chars[i] == '{' {
      raise UnexpectedChar("Unexpected '{'")
    } else {
      let start = i
      while i < len &&
            not(i + 1 < len && chars[i] == '{' && (
              chars[i + 1] == '{' || chars[i + 1] == '%' || chars[i + 1] == '#')) {
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


fn read_string(chars: Array[Char], i: Int) -> (Token, Int)!LexerError {
  let quote = chars[i]
  let j = i + 1
  let str_chars = []

  let mut k = j
  while k < chars.length() && chars[k] != quote {
    str_chars.push(chars[k])
    k += 1
  }

  if k >= chars.length() {
    raise UnterminatedTag("Unterminated string literal")
  }

  let s = String::from_array(str_chars)
  return (Literal(s), k + 1)
}
fn read_operator(chars: Array[Char], i: Int) -> (Token, Int)!LexerError {
  let len = chars.length()

  // 两字符运算符优先匹配
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

  // 关键字运算符：and, or, not
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
      let op_str = kw
      return (Operator(op_str), i + len_kw)
    }
  }
  }
  // 单字符运算符
  let one_char_ops = ['+', '-', '*', '/', '%', '=', '>', '<', '!']
  if one_char_ops.contains(chars[i]) {
    let op_str = String::from_array([chars[i]])
    return (Operator(op_str), i + 1)
  }

  // 否则不是运算符
  raise InvalidToken("Unrecognized operator near: " + String::from_array([chars[i]]))
}

fn read_delimiter(c: Char) -> Token {
  return Delimiter(c)
}

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

  let id = String::from_array(id_chars)
  return (Identifier(id), j)
}

fn read_number(chars: Array[Char], i: Int) -> (Token, Int) {
  let mut j = i
  let len = chars.length()

  // 读取整数部分
  while j < len && ('0' <= chars[j] && chars[j] <= '9') {
    j += 1
  }

  // 检查小数点后是否还有数字
  if j < len && chars[j] == '.' {
    j += 1
    while j < len && ('0' <= chars[j] && chars[j] <= '9') {
      j += 1
    }
  }

  // 构建字符串
  let num_chars = []
  for k in i..<j {
    num_chars.push(chars[k])
  }

  let num_str = String::from_array(num_chars)
  return (Literal(num_str), j)
}

