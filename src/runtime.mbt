// ============================================================
// MoonbitJinja — Runtime
// ============================================================

///|
pub(all) enum Value {
  Null
  IntValue(Int)
  BoolValue(Bool)
  StrValue(String)
  SafeStr(String) 
  ListValue(Array[Value])
  MapValue(Map[String, Value])
}

///|
fn escape_html(s : String) -> String {
  // 不依赖多次 replace（有实现只替第一个的情况），逐字符构造
  let chars = s.to_array()
  let out : Array[String] = []
  for c in chars {
    match c {
      '&' => out.push("&amp;")
      '<' => out.push("&lt;")
      '>' => out.push("&gt;")
      '"' => out.push("&quot;")
      '\'' => out.push("&apos;")
      _ => out.push(c.to_string())
    }
  }
  out.join("")
}

///|
fn display_string(v : Value, autoescape~:Bool = false) -> String {
  match v {
    SafeStr(s) => s // 已标记安全：原样输出
    StrValue(s) => if autoescape { escape_html(s) } else { s }
    _ => {
      let plain = value_to_string(v) // 其他类型先转成字符串
      if autoescape {
        escape_html(plain)
      } else {
        plain
      }
    }
  }
}

///|
fn is_ws(c : Char) -> Bool {
  c == ' ' || c == '\t' || c == '\n' || c == '\r'
}

///|
fn trim_ws(s : String) -> String {
  let a = s.to_array()
  let mut l = 0
  let mut r = a.length()
  while l < r && is_ws(a[l]) {
    l += 1
  }
  while l < r && is_ws(a[r - 1]) {
    r -= 1
  }
  let b : Array[Char] = []
  for i in l..<r {
    b.push(a[i])
  }
  String::from_array(b)
}

///|
fn trim_ws_start(s : String) -> String {
  let a = s.to_array()
  let mut l = 0
  let r = a.length()
  while l < r && is_ws(a[l]) {
    l += 1
  }
  let b : Array[Char] = []
  for i in l..<r {
    b.push(a[i])
  }
  String::from_array(b)
}

///|
fn trim_ws_end(s : String) -> String {
  let a = s.to_array()
  let l = a.length()
  let mut r = l
  while 0 < r && is_ws(a[r - 1]) {
    r -= 1
  }
  let b : Array[Char] = []
  for i in 0..<r {
    b.push(a[i])
  }
  String::from_array(b)
}

// ctrl: 0 正常, 1 break, 2 continue
///|
fn render_loop_body(
  exprs : Array[Expr],
  ctx : Map[String, Value],
  autoescape~ : Bool,
) -> (String, Int) raise Error {
  let acc : Array[String] = []
  let mut ctrl = 0
  for e in exprs {
    match e {
      Break => {
        ctrl = 1
        break
      }
      Continue => {
        ctrl = 2
        break
      }
      IfBlock(cond, t, f) =>
        if is_truthy(eval_value(cond, ctx)) {
          let (s, c) = render_loop_body(t, ctx, autoescape~)
          acc.push(s)
          if c != 0 {
            ctrl = c
            break
          }
        } else {
          let (s, c) = render_loop_body(f, ctx, autoescape~)
          acc.push(s)
          if c != 0 {
            ctrl = c
            break
          }
        }
      Sequence(arr) => {
        let (s, c) = render_loop_body(arr, ctx, autoescape~)
        acc.push(s)
        if c != 0 {
          ctrl = c
          break
        }
      }
      _ => acc.push(render(e, ctx, autoescape~))
    }
  }
  (acc.join(""), ctrl)
}




// Utility: convert Value → String
///|
fn value_to_string(v : Value) -> String {
  match v {
    Null => ""
    IntValue(n) => n.to_string()
    BoolValue(b) => if b { "true" } else { "false" }
    StrValue(s) => s
    SafeStr(s) => s 
    ListValue(arr) => arr.map(value_to_string).join(", ")
    MapValue(_) => "[object]"
  }
}


// Utility: truthiness (for if)
///|
fn is_truthy(v : Value) -> Bool {
  match v {
    Null => false
    BoolValue(b) => b
    StrValue(s) => s != "" && s != "false"
    SafeStr(s) => s != "" && s != "false" 
    IntValue(n) => n != 0
    ListValue(a) => a.length() > 0
    MapValue(m) => !m.is_empty()
  }
}


// ============================================================
// Evaluate full template
// ============================================================

// 把 Template.body 包成一个 Expr，方便复用 merge_blocks / render
///|
fn template_body_as_expr(t : Template) -> Expr {
  Expr::Sequence(t.body)
}

