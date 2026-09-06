---
layout: code-result
background: grid
---
# A refactor should earn trust

The test still tells the same story, while the production code now has a name for the rule.

```ruby
expect(invoice.total).to eq(42)
```
{: .editor #spec title="spec/models/invoice_spec.rb" size="md" line_numbers="true"}

```text
$ bundle exec rspec spec/models/invoice_spec.rb
.

Finished in 0.08 seconds
1 example, 0 failures
```
{: .terminal #passing-test title="test run" size="sm"}
