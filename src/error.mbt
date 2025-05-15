type! LexerError {
  UnexpectedChar(String)
  UnterminatedTag(String)
  InvalidToken(String)
}
type!ParseError{
  UnexpectedToken(String)
  UnexpectedEOF
  InvalidSyntax(String)
}
