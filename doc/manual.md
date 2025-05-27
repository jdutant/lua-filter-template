---
title: Sample Lua filter documentation
author: Jane E. Doe
---

Introduction
------------------------------------------------------------------

Pandoc / Quarto filter that turns a document's title into a simple
greetings message. 

View the filter in original GitHub repo.

Installation
------------------------------------------------------------------

### Pandoc

Downlad `greetings.lua` from the Releases pages. Pass it to Pandoc
using the `-L` (or `--lua-filter`) option:

    pandoc -L path/to/imagify.lua ...

You do not need other files. You may save the filer in Pandoc's
user data directory to make the filter accessible anywhere. See
[PandocMan] for details.

### Quarto

Install this filter as a Quarto extension with

    quarto install extension dialoa/greetings

and use it by adding `labelled-lists` to the `filters` entry
in their YAML header:

``` yaml
---
filters:
- labelled-lists
---
```

### R Markdown

Use `pandoc_args` to invoke the filter. See the [R Markdown
Cookbook](https://bookdown.org/yihui/rmarkdown-cookbook/lua-filters.html)
for details.

``` yaml
---
output:
  word_document:
    pandoc_args: ['--lua-filter=greetings.lua']
---
```

Usage
------------------------------------------------------------------

Acknowledgements
------------------------------------------------------------------

[Pandoc]: https://www.pandoc.org/
[Quarto]: https://www.quarto.org/
[PandocMan]: https://www.pandoc.org/MANUAL.html
