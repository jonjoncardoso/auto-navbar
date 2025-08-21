# Auto Navbar

[![Quarto Extension](https://img.shields.io/badge/Quarto-Extension-blue?style=flat&logo=quarto)](https://quarto.org/docs/extensions/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Version](https://img.shields.io/badge/version-0.1.0-blue.svg)](https://github.com/joncardoso/auto-navbar/releases)

A Quarto extension that automatically generates custom navigation sidebar for specified routes and sections of your Quarto website project. This is useful when you don't want the same navigation sidebar that Quarto generates based on the `sidebar` option in your `_quarto.yml` file everywhere on your website.

## Author

**Jon Cardoso-Silva** - [@jonjoncardoso](https://github.com/jonjoncardoso)

This extension was developed to solve navigation challenges in multi-term educational websites, particularly for the [DS105 course at LSE](https://lse-dsi.github.io/DS105/).

## Quick Links

- [Installation](#installation)
- [Usage](#usage)
- [Examples](#configuration-example)
- [Configuration Options](#configuration-options)

## What It Does

The Auto Navbar extension scans the folder and file structure nested inside the specified routes of your website and automatically creates and overwrites the navigation sidebar for those routes. By default the package will apply alphabetical order to the navigation sidebar but you can customise the order of the navigation items as well as the title of the navigation items. You can also customise whether the folders are collapsed or not.

This is perfect for:

- **Educational websites** where you want different navigation for different terms or courses, like the ones created with the [Quarto Template for University Courses](https://github.com/jonjoncardoso/quarto-template-for-university-courses).
- **Documentation sites** that need navigation that reflects the actual content structure versus previous versions of a package.
- **Multi-section websites** where each section needs its own navigation hierarchy

## Installation

```bash
quarto install extension jonjoncardoso/auto-navbar@v0.1.0
```

## Usage

### Basic Setup

Add the filter to your document or `_quarto.yml`:

```yaml
---
filters:
  - auto-navbar
---
```

Adding the filter alone won't trigger anything. You still need to specify at least one route to be scanned.

#### What Happens with Minimal Configuration

If you add just the basic configuration:

```yaml
auto-navbar:
  "/2024-2025/autumn-term/":
    levels: 3
```

The extension will scan your `/2024-2025/autumn-term/` directory and automatically generate navigation based on the file structure. For example, if you have this file structure:

```
2024-2025/
└── autumn-term/
    ├── index.qmd
    ├── syllabus.qmd
    ├── weeks/
    │   ├── week01/
    │   │   ├── lecture.qmd
    │   │   └── lab.qmd
    │   └── week02/
    │       ├── lecture.qmd
    │       └── lab.qmd
    └── assessments/
        ├── quiz1.qmd
        └── final.qmd
```

The extension will automatically create a sidebar navigation like this:

```text
- Assessments
  - Final
  - Quiz 1
- Syllabus
- Weeks
  - Week 01
    - Lab
    - Lecture
  - Week 02
    - Lab
    - Lecture
```

**Note**: With minimal configuration, the extension uses:
- File names (cleaned up) for navigation titles
- Alphabetical ordering
- All folders start expanded
- No exclusions

#### Customizing Individual Pages

You can override the automatic behavior by adding `title-nav` and `order-nav` to your `.qmd` files. For example, if you want your index and syllabus pages to appear at the top with custom titles:

In `/2024-2025/autumn-term/index.qmd`:
```yaml
---
title: "Autumn Term 2024/2025"
title-nav: "🏠 Home"
order-nav: 1
---
```

In `/2024-2025/autumn-term/syllabus.qmd`:
```yaml
---
title: "Course Syllabus"
title-nav: "📓 Syllabus"
order-nav: 2
---
```

Now your navigation will look like this:

```text
- 🏠 Home
- 📓 Syllabus
- Assessments
  - Final
  - Quiz 1
- Weeks
  - Week 01
    - Lab
    - Lecture
  - Week 02
    - Lab
    - Lecture
```

**Alternative**: Instead of adding `title-nav` and `order-nav` to individual `.qmd` files, you could add this directly to your `_quarto.yml`:

```yaml
auto-navbar:
  "/2024-2025/autumn-term/":
    levels: 3
    special-mappings:
      - path: "/index.qmd"
        title: "🏠 Home"
        order: 1
      - path: "/syllabus.qmd"
        title: "📓 Syllabus"
        order: 2
```

It's your choice. You can configure navigation either in individual `.qmd` files (using `title-nav` and `order-nav`) or in the `_quarto.yml` file (using `path`, `title` and `order` under `special-mappings`). Choose what works best for your workflow or what you find more convenient.

#### Customize How Folders Show Up

You can also customize how folders appear in the navigation. This can only be done via the `_quarto.yml` file using `special-mappings`:

```yaml
auto-navbar:
  "/2024-2025/autumn-term/":
    levels: 3
    special-mappings:
      - path: "/assessments/"
        title: "✍️ Coursework"
        order: 3
        collapsed: true
      - path: "/weeks/"
        title: "📅 Weekly Content"
        order: 4
```

The folder customization accepts:
- **`title`**: Custom name for the folder in navigation
- **`order`**: Position in the navigation
- **`collapsed`**: Whether the folder starts collapsed (`true`) or expanded (`false`)

**Note**: If `collapsed` is not specified, folders default to `collapsed: false` (expanded).

With the folder customization above, your navigation would now look like this:

```text
- 🏠 Home
- 📓 Syllabus
- ✍️ Coursework ⏵ (collapsed)
- 📅 Weekly Content 🔽 (expanded)
  - Week 01
    - Lab
    - Lecture
  - Week 02
    - Lab
    - Lecture
```

Notice that the `Assessments` folder now appears as "✍️ Coursework" and starts collapsed, while the `Weeks` folder appears as "📅 Weekly Content" and starts expanded.

### Configuration Example

Configure different navigation for different sections of your website.

Here is an example, inspired by how I configured the navigation sidebar for the [DS105 website](https://lse-dsi.github.io/DS105/), that allowed different iterations of the DS105 course to have their own unique navigation sidebar.

```yaml
filters:
  - auto-navbar

auto-navbar:
  # This will overwrite the navigation menu you'd normally get from the _quarto.yml file
  "/2024-2025/autumn-term/":
    levels: 3
    exclude: ["*slides.qmd", "*email*"]
    special-mappings:
      - path: "/guides/"
        title: "📚 Guides"
        order: 6
      - path: "/practice/"
        title: "📝 Practice"
        order: 7
        collapsed: true
      - path: "/summative/"
        title: "✍️ Summative"
        order: 8
        collapsed: true
      - path: "/weeks/"
        title: "🗓️ Weeks"
        order: 10
  
  "/2024-2025/winter-term/":
    levels: 3
    exclude: ["people.qmd", "analysis/", "feedback.qmd"]
    special-mappings:
      - path: "/guides/"
        title: "📚 Guides"
        order: 5
      - path: "/practice/"
        title: "📝 Practice"
        order: 6
        collapsed: false
      - path: "/weeks/"
        title: "🗓️ Weeks"
        order: 9
```

### In the _quarto.yml

The `_quarto.yml` configuration controls the overall structure and appearance of navigation sections. You can:

- **Set the order** of major sections using `order`
- **Control collapsing** with `collapsed: true/false`
- **Exclude files** that shouldn't appear in navigation
- **Limit depth** with `levels`

In the example above, the `order` option ensures that the `Guides` section is the 6th item in the navigation sidebar.

### Directly on .qmd files

For fine-grained control over individual pages, you can add `title-nav` and `order-nav` attributes directly to your `.qmd` files. This complements the `_quarto.yml` configuration.

For example, my `/2024-2025/autumn-term/index.qmd` can have:

```yaml
---
title: "🏠 Autumn Term 2024/2025" # Normal Quarto page title users see on the page
title-nav: "🏠 Home"               # Title used in the navigation sidebar
order-nav: 1                       # Amongst the other items at this same level, this will be the first item
---
```

And my `/2024-2025/autumn-term/syllabus.qmd` can have:

```yaml
---
title: "📓 Autumn Term 2024/2025 Syllabus" # Normal Quarto page title users see on the page
title-nav: "📓 Syllabus"                     # Title used in the navigation sidebar
order-nav: 2                                 # Amongst the other items at this same level, this will be the second item
---
```

**How they work together**: The `_quarto.yml` controls the structure (what sections exist, their order, collapsing), while the individual `.qmd` files control their own appearance within that structure (titles, positioning within their level).

#### Alternative (hypothetical) example

Say you host a Quarto website to document you open source software package. You might want to use the `_quarto.yml` file to configure the navigation sidebar for the most up-to-date (`/current/`) version of your package and then to archive previous versions of the package, say `/v1-0-0/`.

A hypothetical auto-navbar configuration for this might look like this:

```yaml
filters:
  - auto-navbar

auto-navbar:
  "/v1-0-0/":
    levels: 2
    special-mappings:
      - path: "/"
        title: "🏠 Home"
      - path: "/installation/"
        title: "📦 Installation"
      - path: "/usage/"
        title: "🚀 Usage"
      - path: "/examples/"
        title: "💡 Examples"
      - path: "/reference/"
        title: "📚 Reference"
```





## How It Works

1. **Scans your website structure** during build time
2. **Applies your configuration** for different sections
3. **Generates navigation HTML** automatically
4. **Injects the navigation** into your pages

## Configuration Options

- **`levels`**: How deep to scan directories (default: unlimited)
- **`exclude`**: Patterns to exclude from navigation (e.g., `["*slides.qmd", "/src/"]`)
- **`special-mappings`**: Override automatic titles and control navigation structure
  - **`order`**: Control the sequence of navigation items
  - **`collapsed`**: Whether a section starts collapsed (`true`/`false`)
  - **`title`**: Custom title for the navigation item

## License

MIT License 