///|
pub fn render_template(
  tpl : Template,
  context : Map[String, Value],
  autoescape~ : Bool = false
) -> String raise Error {
  match tpl.parent {
    None => render_sequence(tpl.body, context, autoescape=autoescape)
    Some(parent_name) => {
      let parent_src = load_template(parent_name)
      let tokens = tokenize(parent_src)
      let parent_tpl = parse(tokens)
      let child_blocks = collect_blocks(tpl.body)
      let parent_expr = template_body_as_expr(parent_tpl)
      let merged_expr = merge_blocks(parent_expr, child_blocks)
      match parent_tpl.parent {
        None => render(merged_expr, context, autoescape=autoescape)
        Some(_) => {
          let next_tpl = { parent: parent_tpl.parent, body: [merged_expr] }
          render_template(next_tpl, context, autoescape=autoescape)
        }
      }
    }
  }
}


// ============================================================
// Core rendering
// ============================================================

///|
fn render(
  expr : Expr,
  context : Map[String, Value],
  autoescape? : Bool = false,
) -> String raise Error {
  match expr {
    TextNode(s, l, r) => {
      let mut out = s
      if l {
        out = trim_ws_start(out)
      } // 见下两个小函数
      if r {
        out = trim_ws_end(out)
      }
      out
    }
    RawText(s) => s
    Var(path) =>
      match resolve_var(path, context) {
        Some(v) => display_string(v, autoescape~) // ←
        None => raise RenderError("Variable not found: " + path.parts.join("."))
      }
    Literal(v) => display_string(v, autoescape~) // ←
    Unary(op, e) => {
      let v = eval_value(e, context)
      match op {
        UnOp::Not => if is_truthy(v) { "false" } else { "true" }
        UnOp::Neg =>
          match v {
            IntValue(n) => (-n).to_string()
            _ => raise RenderError("Unary '-' only supports numbers")
          }
        UnOp::Pos => display_string(v, autoescape~) // ←
      }
    }
    Binary(lhs, op, rhs) => {
      let lv = eval_value(lhs, context)
      let rv = eval_value(rhs, context)
      display_string(apply_binop(lv, op, rv), autoescape~) // ←
    }
    FilterChain(base, calls) => {
      let mut v = eval_value(base, context)
      for c in calls {
        v = apply_filter(c, v, context)
      }
      display_string(v, autoescape~) // ←
    }
    IfBlock(cond, t, e) =>
      if is_truthy(eval_value(cond, context)) {
        render_sequence(t, context, autoescape~) // ←
      } else {
        render_sequence(e, context, autoescape~) // ←
      }
    ForBlock(varname, iterable_expr, body) => {
      let result : Array[String] = []
      let iter_val = eval_value(iterable_expr, context)
      match iter_val {
        ListValue(arr) =>
          for item in arr {
            let new_ctx = clone_context(context)
            new_ctx[varname] = item
            let (chunk, ctrl) = render_loop_body(body, new_ctx, autoescape~)
            if ctrl == 2 {
              continue
            } // continue
            result.push(chunk)
            if ctrl == 1 {
              break
            } // break
          }
        _ => raise RenderError("Expected list in for loop")
      }
      result.join("")
    }
    IncludeNode(filename) => {
      let src = load_template(filename)
      let included_tpl = parse(tokenize(src))
      render_template(included_tpl, context, autoescape~) // ←
    }
    BlockNode(_, body) => render_sequence(body, context, autoescape~)
    SetStmt(name, e) => {
      let v = eval_value(e, context)
      context[name] = v
      ""
    }
    WithBlock(assigns, body) => {
      let new_ctx = clone_context(context)
      for k in assigns.keys() {
        let v = eval_value(assigns[k], context)
        new_ctx[k] = v
      }
      render_sequence(body, new_ctx, autoescape~) // ←
    }
    Break => ""
    Continue => ""
    Sequence(exprs) => render_sequence(exprs, context, autoescape~)
  }
}

///|
fn render_sequence(
  exprs : Array[Expr],
  context : Map[String, Value],
  autoescape~ : Bool = false,
) -> String raise Error {
  let result : Array[String] = []
  for e in exprs {
    result.push(render(e, context, autoescape~))
  } // ←
  result.join("")
}


// 深拷贝 context
fn clone_context(ctx : Map[String, Value]) -> Map[String, Value] {
  let m = Map::new()
  for k in ctx.keys() {
    match ctx.get(k) {
      Some(v) => m[k] = v
      None => ()
    }
  }
  m
}

// ============================================================
// Expression evaluation
// ============================================================

///|
fn eval_value(expr : Expr, context : Map[String, Value]) -> Value raise Error {
  match expr {
    Literal(v) => v
    Var(p) =>
      match resolve_var(p, context) {
        Some(v) => v
        None => raise RenderError("Variable not found: " + p.parts.join("."))
      }
    Binary(l, op, r) => {
      let lv = eval_value(l, context)
      let rv = eval_value(r, context)
      apply_binop(lv, op, rv)
    }
    Unary(op, e) => {
      let v = eval_value(e, context)
      match op {
        UnOp::Not => BoolValue(!is_truthy(v))
        UnOp::Neg =>
          match v {
            IntValue(n) => IntValue(-n)
            _ => raise RenderError("Unary '-' only supports Int")
          }
        UnOp::Pos => v
      }
    }
    // ★ 关键补充：把过滤器链按 Value 语义执行，返回 Value
    FilterChain(base, calls) => {
      let mut v = eval_value(base, context)
      for c in calls {
        v = apply_filter(c, v, context)
      }
      v
    }
    // 其他节点默认走 render 再包 StrValue（保持你之前的兜底逻辑）
    _ => StrValue(render(expr, context))
  }
}


