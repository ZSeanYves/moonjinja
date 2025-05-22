/// --- IF 条件测试 ---
test "if true branch" {
  let tpl = "{% if show %}Hello{% else %}Bye{% endif %}"
  let ctx = ctx_bool("show", true)
  assert_eq!(render_templates(tpl, ctx), "Hello")
  
}

test "if false branch" {
  let tpl = "{% if show %}Hello{% else %}Bye{% endif %}"
  let ctx = ctx_bool("show", false)
  assert_eq(render_templates(tpl, ctx), "Bye")
}

/// --- FOR 循环测试 ---
test "for loop normal list" {
  let tpl = "{% for item in items %}{{ item }},{% endfor %}"
  let ctx = ctx_list_str("items", ["A", "B", "C"])
  assert_eq(render_templates(tpl, ctx), "A,B,C,")
}

test "for loop empty list" {
  let tpl = "{% for item in items %}{{ item }}{% endfor %}"
  let ctx = ctx_list_str("items", [])
  assert_eq(render_templates(tpl, ctx), "")
}

/// --- INCLUDE 测试（使用预定义模板名） ---
test "include static header" {
  let tpl = "START {% include \"header.html\" %} END"
  let ctx = Map::new()
  assert_eq(render_templates(tpl, ctx), "START <header>Header Here</header> END")
}

/// --- EXTENDS / BLOCK 测试 ---
test "extends base with block content" {
  let tpl = "{% extends \"base.html\" %}{% block content %}Main{% endblock %}"
  let ctx = Map::new()
  assert_eq!(render_templates(tpl, ctx), "<body>Main</body>")
}

/// --- SET / WITH 作用域测试 ---
test "set variable and use it" {
  let tpl = "{% set msg = \"Hi\" %}{{ msg }}"
  let ctx = Map::new()
  assert_eq!(render_templates(tpl, ctx), "Hi")
}

test "with block variable overrides" {
  let tpl = "{% with user = \"Alex\" %}Hi {{ user }}{% endwith %}"
  let ctx = Map::new()
  assert_eq!(render_templates(tpl, ctx), "Hi Alex")
}

/// --- FILTERS 测试 ---
test "apply upper and lower filters" {
  let tpl = "{{ name | upper }} {{ name | lower }}"
  let ctx = ctx_str("name", "Hello")
  assert_eq!(render_templates(tpl, ctx), "HELLO hello")
}

test "apply trim filter" {
  let tpl = "{{ name | trim }}"
  let ctx = ctx_str("name", "  Moon  ")
  assert_eq!(render_templates(tpl, ctx), "Moon")
}

/// --- 空白控制 strip 测试 ---
test "whitespace control both sides" {
  let tpl = "A {%- if true -%} B {%- endif -%} C"
  let ctx = Map::new()
  assert_eq!(render_templates(tpl, ctx), "ABC")
}

/// --- 安全模式 HTML 实体测试 ---
test "html escape in safe mode" {
  ignore(set_safe_mode(true))  // 忽略返回值
  let tpl = "User: {{ name }}"
  let ctx = ctx_str("name", "<admin>")
  assert_eq!(render_templates(tpl, ctx), "User: &lt;admin&gt;")
}

/// --- 错误处理测试 ---
test "undefined filter raises error" {
  let tpl = "{{ name | unknown }}"
  let ctx = ctx_str("name", "Alice")
  let result = render_templates(tpl, ctx)
  assert_eq!(result.contains("Unknown filter"), true)
}

test "missing template raises error" {
  let tpl = "{% include \"missing.html\" %}"
  let ctx = Map::new()
  let result = render_templates(tpl, ctx)
  assert_eq!(result.contains("Template not found"), true)
}
