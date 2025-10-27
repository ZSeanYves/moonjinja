// 快捷：空上下文
fn empty_ctx() -> Map[String, Value] {
  Map::new()
}


///| --- tokenize/parse/smoke 渲染 ---
test "render: simple filters & for/break" {
  // 模板：split + trim + upper，并在 stop 处 break
  let tpl =
    "{% set items = \"alpha, beta, stop, gamma\" %}\n" +
    "<ul>\n" +
    "{% for it in items | split(\",\") -%}\n" +
    "  {% if it | trim == \"stop\" %}{% break %}{% endif %}\n" +
    "  <li>{{ it | trim | upper }}</li>\n" +
    "{%- endfor %}\n" +
    "</ul>\n"

  write_tpl("simple.html", tpl)

  let t = parse(tokenize(load_template(name ="simple.html")))
  let out = render_template(t, empty_ctx(), autoescape=false)
  //println("output:"+out)

  // 只应包含 ALPHA/BETA，不应包含 STOP/GAMMA
  assert_eq(out.contains("<li>ALPHA</li>"), true)
  assert_eq(out.contains("<li>BETA</li>"), true)
  assert_eq(out.contains("STOP"), false)
  assert_eq(out.contains("GAMMA"), false)
}


///| --- include / extends 组合 ---
test "render: include + extends merge blocks" {
  write_tpl("partials/header.html",
    "<h1>{{ \"MoonBitJinja\" | upper }}</h1>\n"
  )

  write_tpl("base.html",
    "<!DOCTYPE html>\n" +
    "<html>\n" +
    "<head><title>{% block title %}Base Title{% endblock %}</title></head>\n" +
    "<body>\n" +
    "<header>{% include \"partials/header.html\" %}</header>\n" +
    "<main>{% block content %}Base content{% endblock %}</main>\n" +
    "</body>\n" +
    "</html>\n"
  )

  write_tpl("child.html",
    "{% extends \"base.html\" %}\n" +
    "{% block title %}Child Title{% endblock %}\n" +
    "{% block content %}\n" +
    "  {% set items = \"a, b, c\" %}\n" +
    "  <ul>\n" +
    "  {% for x in items | split(\",\") -%}\n" +
    "    <li>{{ x | trim | upper }}</li>\n" +
    "  {%- endfor %}\n" +
    "  </ul>\n" +
    "{% endblock %}\n"
  )

  let t = parse(tokenize(load_template(name = "child.html")))
  let out = render_template(t, empty_ctx(), autoescape=false)

  //println("output:"+out)

  assert_eq(out.contains("<title>Child Title</title>"), true)  // 子模板覆盖
  assert_eq(out.contains("<h1>MOONBITJINJA</h1>"), true)       // include 生效
  assert_eq(out.contains("<li>A</li>"), true)
  assert_eq(out.contains("<li>B</li>"), true)
  assert_eq(out.contains("<li>C</li>"), true)
  assert_eq(out.contains("Base content"), false)               // 父内容被覆盖
}


///| --- autoescape 显式参数 + safe/escape 过滤器 ---
test "render: autoescape & safe/escape filters" {
  write_tpl("esc.html",
    "{% with msg = \"<b>hi & bye</b>\" %}\n" +
    "<p>raw: {{ msg }}</p>\n" +
    "<p>safe: {{ msg | safe }}</p>\n" +
    "<p>esc: {{ msg | escape }}</p>\n" +
    "{% endwith %}\n"
  )

  let t = parse(tokenize(load_template(name ="esc.html")))

  // autoescape=false：全部原样
  let out0 = render_template(t, empty_ctx(), autoescape=false)
  //println("output0"+out0)
  assert_eq(out0.contains("<p>raw: <b>hi & bye</b></p>"), true)
  assert_eq(out0.contains("<p>safe: <b>hi & bye</b></p>"), true)
  assert_eq(out0.contains("<p>esc: <b>hi & bye</b></p>"), true)

  // autoescape=true：raw 被转义；safe/esc 原样可见 <> &
  let out1 = render_template(t, empty_ctx(), autoescape=true)
  //println("output1"+out1)
  assert_eq(out1.contains("<p>raw: &lt;b&gt;hi &amp; bye&lt;/b&gt;</p>"), true)
  assert_eq(out1.contains("<p>safe: <b>hi & bye</b></p>"), true)
  assert_eq(out1.contains("<p>esc: <b>hi & bye</b></p>"), true)
}

///|
test "render: built-in example template" {
  // 默认模板 = example.html
  let t = parse(tokenize(load_template()))
  let out = render_template(t, empty_ctx(), autoescape=true)

  // 检查继承与 include 是否生效
  assert_eq(out.contains("<h1>MOONBITJINJA</h1>"), true)
  assert_eq(out.contains("<title>MoonBitJinja Example</title>"), true)

  // 检查 for + break 正常（stop 后终止）
  assert_eq(out.contains("<li>ALPHA</li>"), true)
  assert_eq(out.contains("<li>BETA</li>"), true)
  assert_eq(out.contains("STOP"), false)
  assert_eq(out.contains("GAMMA"), false)

  // 检查 autoescape / safe / escape
  assert_eq(out.contains("&lt;b&gt;hi &amp; bye&lt;/b&gt;"), true)
  assert_eq(out.contains("<p>safe: <b>hi & bye</b></p>"), true)
  assert_eq(out.contains("<p>esc: <b>hi & bye</b></p>"), true)
}