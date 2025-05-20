pub fn filter_upper(s: String) -> String {
  let chars = s.to_array()
  let upper_chars = chars.map(fn(c: Char) -> Char {
    if c >= 'a' && c <= 'z' {
      Char::from_int(c.to_int() - 32)
    } else {
      c
    }
  })
  return String::from_array(upper_chars)
}

pub fn filter_lower(s: String) -> String {
  let chars = s.to_array()
  let lower_chars = chars.map(fn(c: Char) -> Char {
    if c >= 'A' && c <= 'Z' {
      Char::from_int(c.to_int() + 32)
    } else {
      c
    }
  })
  return String::from_array(lower_chars)
}

pub fn filter_trim(s: String) -> String {
  return s.trim(" \n\r\t").to_string()
}

// 统一注册并返回
pub fn get_filter(name: String) -> Option[Filter] {
  if name == "upper" {
    return Some(Upper)
  } else if name == "lower" {
    return Some(Lower)
  } else if name == "trim" {
    return Some(Trim)
  } else {
    return None
  }
}
