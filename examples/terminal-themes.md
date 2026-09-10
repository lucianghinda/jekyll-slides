---
layout: presentation
title: Terminal themes
theme: catppuccin-mocha
permalink: /terminal-themes/
---

<!--
layout: title
background: gradient
-->
# Catppuccin on your slides

## Four flavors, and a macOS window around the code

---

<!--
layout: code
-->
# One theme for the whole deck

```ruby
class Invoice
  TAX = 0.19

  def total
    subtotal * (1 + TAX)
  end
end
```
{: .editor title="app/models/invoice.rb" highlight="5"}

---

<!--
layout: code
-->
# Terminals get the same window

```console
$ bundle exec rspec
Invoice
  applies tax

3 examples, 0 failures
```
{: .terminal title="zsh — rspec"}

---

<!--
layout: split-code
-->
```ruby
def total
  subtotal * 1.19
end
```
{: .editor title="mocha, from the deck" size="sm"}

```console
$ ghostty --version
ghostty 1.0.1
```
{: .terminal title="latte, on this window only" theme="catppuccin-latte" size="sm"}

---

<!--
layout: split-code
-->
```ruby
def total
  subtotal * 1.19
end
```
{: .editor title="frappé" theme="catppuccin-frappe" size="sm"}

```ruby
def total
  subtotal * 1.19
end
```
{: .editor title="macchiato" theme="catppuccin-macchiato" size="sm"}
