// template.mbt — safe FileSystem loader for MoonbitJinja

const TEMPLATE_ROOT : String = "src/templates"

// 入口：按名称加载模板内容
pub fn load_template(name~ : String= "example.html") -> String raise Error {
  let norm = normalize_name(name)                 // 1) 规范化
  ensure_safe_name(norm)                                  // 2) 基础安全检查
  let full = join_path(TEMPLATE_ROOT, norm)       // 3) 拼绝对路径
  ensure_within_root(TEMPLATE_ROOT, full)                 // 4) 根目录越界检查
  read_text_file(full)                                    // 5) 读文件
}


// 统一分隔符、去前导'/'、消解 '.' 与 '..'
///|
fn normalize_name(name : String) -> String raise Error {
  // 统一分隔符：把 '\' 换成 '/'
  let s1 = name.replace(old="\\", new="/")

  // 去掉前导 '/'
  let s2 =
    if s1.has_prefix("/") {
      s1[1:s1.length()].to_string()
    } else {
      s1
    }

  // 拆分路径并规整 '.' / '..'
  let parts = s2.split("/").to_array() 
  let stack : Array[String] = [] 
  for p in parts {
    let seg = p.to_string() 
    if seg == "" || seg == "." {
      continue
    }
    if seg == ".." {
      if stack.length() > 0 {
        let _ = stack.pop()
        // 丢弃返回值即可
      }
      // 其余越界情况交给 ensure_safe_name 再检查
    } else {
      stack.push(seg)
    }
  }
  stack.join("/")
}


// 拒绝绝对路径/盘符/残留 '..'
///|
fn ensure_safe_name(norm : String) -> Unit raise JinjaError {
  if norm == "" {
    raise RenderError("Empty template name")
  }
  if norm.contains("..") {
    raise RenderError("Path traversal is not allowed")
  }
  if norm.has_prefix("/") {
    raise RenderError("Absolute paths are not allowed")
  }
  // Windows 盘符：C: 或 d:
  if norm.length() >= 2 &&
    (
      ('A'.to_int() <= norm[0] && norm[0] <= 'Z'.to_int()) ||
      ('a'.to_int() <= norm[0] && norm[0] <= 'z'.to_int())
    ) &&
    norm[1] == ':' {
    raise RenderError("Drive-letter paths are not allowed")
  }
}

// 拼接 root 和相对名（避免重复/缺失分隔符）
///|
fn join_path(root : String, rel : String) -> String raise Error {
  // 去掉 root 末尾的 '/'（如果有）
  let r = if root.has_suffix("/") {
    root[0:root.length() - 1].to_string()
  } else {
    root
  }

  // 去掉 rel 开头的 '/'（如果有）
  let a = if rel.has_suffix("/") {
    rel[1:rel.length()].to_string()
  } else {
    rel
  }
  r + "/" + a
}


// 简易越界检查（结合 normalize 已足够）
///|
fn ensure_within_root(root : String, full : String) -> Unit raise JinjaError {
  let r = if root.has_suffix("/") { root } else { root + "/" }
  if not(full.has_prefix(r)) {
    raise RenderError("Resolved path escapes template root")
  }
}

// 读取 UTF-8 文本文件，IOError → RenderError
///|
fn read_text_file(path : String) -> String raise Error {
  // 检查路径是否存在
  if not(@fs.path_exists(path)) {
    raise RenderError("Template not found: " + path)
  }
  if @fs.is_dir(path) {
    raise RenderError("Template path is a directory: " + path)
  }

  // 读取并捕获 IOError
  @fs.read_file_to_string(path, encoding="utf8")
}

// 简易工具：确保目录存在
pub fn ensure_dir(path : String) -> Unit raise @fs.IOError {
  if !@fs.path_exists(path) {
    @fs.create_dir(path)
  }
}

// 简易工具：写模板到 src/templates/...
pub fn write_tpl(name : String, content : String) -> Unit raise @fs.IOError {
  let root = "src/templates"
  ensure_dir(root)
  let parts = name.split("/").to_array()
  let mut acc = root
  // 逐级创建子目录
  if parts.length() > 1 {
    for i in 0..<(parts.length() - 1) {
      acc = acc + "/" + parts[i].to_string()
      ensure_dir(acc)
    }
  }
  let full = root + "/" + name
  @fs.write_string_to_file(full, content, encoding="utf8")
}