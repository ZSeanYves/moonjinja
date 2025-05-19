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


pub enum Expr {
  TextNode(String)
  VariableNode(String)
  BinaryOp(Expr, String, Expr)
  LiteralNode(String)
  IfBlock(Expr, Array[Expr], Array[Expr])
  ForBlock(String, Expr, Array[Expr])
  Sequence(Array[Expr])
}

pub enum Value {
  IntValue(Int)
  BoolValue(Bool)
  StrValue(String)
  ListValue(Array[Value])
}

fn render_template(template: String, context: Map[String, Value]) -> String!JinjaError {
  let tokens: Array[Token] = tokenize!(template)
  let ast: Expr = parse!(tokens)
  return render!(ast, context)
}

fn render_templates(template: String, context: Map[String, Value]) -> String {
  match render_template?(template, context) {
    Ok(result) => return result
    Err(err) => return to_string(err)
  }
}
