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


 

pub fn load_template(name: String) -> String!JinjaError {

}


