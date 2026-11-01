# Design reference

The screens of the Wake Up Human prototype, extracted from its HTML export (`App de alarmas
macOS.html`, 2026-11-01). Embedded fonts and the export's runtime were removed. Each file keeps
the markup, the inline styles (colours, sizes, spacing) and the `text/x-dc` script that drives
its states.

They are a reference, not code to port. Where
`.agents/specs/2026-11-01-macos-typing-alarm.md` is silent on layout, copy or colour, these
screens govern; where the two disagree, the spec governs. The user-facing strings are Spanish
product content (ADR-0024).

| File | Component | Boards in the prototype (state prop) |
|------|-----------|--------------------------------------|
| `panel.html` | Menu-bar panel | Normal, With notices, Inline editing, Bedtime on battery (`escenario`: `normal`, `avisos`, `edicion`, `bateria`) |
| `status-icon.html` | Status-bar icon | Static sheet of the six icon states |
| `ring-window.html` | Ring window | Just started, With a joined Alarm, Dismissed (`momento`: `inicio`, `sumada`, `apagada`) |

Reading the markup:

- `{{name}}` is a value computed by `renderVals()` in the file's script.
- `<sc-if value=…>` shows its content only when the value is true.
- `<sc-for list=… as=…>` repeats its content for each item.
- `sc-camel-on-*` attributes are event handlers.
