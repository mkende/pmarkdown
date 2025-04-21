# pmarkdown supported syntax

This page describes the Markdown syntax supported by `pmarkdown` in its
*default* mode. That syntax can be changed by selecting another mode, as
[documented here](https://metacpan.org/pod/pmarkdown#MODES).

In addition, many of the behaviors of the program can be individually tweaked
through a large set of options. Some of the options are mentioned here but you
should refer to the
[options documentation](https://metacpan.org/pod/Markdown::Perl::Options) for
the complete list.

## Overview

The overall syntax is based on the
[CommonMark spec](https://spec.commonmark.org/0.31.2/) and is not fully defined
here. Refer to the spec for all the details.

The syntax is split into top-level blocks (which themselves can be containers
or not) and inline content inside most of these blocks. In general, the blocks
are always parsed first, and their inline content is parsed afterward and cannot
impact the rendering of the block.

## Escaping

Any symbol character can be prefixed by a single `\` in a Markdown source to
prevent any Markdown interpretation of that character and force it to be
rendered as-is in the output.

## Block structures

These are the leaves blocks, that is type of blocks that can’t contain other
blocks.

### Paragraphs

A paragraph is the simplest structure in Markdown. It’s just a set of line of
text that does not look like any other block. A single paragraph can span
multiple line of text but is interrupted at the first empty line, when
the structure of another block is recognised, or when the structure of a parent
block ends.

Note that the documentation of some block types says that they *cannot interrupt
a paragraph*. This means that such a block cannot immediately follow a paragraph
without being separated by an empty line.

Paragraphs are rendered in HTML within a single `<p>` tag. For example:

```md
foo
bar

baz
```

Is rendered as:

```html
<p>foo
bar</p>
<p>baz</p>
```

### Headings

By default, only so-called ATX headings are supported. These headings are a
single line of text, starting with a number of `#` characters, followed by at
least one space or tab, then the heading text property and optionally
terminated by another set of `#` characters which does not need to be of the
same length as the opening ones.

The heading level is determined by the number of opening `#` characters. For
example:

```md
# Foo

## Bar ###
```

Is rendered as:

```html
<h1>Foo</h1>
<h2>Bar</h2>
```

Because there is no strong consensus on their syntax, and it can be confused
with list label,
[*setext* headings](https://spec.commonmark.org/0.31.2/#setext-headings) are not
supported by default. They can be activated with the `use_setext_headings`
option.

### File metadata

The Markdown text can start with a YAML table, at the very beginning of the
content, to specify metadata for the file. This table must start with a line
containing only `---` and ends with a line containing only `---` or `...`. The
YAML content must not be empty and must not contain any blank line.

The YAML content is not part of the rendered HTML, but can be extracted by other
processing systems.

```md
---
foo: bar
baz: bin
...
baz
```

Is rendered as:

```html
<p>baz</p>
```

### Thematic breaks

A thematic break (usually rendered as a horizontal line through the page) can
be inserting three or more `-`, `_`, `*` characters alone on a line, optionally
separated by spaces or tabs. For
example:

```md
***

- - -
```

Is rendered as:

```html
<hr />
<hr />
```

### Code blocks

We support the two types of common code blocks: indented and fenced code blocks.

Indented code blocks are made of any paragraph starting with at least 4 spaces
or a tab.

Fenced code blocks starts with a line containing at least three backticks
(`` ` ``) or three tilde (`~`) characters in a row, optionally followed by some
text, called the *info string*. If the code blocks starts with backticks then
the info string cannot contain a backtick characters. The block extends until a
line containing only backticks or tilde (matching the opening character) and
using at least as many of these characters as the opening line.

For example:

```md
    foo
    bar
```

Is rendered as:

```html
<pre><code>foo
bar
</code></pre>
```

and

````md
``` c++
foo bar
```
````

Is rendered as:

```html
<pre><code class="language-c++">foo bar
</code></pre>
```

As can be seen in this example, when present the first word of the info string
(and only that one) is used to generate a *language* class for the `<code>` tag,
which is often recognised by syntax coloration scripts. This behavior can be
tweaked with the `code_blocks_info` option.

### Link reference definitions

The general syntax for links is described below but some links can use a
reference definition to avoid having to mention the URL at the point where the
link is used.

The reference definition can appear anywhere in the document as a paragraph of
its own (it can appear before or after where it is used, and can be inside
container blocks). It is recommended to put it soon after the point where it is
used, at the root of the document.

The general syntax is as follow: the link *label* between brackets, followed by
a colon, followed by optional spaces and up to one new line, followed by the URL
itself, optionally between angled brackets, optionally followed by spaces and up
to one new line and the link title, between single or double quotation mark.
Example:

> \[label]: https://example.com "Some title"

The link reference definition does not appear in the generated HTML, unless it
is used by an inline link. Note that the optional title cannot contain quotation
marks of the same type (simple or double) than the one that are used to quote
it. Also, if several link reference definitions are present with the same label,
a warning is emitted and only the first one is kept.

### HTML Blocks

A document can contain embedded HTML. At top level, the content of the HTML
block will start with an opening tag and continue until a matching closing tag
or a blank line, depending on the type of tags.

The complete rules are too complex to describe here. See the
[CommonMark spec](https://spec.commonmark.org/0.31.2/#html-blocks) for all the
details.

The content of the HTML block is included as-is in the output and is not parsed
as Markdown.

Note that you can use the `disallowed_html_tags` option to prevent some specific
HTML tags from being present in the HTML output. When this option is set, the
tags that it specifies will appear in the output as literal text, rather than
HTML markup.

### Tables

A table can be represented through a set of lines where the cells are separated
by pipes. The first line is the header line, the next line must be a separator
line and it must have exactly the same number of cells. Then a table can include
as many other lines as needed and their number of cells does not need to match
exactly the header line.

The separator line, consist of cells separated by pipes (like any other lines)
and the cells are made only of set of dashes (`-`) optionally with colons (`:`)
at the beginning or end of the cell, to signify the alignment of the column.
Example:

```md
| foo | bar | baz |
| :-- | --- | :-: |
| 1 | 2 | 3 |
```

Is rendered as:

```html
<table>
  <thead>
    <tr>
      <th align="left">foo</th>
      <th>bar</th>
      <th align="center">baz</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td align="left">1</td>
      <td>2</td>
      <td align="center">3</td>
    </tr>
  </tbody>
</table>
```

By default, tables cannot interrupt a paragraph (there must be a blank line
before them or they must appear just after a title or a similar construct) and
separating pipes (`|`) must be used at the beginning and end of each line of the
table. This behavior can be tweaked using the
`table_blocks_can_interrupt_paragraph` and `table_blocks_pipes_requirements`
options.

Note that if you put more cells in a line than there was in the header line,
then these cells will be ignored and a warning will be generated.

The content of all cells is interpreted as inline Markdown text but cannot
contain other Markdown blocks.

## Container blocks

The blocks are top-level structure (like the leaves blocks above) except that
they can contain any other Markdown blocks in addition to inline content.

### Lists

TODO, but note that pmarkdown is using the default
[CommonMark syntax](https://spec.commonmark.org/0.31.2/#list-items).

#### Task lists

TODO, but note that pmarkdown is using the default
[GitHub](https://github.github.com/gfm/#task-list-items-extension-).

### Block Quotes

TODO, but note that pmarkdown is using the default
[CommonMark syntax](https://spec.commonmark.org/0.31.2/#block-quotes).

### Directive blocks

Directive blocks can be used to specify custom HTML `div`. Such a block begins
with a line like `:::name[inline-content]{#id .class key=value}` which starts
with up to 3 optional spaces, followed by at least 3 colons, then a name for the
directive, then inline content, attributes, any number of colons, and finally a
newline. Each of these elements except the opening colons are optional and
spaces can be used to separate all the elements.

The block extends until the enclosing block ends, or until a line optionally
prefixed by up to 3 spaces and containing only colons in at least the same
number as those opening the block (before the name).

Example:

```md
::: name [inline-content] {#id .class key=value}
markdown content
:::
```

Is rendered as:

```html
<div id="id" class="name class" data-key="value">
  <p>markdown content</p>
</div>
```

Another example:

```md
:::::::: SPOILERS ::::::::
content
::::::::::::::::::::::::::
```

Is rendered as:

```html
<div class="spoilers">
  <p>content</p>
</div>
```

Note that the case change in the example above is applied only on a class
supplied as the name of the block. Also, as of know, the inline content of the
directive is ignored and will generate a warning if present.

## Inlines

Inline content is the content that can appear within other blocks or, as
paragraphs, directly at the root of the document. In general, each paragraph is
rendered within a `<p>` tag, but this may vary depending on the container block.

Note that, in the examples below, the `<p>` tag surrounding paragraphs is omitted
when it’s not relevant for the example.

### Text content

By default text that is not interpreted as anything else is rendered as-is in
the output:

```md
foo bar
```

Is rendered as:

```html
<p>foo bar</p>
```

### HTML entities

Any character can appear escaped in the input markdown and it will generally be
decoded in the output HTML. The supported escaping are the following:

-   decimal character references: `&#123;` where `123` is any decimal unicode
    code point.
-   hexadecimal character references: `&#X1bc;` where `1cb` is any hexadecimal
    unicode code point.
-   HTML entity reference: `&#abc;` where `abc` is a
    [valid HTML5 entity name](https://html.spec.whatwg.org/entities.json).
-   Backslash escaping: `\X` where `X` is an ASCII control character (e.g. `#`,
    `!`, or any other graphical, non-alphanumeric ASCII character).

For example:

```md inline
&#65;
&#X4B;
&mu;
\#
```

Is rendered as:

```html
A
K
μ
#
```

When it appears as an escaped entity, a character will never be part of a
Markdown construct (whether to indicate a block structure or an inline span) so
escaping can be used to prevent some text from being recognised as a Markdown
construct:

```md
\# this is not a header
```

Is rendered as:

```html
<p># this is not a header</p>
```

Finally, note that some characters with special meanings in HTML5 are always
escaped in the output, whether they appeared literally or escaped in the input:

```md inline
some "word"
```

Is rendered as:

```html
some &quot;word&quot;
```


### Soft and hard line breaks

New lines in a paragraph are rendered as-is, with a new line in the HTML output,
also called a soft line break:

```md
foo
bar
```

Is rendered as:

```html
<p>foo
bar</p>
```

It is possible to render hard line breaks (`<br />`) by putting a
backslash just before the end of the line:

```md
foo\
bar
```

Is rendered as:

```html
<p>foo<br />
bar</p>
```

Other Markdown engines allow to end the line with two spaces for a hard line
break. But, as this is mostly invisible in the Markdown source, this is not
supported in our default syntax. This can be activated with the
`two_spaces_hard_line_breaks` option.

### Emphasis and other markups

Emphasis and other spans of text can be delimited using some specific
characters. Our default syntax uses `*`, `_`, and `~`. The exact parsing rules
are too complex to be included here (they are documented in the
[CommonMark spec](https://spec.commonmark.org/0.31.2/#emphasis-and-strong-emphasis))
but, in general, a span will be delimited by one or two of the same character
among those listed above, when they are flanking the left side of a word, until
the same character in the same quantity is found flanking the right side of a
word:


```md inline
*emphasis (italic)*
_also emphasis_
**strong (bold)**
__also strong__
~strikethrough~
~~deleted~~
```

Is rendered as:

```html
<em>emphasis (italic)</em>
<em>also emphasis</em>
<strong>strong (bold)</strong>
<strong>also strong</strong>
<s>strikethrough</s>
<del>deleted</del>
```

Multiple different spans can be nested, but they can’t partially overlap:

```md inline
*this is em **and strong***
*this __is only em* and not strong__
```

Is rendered as:

```html
<em>this is em <strong>and strong</strong></em>
<em>this __is only em</em> and not strong__
```

The rendering of these delimited spans can be tuned with the `inline_delimiters`
option, which allows to specify arbitrary tags to generate for a given delimiter
(and can also be used to generate `<span>` with arbitrary classes).

### Links

TODO, but note that pmarkdown is using the default
[CommonMark syntax](https://spec.commonmark.org/0.31.2/#list-items).

### Images

TODO, but note that pmarkdown is using the default
[CommonMark syntax](https://spec.commonmark.org/0.31.2/#list-items).

### Autolinks

For URLs that *look like* links, they can appear directly in the Markdown text,
surrounded by angle brackets:

```md inline
<http://example.com/page?param=foo>
```

Is rendered as:

```html
<a href="http://example.com/page?param=foo">http://example.com/page?param=foo</a>
```

That syntax requires that the protocol (for example: `https:`) be present in the
link for it to be recognised.

An even lighter syntax exist, where the link can appear directly in the text if
there is no ambiguity. It must start by a protocol or by the string `www.` and
must come at the beginning of a line, after a whitespace, or after some other
existing delimiters:

```md inline
A link: www.example.com/page?param=foo.
```

Is rendered as:

```html
A link: <a href="https://www.example.com/page?param=foo">www.example.com/page?param=foo</a>.
```

As seen above, that syntax will try to exclude punctuation like `.` or `)`
following a link when it does not seem to be part of the link itself. Also, note
that the default `https:` protocol is added if it was missing. This can be
controlled using the `default_extended_autolinks_scheme` option.

### Raw HTML

Anything that looks like an HTML tag will appear as-is in the output. For
example:

```md inline
text that is <ins>inserted</ins>.
```

Is rendered as:

```html
text that is <ins>inserted</ins>.
```

As opposed to block-level HTML element, this applies only to the tag itself and
any other text will still be parsed as Markdown (including between two HTML
tags).

Note that you can use the `disallowed_html_tags` option to prevent some specific
HTML tags from being present in the HTML output. When this option is set, the
tags that it specifies will appear in the output as literal text, rather than
HTML markup.
