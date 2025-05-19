priv type! JinjaError {
  LexerError(String)
  ParseError(String)
  RenderError(String)
}
fn to_string(e: JinjaError) -> String {
  match e {
    LexerError(msg) => return "[LexerError] " + msg
    ParseError(msg) => return "[ParseError] " + msg
    RenderError(msg) => return "[RenderError] " + msg
  }
}
