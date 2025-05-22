pub enum Filter {
  Upper
  Lower
  Trim
}

fn filter_upper(s: String) -> String {
  return s.to_upper()
}

fn filter_lower(s: String) -> String {
  return s.to_lower()
}

fn filter_trim(s: String) -> String {
  return s.trim(" \n\r\t").to_string()
}


fn get_filter(name: String) -> Option[Filter] {
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


fn escape_html(input: String) -> String {
  let mut result = input
  result = result.replace(old="&", new="&amp;")
  result = result.replace(old="<", new="&lt;")
  result = result.replace(old=">", new="&gt;")
  result = result.replace(old="\"", new="&quot;")
  result = result.replace(old="'", new="&#39;")
  return result
}



