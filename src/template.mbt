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
  IncludeNode(String)
  BlockNode(String, Array[Expr])
  Sequence(Array[Expr])
}

pub enum Value {
  IntValue(Int)
  BoolValue(Bool)
  StrValue(String)
  ListValue(Array[Value])
}

pub enum Filter {
  Upper
  Lower
  Trim
}

/// 用于 block 继承合并的辅助结构
pub type BlockMap Map[String, Array[Expr]]
fn render_template(template: String, context: Map[String, Value]) -> String!JinjaError {
  let tokens: Array[Token] = tokenize!(template)
  let ast: Expr = parse!(tokens)
  return render!(ast, context)
}

fn render_templates(template: String, context: Map[String, Value]) -> String {
  match render_template?(template, context) {
    Ok(result) => return result
    Err(err) => return error_to_string(err)
  }
}

/// include 模板加载器（需在实际使用中改为从文件系统读取）
pub fn load_template(name: String) -> String!JinjaError {
  if name == "header.html" {
    return "<h1>Header Content</h1>"
  } else if name == "footer.html" {
    return "<footer>Footer Here</footer>"
  } else if name == "base.html" {
    return "<body>{% block content %}{% endblock %}</body>"
  } else if name == "with-block.html" {
    return "{% block message %}Default{% endblock %}"  
  } else {
    raise RenderError("Template not found: " + name)
  }
}


