pub enum Value {
  IntValue(Int)
  BoolValue(Bool)
  StrValue(String)
  ListValue(Array[Value])
}

fn render(expr: Expr, context: Map[String, Value]) -> String!RenderError {
  match expr {
    TextNode(s) => return s
    VariableNode(name) => {
      match context.get(name) {
        Some(v) => return value_to_string(v)
        None => raise RenderError::MissingVariable("Variable not found: " + name)
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
  }
}

fn render_sequence(exprs: Array[Expr], context: Map[String, Value]) -> String!RenderError {
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


fn apply_operator(lhs: String, op: String, rhs: String) -> String!RenderError {
  match op {
    "+" => return lhs + rhs
    "==" => return if lhs == rhs { "true" } else { "false" }
    _ => raise RenderError::UnsupportedOperator("Operator not supported: " + op)
  }
}

fn eval_condition(expr: Expr, context: Map[String, Value]) -> Bool!RenderError {
  let result = render!(expr, context)
  return result != "" && result != "false"
}

fn eval_list(expr: Expr, context: Map[String, Value]) -> Array[Value]!RenderError {
  let key = expr_to_key(expr)
  match context.get(key) {
    Some(ListValue(arr)) => return arr
    Some(_) => raise RenderError::InvalidIteration("Expected list in for loop")
    None => raise RenderError::MissingVariable("Variable not found: " + key)
  }
}

fn expr_to_key(expr: Expr) -> String {
  match expr {
    VariableNode(name) => return name
    _ => return ""
  }
}