type! LexerError {
  UnexpectedChar(String)
  UnterminatedTag(String)
  InvalidToken(String)
}
type! ParseError{
  UnexpectedToken(String)
  UnexpectedEOF(String)
  InvalidSyntax(String)
}

type! RenderError {
  MissingVariable(String)
  UnsupportedOperator(String)
  InvalidIteration(String)
}