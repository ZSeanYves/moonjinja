pub fn load_template(name: String) -> String!JinjaError {
  match name {
    "example.html" => return "<!-- 注意，此为最基础模板，如需更新添加内容自己导入新的 -->\n{% set title = \"MoonBit\" %}\n{% set items = \"apple,banana,cherry\" %}\n\n<h1>{{ title | upper }}</h1>\n\n<ul>\n{% for item in items.split(\",\") -%}\n  <li>{{- item | trim -}}</li>\n{%- endfor %}\n</ul>\n\n{% with msg = \"welcome\" %}\n<p>Hello, {{ msg }}!</p>\n{% endwith %}\n\n{% if title == \"MoonBit\" %}\n<p>This is rendered because the condition is true.</p>\n{% endif %}\n"
    _ => raise RenderError("Template not found: " + name)
  }
}
