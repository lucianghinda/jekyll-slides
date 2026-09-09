# Releasing Jekyll Slides

The first release is `0.1.0`. The version lives in `lib/jekyll/slides/version.rb`.
For later releases, update that constant and move the relevant changelog entries
into a dated version section before building.

## Verify and build

From the repository root:

```sh
bundle install
npm ci
bin/prepare_release
git diff --check
```

`bin/prepare_release` runs the complete Rake verification, replaces the generated
Markdown API docs using YARD, updates their index and `llms.txt`, then performs a
strict gem build. It writes `pkg/jekyll-slides-VERSION.gem` and a matching
`.gem.sha256` file using the version from the gemspec. It works from any current
directory and stops at the first failure. It never commits, tags, pushes, or
publishes.

To regenerate only documentation, run `bundle exec rake docs`. Review and commit
the generated `doc/` and `llms.txt` files with their source changes. `doc/` is
generated output; put authored guides in `docs/` instead. The complete Rake
check includes lint, Ruby and browser-runtime tests, CSS reproducibility, strict
gem validation, archive inspection, and a fresh-process Jekyll build using the
installed gem. CI tests Ruby 3.1 against Jekyll 4.3 and the latest allowed
Jekyll version, plus Ruby 3.4 and 4.0 against Jekyll 4.4 or newer. Jekyll 4.3
relies on standard-library gems removed from Ruby 3.4 and is not a supported
combination with Ruby 3.4 or newer.

The archive should contain Ruby code, layouts, includes, compiled assets, bundled
fonts and their OFL notices, generated Markdown API docs, `llms.txt`, the Apache
license, README, and changelog. Development scripts and example decks stay in
the source repository. Consumers do not need Node, YARD, or a CSS build step.

Review the dark and light example decks, code focus/scrolling, overview, and PDF
output when presentation assets change. Dense examples need splitting for print.

## Publish

Before publishing, make the intended repository at
`https://github.com/lucianghinda/jekyll-slides` publicly available, or update the
gemspec and documentation links to the actual release repository. Configure its
Git remote and check the compatibility CI results. The local preparation does
not create a remote repository or publish the package.

Commit the verified tree, then create an annotated tag for that exact version:

```sh
git tag -a v0.1.0 -m "Release jekyll-slides 0.1.0"
git push origin main
git push origin v0.1.0
gem push pkg/jekyll-slides-0.1.0.gem
```

Use a RubyGems account authorized to publish the gem, with MFA enabled. See the
[RubyGems publishing guide](https://guides.rubygems.org/publishing/) for account
and push details. Confirm the published version and install it in a clean site.
Do not overwrite or reuse a version that has already been published.
