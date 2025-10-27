# 🧩 MoonbitJinja：MoonBit 的轻量级模板引擎

[English](#) | [简体中文](#)

**MoonbitJinja** 是一个基于 **MoonBit** 的轻量级模板引擎，灵感来自 Jinja。  
它实现了模板继承、变量插值、过滤器、控制结构与 HTML 安全渲染，适合教学与工程使用。

---

## ✨ 功能特性

- Jinja 风格语法：`{{ ... }}`（变量）与 `{% ... %}`（语句）
- 支持语句：**if**、**for**、**with**、**block / endblock**、**include**、**set**、**break**、**continue**
- 模板继承：`extends` 支持父模板块覆盖与内容合并
- 管道与过滤器：支持 `split(",")`、`trim`、`upper`、`safe`、`escape` 等链式过滤器
- 自动转义：可选 HTML Autoescape 模式，防止 XSS
- 空白控制：支持 `{%- ... %}`、`{{- ... }}` 等 strip 标记
- 安全加载机制：路径归一化、根目录限制与安全检查
- 明确的错误类型：`ParseError` 与 `RenderError`
- 自带示例模板与单元测试

---

## 📦 安装

```bash
moon add ZSeanYves/moonjinja
```

或手动编辑 `moon.mod.json`：

```json
"import": ["ZSeanYves/moonjinja"]
```

> 上述路径假设仓库名为 `moonjinja`，如有不同请自行修改。

---

## 🚀 快速开始

### 1）准备模板目录 `templates/`

**`templates/base.html`**

```html
<!DOCTYPE html>
<html>
<head><title>{% block title %}Base Title{% endblock %}</title></head>
<body>
<header>{% include "partials/header.html" %}</header>
<main>{% block content %}Base content{% endblock %}</main>
</body>
</html>
```

**`templates/partials/header.html`**

```html
<h1>{{ "MoonBitJinja" | upper }}</h1>
```

**`templates/example.html`**（默认演示模板）

```jinja2
{% extends "base.html" %}

{% block title %}MoonBitJinja 示例{% endblock %}

{% block content %}
  {% set items = "alpha, beta, stop, gamma" %}
  <ul>
  {% for it in items | split(",") %}
    {% if it | trim == "stop" %}
      {% break %}
    {% endif %}
    <li>{{ it | trim | upper }}</li>
  {% endfor %}
  </ul>

  {% with msg = "<b>hi & bye</b>" %}
  <p>raw: {{ msg }}</p>
  <p>safe: {{ msg | safe }}</p>
  <p>esc: {{ msg | escape }}</p>
  {% endwith %}
{% endblock %}
```

### 2）在 MoonBit 中渲染

```moonbit
use ZSeanYves/moonjinja

// 默认加载 "example.html" 模板
let text = load_template()
let tpl  = parse(tokenize(text))

// 可启用 HTML 自动转义
let html = render_template(tpl, empty_ctx(), autoescape=true)
println(html)
```

**输出示例（autoescape=true 时）：**

```html
<!DOCTYPE html>
<html>
<head><title>MoonBitJinja 示例</title></head>
<body>
<header><h1>MOONBITJINJA</h1>
</header>
<main>
  <ul>
    <li>ALPHA</li>
    <li>BETA</li>
  </ul>
  <p>raw: &lt;b&gt;hi &amp; bye&lt;/b&gt;</p>
  <p>safe: <b>hi & bye</b></p>
  <p>esc: <b>hi & bye</b></p>
</main>
</body>
</html>
```

> 可见 `autoescape=true` 时，`raw` 被转义，而 `safe` 与 `escape` 输出原始 HTML。

---

## 🧭 对外接口

### 加载模板

| 函数 | 签名 | 说明 |
| --- | --- | --- |
| `load_template` | `load_template(name~ : String = "example.html") -> String raise Error` | 从模板根目录读取文件，默认加载 `example.html`，包含路径安全检查。 |

### 词法解析 → 语法解析 → 渲染

| 函数 | 签名 | 说明 |
| --- | --- | --- |
| `tokenize` | `tokenize(String) -> Array[Token]` | 模板词法分析器，支持空白 strip 标记。 |
| `parse` | `parse(Array[Token]) -> Template raise JinjaError` | 将 token 序列转换为语法树（AST）。 |
| `render_template` | `render_template(Template, Map[String,Value], autoescape: Bool) -> String raise JinjaError` | 根据上下文变量与过滤器渲染输出字符串。 |

### 内置过滤器

- `upper`：转大写  
- `trim`：去除前后空白  
- `split(delim)`：按分隔符拆分字符串  
- `safe`：标记字符串为安全（不转义）  
- `escape`：强制转义 HTML

> 可链式使用：`{{ x | trim | upper }}`  
> 与 `autoescape` 选项协同工作。

### 控制语句

- `{% if cond %}...{% else %}...{% endif %}`
- `{% for x in xs %}...{% endfor %}`（支持 `{% break %}`、`{% continue %}`）
- `{% set name = expr %}`
- `{% with a = 1, b = 2 %}...{% endwith %}`
- `{% include "path/file.html" %}`
- `{% block name %}...{% endblock %}` + `{% extends "base.html" %}`

### 空白控制

- 左侧去空：`{%- ... %}` 或 `{{- ... }}`  
- 右侧去空：`{% ... -%}` 或 `{{ ... -}}`

渲染器根据 strip 标志自动调整文本块空白。

---

## 🧪 测试

内置单元测试覆盖以下场景：

- 词法分析与 strip 控制  
- 块结构与循环嵌套  
- 模板继承与 include  
- 过滤器与 autoescape 行为  

```bash
moon test
```

---

## ⚠️ 错误类型

`JinjaError` 包含以下两类：

- `ParseError`：语法错误（如标签不匹配、意外 EOF 等）  
- `RenderError`：运行期错误（变量未定义、过滤器不存在等）

---

## 📁 推荐项目结构

```
templates/
  base.html
  example.html
  partials/
    header.html

src/
  lexer.mbt
  parser.mbt
  render.mbt
  moonjinja_test.mbt
```

设置 `TEMPLATE_ROOT = "templates/"` 或在配置中自定义路径。

---

## 📜 许可证

基于 **Apache-2.0** 协议开源。详见 `LICENSE` 文件。
