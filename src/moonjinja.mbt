pub fn render_template(template: String, context: Map[String, Value]) -> String!JinjaError {
  let tokens: Array[Token] = tokenize!(template)
  let ast: Expr = parse!(tokens)
  return render!(ast, context)
}

pub fn render_templates(template: String, context: Map[String, Value]) -> String {
  match render_template?(template, context) {
    Ok(result) => return result
    Err(err) => return error_to_string(err)
  }
}


pub fn ctx_str(key: String, val: String) -> Map[String, Value] {
  let ctx = Map::new()
  ctx[key] = StrValue(val)
  return ctx
}

pub fn ctx_int(key: String, val: Int) -> Map[String, Value] {
  let ctx = Map::new()
  ctx[key] = IntValue(val)
  return ctx
}

pub fn ctx_bool(key: String, val: Bool) -> Map[String, Value] {
  let ctx = Map::new()
  ctx[key] = BoolValue(val)
  return ctx
}

pub fn ctx_list_str(key: String, arr: Array[String]) -> Map[String, Value] {
  let ctx = Map::new()
  let list = arr.map(fn(s) { StrValue(s) })
  ctx[key] = ListValue(list)
  return ctx
}

pub fn ctx_list_int(key: String, arr: Array[Int]) -> Map[String, Value] {
  let ctx = Map::new()
  let list = arr.map(fn(n) { IntValue(n) })
  ctx[key] = ListValue(list)
  return ctx
}
