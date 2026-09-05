---
layout: presentation
title: Readable technical slides
theme: minimal-light
permalink: /readability/
---

<!--
layout: title
background: plain
-->
# Read every detail

## A light theme for technical talks

Atkinson Hyperlegible Next for text. Atkinson Hyperlegible Mono for code.

---

<!--
layout: code
-->
# Keep the context visible

```ruby
# Comments belong to the explanation.
invoice_id = "INV-001"
characters = "O0 I1 lL"

def subtotal(price, quantity)
  price * quantity
end
```
{: .editor title="app/models/invoice.rb" size="md" focus="5-7" line_numbers="true"}

---

<!--
layout: code-result
-->
# Show the result

The window, syntax colors, and terminal prompts remain part of the presentation.

```ruby
puts subtotal(21, 2)
```
{: .editor title="invoice.rb" size="md"}

```text
$ ruby invoice.rb
42
```
{: .terminal title="Terminal" size="sm"}

---

# Make the evidence readable

| Check | Result |
|-------|--------|
| Text and code | Atkinson fonts |
| Theme | Minimal light |
| Font loading | Works offline |

Keep tables short enough to discuss one row at a time.

---

# Words matter too

Use **emphasis**, *real italics*, and readable `inline_code`.

> Keep the explanation as clear as the implementation.

Diacritics: Știință, înțelegere, café, naïve.[^fonts]

[^fonts]: The bundled fonts include Latin and extended Latin characters.