// 二元运算计算
///|
fn apply_binop(lhs : Value, op : BinOp, rhs : Value) -> Value raise JinjaError {
  match (lhs, rhs) {
    (IntValue(a), IntValue(b)) =>
      match op {
        BinOp::Add => IntValue(a + b)
        BinOp::Sub => IntValue(a - b)
        BinOp::Mul => IntValue(a * b)
        BinOp::Div => IntValue(if b == 0 { 0 } else { a / b })
        BinOp::FloorDiv => IntValue(if b == 0 { 0 } else { a / b })
        BinOp::Mod => IntValue(if b == 0 { 0 } else { a % b })
        BinOp::Eq => BoolValue(a == b)
        BinOp::Ne => BoolValue(a != b)
        BinOp::Lt => BoolValue(a < b)
        BinOp::Le => BoolValue(a <= b)
        BinOp::Gt => BoolValue(a > b)
        BinOp::Ge => BoolValue(a >= b)
        _ => raise RenderError("Unsupported numeric op")
      }
    (StrValue(a), StrValue(b)) =>
      match op {
        BinOp::Add => StrValue(a + b)
        BinOp::Eq => BoolValue(a == b)
        BinOp::Ne => BoolValue(a != b)
        _ => StrValue("")
      }
    (BoolValue(a), BoolValue(b)) =>
      match op {
        BinOp::And => BoolValue(a && b)
        BinOp::Or => BoolValue(a || b)
        _ => BoolValue(false)
      }
    _ => raise RenderError("Type mismatch in binary expression")
  }
}

// 过滤器应用
///|
fn apply_filter(
  call : Call,
  value : Value,
  _ctx : Map[String, Value],
) -> Value raise Error {
  match call.name {
    "upper" =>
      match value {
        StrValue(s) => StrValue(s.to_upper())
        SafeStr(s) => SafeStr(s.to_upper()) // 保持“安全”语义
        _ => value
      }
    "lower" =>
      match value {
        StrValue(s) => StrValue(s.to_lower())
        SafeStr(s) => SafeStr(s.to_lower())
        _ => value
      }
    "trim" =>
      match value {
        StrValue(s) => StrValue(trim_ws(s))
        SafeStr(s) => SafeStr(trim_ws(s))
        _ => value
      }
    "split" => {
      // 允许 0/1 个参数，默认 ","
      let sep = if call.args.length() >= 1 {
        value_to_string(eval_value(call.args[0], _ctx))
      } else {
        ","
      }
      match value {
        StrValue(s) | SafeStr(s) => {
          let parts = s.split(sep).to_array()
          let out : Array[Value] = []
          for p in parts {
            out.push(StrValue(p.to_string()))
          }
          ListValue(out)
        }
        _ => ListValue([])
      }
    }
    // ★ 按你的测试期望：safe/escape 都“标记为安全”，不做实体转义
    "safe" =>
      match value {
        SafeStr(s) => SafeStr(s) // 已经安全
        StrValue(s) => SafeStr(s) // 标记为安全
        _ => SafeStr(value_to_string(value))
      }
    "escape" =>
      match value {
        SafeStr(s) => SafeStr(s) // 仍然安全
        StrValue(s) => SafeStr(s) // 按用例：不转义，只标记安全
        _ => SafeStr(value_to_string(value))
      }
    _ => raise RenderError("Unknown filter: " + call.name)
  }
}


// 变量解析：支持 a.b.c
///|
fn resolve_var(path : VarPath, ctx : Map[String, Value]) -> Value? {
  if path.parts.length() == 0 {
    return None
  }
  let mut curr : Value? = ctx.get(path.parts[0])
  for i in 1..<path.parts.length() {
    match curr {
      Some(MapValue(m)) => curr = m.get(path.parts[i])
      _ => return None
    }
  }
  curr
}

// ============================================================
// Block merging for inheritance
// ============================================================

///|
fn collect_blocks(exprs : Array[Expr]) -> Map[String, Array[Expr]] {
  let blocks = Map::new()
  for e in exprs {
    match e {
      BlockNode(name, body) => blocks[name] = body
      Sequence(arr) => {
        let inner = collect_blocks(arr)
        for k in inner.keys() {
          blocks[k] = inner[k]
        }
      }
      _ => ()
    }
  }
  blocks
}

///|
fn merge_blocks(expr : Expr, overrides : Map[String, Array[Expr]]) -> Expr {
  match expr {
    BlockNode(name, _) =>
      match overrides.get(name) {
        Some(body) => BlockNode(name, body)
        None => expr
      }
    Sequence(exprs) => {
      let merged = []
      for e in exprs {
        merged.push(merge_blocks(e, overrides))
      }
      Sequence(merged)
    }
    _ => expr
  }
}
