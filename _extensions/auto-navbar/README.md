# Auto Navbar

A Quarto extension that automatically generates navigation bars based on your website structure, eliminating the need for manual navbar configuration.

## What It Does

The Auto Navbar extension scans your website's file structure and automatically creates navigation menus. This is perfect for:

- **Educational websites** where you want different navigation for different terms or courses
- **Documentation sites** that need navigation that reflects the actual content structure
- **Multi-section websites** where each section needs its own navigation hierarchy

## Installation

```bash
quarto add joncardoso/auto-navbar
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

### Configuration

Configure different navigation for different sections of your website:

```yaml
filters:
  - auto-navbar

auto-navbar:
  # General navigation for the whole site
  "general":
    special-mappings:
      - path: "/"
        title: "🏠 Home"
      - path: "/syllabus.qmd"
        title: "📔 Syllabus"
  
  # Specific navigation for 2024 autumn term
  "/2024/autumn-term/":
    levels: 3
    special-mappings:
      - path: "/"
        title: "🏠 Term Home"
      - path: "/course-info.qmd"
        title: "ℹ Course Info"
```

## Examples

### University Course Website

Imagine you have an educational website like the [Quarto Template for University Courses](https://github.com/jonjoncardoso/quarto-template-for-university-courses) and want to:

- Keep old material available but with different navigation
- Show current term material prominently in the navbar
- Automatically update navigation when you add new weeks

```yaml
auto-navbar:
  # Current term gets full navigation
  "/2024/autumn-term/":
    levels: 3
    special-mappings:
      - path: "/"
        title: "🏠 Autumn Term 2024"
      - path: "/syllabus.qmd"
        title: "📔 Syllabus"
      - path: "/weeks/week01/"
        title: "📅 Week 1: Introduction"
  
  # Archive terms get simplified navigation
  "/2023/":
    levels: 2
    special-mappings:
      - path: "/"
        title: "📚 Archive: 2023"
```

### Blog or Documentation Site

```yaml
auto-navbar:
  "/blog/":
    levels: 2
    special-mappings:
      - path: "/"
        title: "📰 Blog Home"
      - path: "/categories/"
        title: "🏷️ Categories"
  
  "/docs/":
    levels: 3
    special-mappings:
      - path: "/"
        title: "📖 Documentation"
```

## How It Works

1. **Scans your website structure** during build time
2. **Applies your configuration** for different sections
3. **Generates navigation HTML** automatically
4. **Injects the navigation** into your pages

## Configuration Options

- **`levels`**: How deep to scan directories (default: unlimited)
- **`special-mappings`**: Override automatic titles for specific files
- **Path-based targeting**: Different navigation for different website sections

## License

MIT License 