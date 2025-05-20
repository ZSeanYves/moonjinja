fn render(expr: Expr, context: Map[String, Value]) -> String!JinjaError {
  match expr {
    TextNode(s) => return s
    VariableNode(name) => {
      // 支持 {{ var | filter }} 格式
      let parts = name.split("|").to_array()
      let var_name = parts[0].trim("").to_string()
      let filter_name = if parts.length() > 1 { parts[1].trim("").to_string() } else { "" }

      match context.get(var_name) {
        Some(v) => {
          let base = value_to_string(v)
          if filter_name == "" {
            return base
          } else {
          match get_filter(filter_name) {
            Some(Upper) => return filter_upper(base)
            Some(Lower) => return filter_lower(base)
            Some(Trim) => return filter_trim(base)
            None => raise RenderError("Unknown filter: " + filter_name)
          }
          }
        }
        None => raise RenderError("Variable not found: " + var_name)
      }
    }

    LiteralNode(s) => return s
    BinaryOp(lhs, op, rhs) => {
      let left = render!(lhs, context)
      let right = render!(rhs, context)
      return apply_operator!(left, op, right)
    }
    IfBlock(cond, then_body, else_body) => {
      let cond_val = eval_condition!(cond, context)
      if cond_val {
        return render_sequence!(then_body, context)
      } else {
        return render_sequence!(else_body, context)
      }
    }
    ForBlock(var, list_expr, body) => {
      let result = []
      let iterable = eval_list!(list_expr, context)
      for item in iterable {
        let new_ctx = context
        new_ctx[var] = item
        result.push(render_sequence!(body, new_ctx))
      }
      return result.join("")
    }
    Sequence(exprs) => return render_sequence!(exprs, context)
    IncludeNode(filename) => {
      let tpl = load_template!(filename)
      let tokens = tokenize!(tpl)
      let ast = parse!(tokens)
      return render!(ast, context)
    }
    BlockNode(_, body) => {
     return render_sequence!(body, context)
    }
  }
}

fn render_sequence(exprs: Array[Expr], context: Map[String, Value]) -> String!JinjaError {
  let result = []
  for expr in exprs {
    result.push(render!(expr, context))
  }
  return result.join("")
}

fn value_to_string(v: Value) -> String {
  match v {
    IntValue(n) => return n.to_string()
    BoolValue(b) => return if b { "true" } else { "false" }
    StrValue(s) => return s
    ListValue(arr) => return arr.map(value_to_string).join(", ")
  }
}


fn apply_operator(lhs: String, op: String, rhs: String) -> String!JinjaError {
  match op {
    "+" => return lhs + rhs
    "==" => return if lhs == rhs { "true" } else { "false" }
    _ => raise RenderError("Operator not supported: " + op)
  }
}

fn eval_condition(expr: Expr, context: Map[String, Value]) -> Bool!JinjaError {
  let result = render!(expr, context)
  return result != "" && result != "false"
}

fn eval_list(expr: Expr, context: Map[String, Value]) -> Array[Value]!JinjaError {
  let key = expr_to_key(expr)
  match context.get(key) {
    Some(ListValue(arr)) => return arr
    Some(_) => raise RenderError("Expected list in for loop")
    None => raise RenderError("Variable not found: " + key)
  }
}

fn expr_to_key(expr: Expr) -> String {
  match expr {
    VariableNode(name) => return name
    _ => return ""
  }
}