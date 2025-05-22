import os

TEMPLATE_DIR = "src/templates"
OUTPUT_FILE = "src/template.mbt"

def escape_content(content):
    return (
        content.replace("\\", "\\\\")
               .replace("\"", "\\\"")
               .replace("\n", "\\n")
    )

def main():
    if not os.path.exists(TEMPLATE_DIR):
        print(f" Folder '{TEMPLATE_DIR}' not found.")
        return

    entries = []
    for fname in os.listdir(TEMPLATE_DIR):
        if fname.endswith(".html"):
            path = os.path.join(TEMPLATE_DIR, fname)
            with open(path, "r", encoding="utf-8") as f:
                raw = f.read()
                content = escape_content(raw)
                entries.append(f'    "{fname}" => return "{content}"')

    with open(OUTPUT_FILE, "w", encoding="utf-8") as out:
        out.write("pub fn load_template(name: String) -> String!JinjaError {\n")
        out.write("  match name {\n")
        for line in entries:
            out.write(line + "\n")
        out.write('    _ => raise RenderError("Template not found: " + name)\n')
        out.write("  }\n")
        out.write("}\n")

    print(f" Generated {OUTPUT_FILE} with {len(entries)} templates.")

if __name__ == "__main__":
    main()
