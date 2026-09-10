---
layout: presentation
title: Presentation polish
theme: minimal-light
permalink: /presentation-polish/
---

<!--
layout: title
background: plain
-->
# Room to think

## A flat light deck, wider margins of attention, and one idea at a time

---

<!--
layout: content
background: plain
-->
# Draw the path first

```text
browser  ──▶  router  ──▶  controller  ──▶  view
```

The router picks the controller. The controller prepares one object. The view
reads that object and nothing else.

---

<!--
layout: content
background: plain
-->
# Every block keeps its distance

```ruby
Rails.application.routes.draw { resources :invoices }
```

Highlighted code is followed by prose.

| Block          | Followed by |
|----------------|-------------|
| Plain fence    | Paragraph   |
| Rouge output   | Paragraph   |

A table is followed by prose.

> A quote is followed by prose.

Nothing collides, and nothing floats.

---

<!--
layout: content
background: plain
-->
# One idea at a time

Start with the claim everyone already accepts.

Then add the part that costs something.
{: .fragment}

Then the part that changes what you do tomorrow.
{: .fragment}

---

<!--
layout: code
background: plain
-->
# The window is flat now

```ruby
class Invoice
  def total = items.sum(&:price)
end
```
{: .editor title="app/models/invoice.rb" theme="macos-light" line_numbers="true"}

---

<!--
layout: statement
background: plain
-->
# Give the content the room

Padding is a decision about attention.
