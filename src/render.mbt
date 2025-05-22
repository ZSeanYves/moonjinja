// Value type used in template context
pub enum Value {
  IntValue(Int)                      // Integer value
  BoolValue(Bool)                    // Boolean value
  StrValue(String)                   // String value
  ListValue(Array[Value])           // List of values
}

// Main render function: evaluates an AST expression with a given context
fn render(expr: Expr, context: Map[String, Value]) -> String!JinjaError {
  match expr {
    // Render plain text with optional whitespace trimming
    TextNode(s, strip_left, strip_right) => {
      let mut out = s
      if strip_left {
        out = out.trim_start("").to_string()
      }
      if strip_right {
        out = out.trim_end("").to_string()
      }
      return out
    }

    // Render variable with optional filter (e.g., {{ name | upper }})
    VariableNode(name) => {
      let parts = name.split("|").to_array()
      let var_name = parts[0].trim("").to_string()
      let filter_name = if parts.length() > 1 { parts[1].trim("").to_string() } else { "" }

      match context.get(var_name) {
        Some(v) => {
          let base = value_to_string(v)
          if filter_name == "" {
            if is_safe_mode() {
              return escape_html(base)
            } else {
              return base
            }
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

    // Literal strings or numbers
    LiteralNode(s) => return s

    // Binary expressions like {{ a + b }}
    BinaryOp(lhs, op, rhs) => {
      let left = render!(lhs, context)
      let right = render!(rhs, context)
      return apply_operator!(left, op, right)
    }

    // If conditional
    IfBlock(cond, then_body, else_body) => {
      let cond_val = eval_condition!(cond, context)
      if cond_val {
        return render_sequence!(then_body, context)
      } else {
        return render_sequence!(else_body, context)
      }
    }

    // For loop rendering
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

    // Render a sequence of expressions
    Sequence(exprs) => return render_sequence!(exprs, context)

    // Include another template
    IncludeNode(filename) => {
      let tpl = load_template!(filename)
      let tokens = tokenize!(tpl)
      let ast = parse!(tokens)
      return render!(ast, context)
    }

    // Block rendering (used in inheritance)
    BlockNode(_, body) => {
     return render_sequence!(body, context)
    }

    // Template inheritance rendering
    ExtendsNode(parent, child_blocks) => {
      let parent_src = load_template!(parent)
      let parent_ast = parse!(tokenize!(parent_src))
      let merged = merge_blocks(parent_ast, child_blocks)
      return render!(merged, context)
    }

    // Handle {% set var = value %} (stores value in context)
    SetStmt(name, expr) => {
      let value = eval_value!(expr, context)
      context[name] = value
      return ""  // 'set' produces no output
    }

    // Handle {% with var = value %} ... {% endwith %}
    WithBlock(name, value_expr, body) => {
      let value = eval_value!(value_expr, context)

      // Copy current context into a new map
      let new_ctx = Map::new()
      for k in context.keys() {
        match context.get(k) {
          Some(v) => new_ctx[k] = v
          None => ignore(0)
        }
      }
      new_ctx[name] = value

      return render_sequence!(body, new_ctx)
    }
  }
}

// Render a list of expressions into a single string
fn render_sequence(exprs: Array[Expr], context: Map[String, Value]) -> String!JinjaError {
  let result = []
  for expr in exprs {
    result.push(render!(expr, context))
  }
  return result.join("")
}

// Convert a Value enum to a printable string
fn value_to_string(v: Value) -> String {
  match v {
    IntValue(n) => return n.to_string()
    BoolValue(b) => return if b { "true" } else { "false" }
    StrValue(s) => return s
    ListValue(arr) => return arr.map(value_to_string).join(", ")
  }
}

// Handle binary operators such as + and ==
fn apply_operator(lhs: String, op: String, rhs: String) -> String!JinjaError {
  match op {
    "+" => return lhs + rhs
    "==" => return if lhs == rhs { "true" } else { "false" }
    _ => raise RenderError("Operator not supported: " + op)
  }
}

// Evaluate condition for if statements
fn eval_condition(expr: Expr, context: Map[String, Value]) -> Bool!JinjaError {
  let result = render!(expr, context)
  return result != "" && result != "false"
}

// Evaluate an expression to a list (for for-loops)
fn eval_list(expr: Expr, context: Map[String, Value]) -> Array[Value]!JinjaError {
  let key = expr_to_key(expr)
  match context.get(key) {
    Some(ListValue(arr)) => return arr
    Some(_) => raise RenderError("Expected list in for loop")
    None => raise RenderError("Variable not found: " + key)
  }
}

// Extract string key from a VariableNode expression
fn expr_to_key(expr: Expr) -> String {
  match expr {
    VariableNode(name) => return name
    _ => return ""
  }
}

// Merge child blocks into parent template for inheritance
fn merge_blocks(expr: Expr, overrides: Map[String, Array[Expr]]) -> Expr {
  match expr {
    BlockNode(name, _) => {
      match overrides.get(name) {
        Some(body) => return BlockNode(name, body)
        None => return expr
      }
    }
    Sequence(exprs) => {
      let merged = []
      for e in exprs {
        merged.push(merge_blocks(e, overrides))
      }
      return Sequence(merged)
    }
    _ => return expr
  }
}

// Evaluate an expression into a Value (used in set/with)
fn eval_value(expr: Expr, context: Map[String, Value]) -> Value!JinjaError {
  let rendered = render!(expr, context)
  return StrValue(rendered)  // Currently all set/with use string values
}
