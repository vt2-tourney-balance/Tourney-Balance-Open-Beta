---
title: "Writing Patch Notes"
order: 3
---

## Creating & Modifing Pages
To create or modify patch notes on this GitHub pages site navigate to `site\content\patch-notes` under the TB Open Beta repository.
Patch notes are are Markdown files `.md` and can be modified with any text editor.

When creating a new file, make sure to add this preamble at the top.
```
---
title: Your Title
date: 2000-01-01
---
```

After pushing your changes, GitHub Actions will automatically build and deploy the site. 

## Markdown & Astro Syntax
This example demonstrates the syntax used by markdown.

### Code
````
<details>
<summary>Extra detail (collapsed by default)</summary>

Anything here renders normally as long as there's
a blank line right after `<summary>` and before `</details>`.

### Output

# H1 - Header 1
## H2 - Header 2
### H3 - Header 3
#### H4 - Header 4


**bold**, *italics*, ~strike through~, <u>underline</u>

- Plain bullet
* Another bullet
1. Enumerated
    1. Sub point
    * Also sub point

Inline `code` section.

```
code block
```
````

### Output
<details>
<summary>Extra detail (collapsed by default)</summary>

Anything here renders normally as long as there's a blank line right after `<summary>` and before `</details>`.


# H1 - Header 1
## H2 - Header 2
### H3 - Header 3
#### H4 - Header 4


**bold**, *italics*, ~strike through~, <u>underline</u>

- Plain bullet
* Another bullet
1. Enumerated
    1. Sub point
    * Also sub point

Inline `code` section.

```
code block
```

</details>
