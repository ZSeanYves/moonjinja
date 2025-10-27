# 🧩 MoonbitJinja: A Tiny Jinja‑like Template Engine for MoonBit

[English](#) | [简体中文](#)

**MoonbitJinja** is a lightweight, dependency‑free template engine for **MoonBit**, inspired by Jinja.  
It parses a small but expressive template syntax (blocks, variables, filters, and inheritance) and renders HTML/text safely with optional auto‑escaping.

---

## ✨ Features

- Familiar Jinja‑style tags: `{{ ... }}` (variables) and `{% ... %}` (statements)
- Block statements: **if**, **for**, **with**, **block / endblock**, **include**, **set**, **break**, **continue**
- Template inheritance: **extends**, with block overriding & content merging
- Filters & pipes: `split(",")`, `trim`, `upper`, `safe`, `escape` (chainable like `x | trim | upper`)
- Optional **autoescape** with HTML escaping that you can turn on/off per render
- Whitespace control with strip markers: `-{% ... %}` or `{%- ... %}`, `-}}` and `{{-`
- Safe template loading with path normalization and root boundary checks
- Clear error types: **ParseError** and **RenderError**
- Comes with example templates and tests

---

## 📦 Installation

```bash
moon add ZSeanYves/moonjinja
```

Or edit your `moon.mod.json`:

```json
"import": ["ZSeanYves/moonjinja"]
```

> The module path above assumes your repository is named `moonjinja`. Adjust if needed.

---

## 🚀 Quick Start

### 1) Put your templates under `templates/`

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

**`templates/example.html`** (default demo)

```jinja2
{% extends "base.html" %}

{% block title %}MoonBitJinja Example{% endblock %}

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

### 2) Render it in MoonBit

```moonbit
use ZSeanYves/moonjinja

// 读取模板文本（默认 "example.html"）并渲染
let text = load_template()  // same as load_template("example.html")
let tpl  = parse(tokenize(text))

// 可选择 autoescape=true 进行 HTML 转义
let html = render_template(tpl, empty_ctx(), autoescape=true)
println(html)
```

**Sample output (with `autoescape=true`):**

```html
<!DOCTYPE html>
<html>
<head><title>MoonBitJinja Example</title></head>
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

> Notice how `raw` is escaped under `autoescape=true`, while `safe`/`escape` leave raw HTML intact for demonstration.

---

## 🧭 Public API (User‑Facing)

> Below are the functions you typically use when embedding MoonbitJinja in your program.

### Loading

| Function | Signature | Notes |
| --- | --- | --- |
| `load_template` | `load_template(name~ : String = "example.html") -> String raise Error` | Reads a file under `TEMPLATE_ROOT` (defaults to `templates/`). It normalizes the path and ensures the final path stays within root to prevent path traversal. |

### Tokenize → Parse → Render

| Function | Signature | Notes |
| --- | --- | --- |
| `tokenize` | `tokenize(String) -> Array[Token]` | Jinja‑style lexer. Supports strip markers for whitespace control. |
| `parse` | `parse(Array[Token]) -> Template raise JinjaError` | Builds an AST (with inheritance info) from tokens. |
| `render_template` | `render_template(Template, Map[String,Value], autoescape: Bool) -> String raise JinjaError` | Renders the template with a simple value model and filters. |

### Values & Filters

- `Value`: supports `StrValue`, `IntValue`, `BoolValue`, `Null`, as well as arrays/maps where used.
- Built‑in filters:
  - `upper` — convert to uppercase
  - `trim` — remove surrounding whitespace
  - `split(delim : String)` — split string into array
  - `safe` — mark string as safe (skip escaping even when `autoescape=true`)
  - `escape` — mark string to be escaped under `autoescape=true`

> Filters can be chained: `{{ x | trim | upper }}`.  
> `safe`/`escape` interact with the renderer’s `autoescape` flag as expected.

### Statements (Blocks)

- `{% if cond %}…{% else %}…{% endif %}`
- `{% for x in xs %}…{% endfor %}` (supports `{% break %}`, `{% continue %}`)
- `{% set name = expr %}`
- `{% with a = 1, b = 2 %}…{% endwith %}`
- `{% include "path/to/file.html" %}`
- `{% block name %}…{% endblock %}` + `{% extends "base.html" %}`

### Whitespace Control

Use dashes to trim surrounding text nodes:

- Left trim: `{%- ... %}` or `{{- ... }}`
- Right trim: `{% ... -%}` or `{{ ... -}}`

The parser records strip flags next to `Text` so the renderer can remove adjoining whitespace.

---

## 🧪 Tests

This repository includes tests that cover the lexer, parser, and renderer (filters, control flow, `include`, `extends`, and auto‑escape behavior).

```bash
moon test
```

Typical assertions include:

- Breaks the loop when encountering `"stop"`
- Child overrides parent blocks via `extends`
- `autoescape=true` escapes by default; `safe/escape` filters show the raw HTML

---

## ⚠️ Errors

`JinjaError` is raised for template problems and has at least two variants:

- `ParseError(String)` — illegal tokens, mismatched tags, incomplete blocks, etc.
- `RenderError(String)` — runtime issues such as unknown filter/variable, or invalid value operations

---

## 🧱 Project Structure (Suggested)

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

Set `TEMPLATE_ROOT` to `templates/` (or any folder you prefer) in your code/config.

---

## 📜 License

Licensed under **Apache‑2.0**. See `LICENSE` for details.
