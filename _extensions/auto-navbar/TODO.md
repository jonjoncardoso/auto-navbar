# Auto Navbar Extension - Implementation Plan

> **Note**: This file consolidates all user stories and refactoring tasks. The previous `REFACTORING.md` file has been merged into this document as Epic 7: Code Refactoring and Architecture Improvements.

## User Stories and Implementation Plan

### ✅ Epic 1: Core Extension Setup - COMPLETED

#### ✅ User Story 1.1: Basic Extension Structure - COMPLETED

**As a user of this extension, I'd like to have a working extension skeleton that can be loaded by Quarto without errors.**

**✅ Completed Solution:**
- Created `_extension.yml` with proper metadata
- Created `auto-navbar.lua` file that returns the document unchanged
- Tested that extension loads without errors
- Added basic logging to confirm extension is being called

#### ✅ User Story 1.2: Configuration Parsing - COMPLETED

**As a user of this extension, I'd like to be able to configure the extension through YAML in `_quarto.yml`.**

**✅ Completed Solution:**
- Read `auto-navbar` configuration from document metadata
- Parse path-based configuration structure
- Extract special mappings and level limits
- Validate configuration structure
- Add error handling for malformed configuration

### ✅ Epic 2: Path Matching and Scope Detection - COMPLETED

#### ✅ User Story 2.1: Path-based Configuration Matching - COMPLETED

**As a user of this extension, I'd like the extension to apply different navbar configurations based on the current page's URL path.**

**✅ Completed Solution:**
- Determine current document's web path from file system path
- Match current path against configured path keys
- Support exact matches and partial matches (e.g., `/2024/autumn-term/` matches all pages in that section)
- Handle cases where no configuration matches
- Use relative paths (not hardcoded `/DS105/`) for portability

#### ✅ User Story 2.2: Scope Determination - COMPLETED

**As a user of this extension, I'd like the extension to understand which directory structure to scan for navbar generation.**

**✅ Completed Solution:**
- Extract root directory from matched configuration
- Determine scanning scope based on current page location
- Support different scopes: term-wide, section-specific, global
- Handle edge cases (blog posts, cross-term links)

### ✅ Epic 3: File System Scanning - COMPLETED

#### ✅ User Story 3.1: Directory Structure Discovery - COMPLETED

**As a user of this extension, I'd like the extension to automatically discover the file structure of my course content.**

**✅ Completed Solution:**
- Scan directory recursively for `.qmd` files
- Build hierarchical structure representation
- Respect level limits from configuration
- Handle nested directories and subdirectories
- Exclude non-content files and directories

#### ✅ User Story 3.2: File Metadata Extraction - COMPLETED

**As a user of this extension, I'd like the extension to extract titles and metadata from my `.qmd` files.**

**✅ Completed Solution:**
- Read YAML headers from `.qmd` files
- Extract `title` field from metadata
- Handle missing or malformed YAML gracefully
- Support other metadata fields if needed
- Cache metadata to avoid repeated file reads

### ✅ Epic 4: Text Resolution System - COMPLETED

#### ✅ User Story 4.1: Special Mappings Priority - COMPLETED

**As a user of this extension, I'd like to be able to override automatic text resolution with explicit mappings for specific files.**

**✅ Completed Solution:**
- Check special mappings first for each file
- Support exact path matching in special mappings
- Apply mappings before other text resolution methods
- Handle cases where mapping doesn't exist
- **Added order support for custom ordering**

#### ✅ User Story 4.2: YAML Metadata Priority - COMPLETED

**As a user of this extension, I'd like the extension to use titles from my `.qmd` file headers when available.**

**✅ Completed Solution:**
- Extract `title` field from YAML headers
- Use extracted title if available and not empty
- Fall back to filename conversion if no title found
- Handle malformed YAML gracefully

#### ✅ User Story 4.3: Smart Filename Conversion - COMPLETED

**As a user of this extension, I'd like the extension to intelligently convert filenames to readable menu text when no explicit title is available.**

**✅ Completed Solution:**
- Convert kebab-case to Title Case (e.g., `week01-lecture.qmd` → `Week 01 Lecture`)
- Handle common patterns (e.g., `w01-practice.qmd` → `W01 Practice`)
- Remove file extensions
- Handle special characters and numbers appropriately
- Provide fallback to cleaned filename

### ✅ Epic 5: HTML Generation - COMPLETED

#### ✅ User Story 5.1: Quarto-compatible HTML Generation - COMPLETED

**As a user of this extension, I'd like the extension to generate HTML that matches Quarto's sidebar structure exactly.**

**✅ Completed Solution:**
- Generate HTML that matches Quarto's sidebar classes and structure
- Support nested sections with proper Bootstrap collapse functionality
- Include proper CSS classes and data attributes
- Generate unique IDs for collapsible sections
- Ensure accessibility attributes are included

#### ✅ User Story 5.2: Hierarchical Menu Structure - COMPLETED

**As a user of this extension, I'd like the extension to create proper hierarchical menus that reflect the directory structure.**

**✅ Completed Solution:**
- Convert directory structure to nested HTML lists
- Create collapsible sections for directories
- Maintain proper nesting levels
- Handle mixed content (files and directories at same level)
- Support unlimited nesting (within level limits)

### ✅ Epic 6: Navbar Injection and Replacement - COMPLETED

#### ✅ User Story 6.1: Existing Navbar Removal - COMPLETED

**As a user of this extension, I'd like the extension to remove the existing Quarto-generated navbar before injecting the new one.**

**✅ Completed Solution:**
- Identify existing navbar elements in the document
- Remove or hide existing navbar HTML
- Ensure clean replacement without conflicts
- Handle cases where no existing navbar is found

#### ✅ User Story 6.2: New Navbar Injection - COMPLETED

**As a user of this extension, I'd like the extension to inject the generated navbar into the correct location in the HTML document.**

**✅ Completed Solution:**
- Inject generated navbar using JavaScript for precise positioning
- Ensure navbar appears in correct location relative to page structure
- Handle different page layouts and structures
- Use `#quarto-sidebar` selector for replacement

### ✅ Epic 7: Code Refactoring and Architecture Improvements - COMPLETED

#### ✅ User Story 7.1: Logging System Migration - COMPLETED

**As a developer, I want consistent logging throughout the codebase for better debugging and maintenance.**

**✅ Completed Solution:**
- Migrated from simple `_verbose` boolean to proper Quarto log levels
- Replaced all `if verbose then` checks with appropriate `quarto.log.*` calls
- Implemented proper log level configuration (`_logLevel` in config)
- Added comprehensive debug logging for AST injection investigation
- Cleaner function signatures without verbose parameters

#### ✅ User Story 7.2: Cross-platform Directory Walking - COMPLETED

**As a developer, I want file scanning to work on Windows, macOS, and Linux without shell-specific assumptions.**

**✅ Completed Solution:**
- Replaced Windows-specific `dir` command with `pandoc.system.list_directory()`
- Used cross-platform Pandoc API with proper error handling via `pcall()`
- Eliminated manual path separator conversions in favor of `pandoc.path.normalize()`
- Made the extension truly OS-agnostic without complex fallback logic

#### ✅ User Story 7.3: Configuration Validation and Error Handling - COMPLETED

**As a user, I want clear feedback when I misconfigure the extension.**

**✅ Completed Solution:**
- Comprehensive configuration validation in `__validate_config()` function
- Type validation for all configuration fields
- Graceful degradation on validation failure (doesn't crash render)
- Helpful error messages with specific context
- Proper Pandoc object handling for validation

#### ✅ User Story 7.4: HTML Generation Consolidation - COMPLETED

**As a developer, I want one clear layer to format Quarto-compatible sidebar HTML.**

**✅ Completed Solution:**
- HTML generation properly separated into `navbar-templates.lua`
- `navbar-generator.lua` focuses on metadata and text resolution, not markup
- Clear separation of concerns between structure and content
- Modular template system for maintainability

#### ❌ User Story 7.5: AST Injection Investigation - INVESTIGATED BUT UNABLE TO IMPLEMENT

**As a user, I want the navbar to be produced server-side so pages don't flash or depend on client JavaScript timing.**

**Investigation Results:**
- **AST manipulation cannot work** for sidebar modification because our extension runs too early in the Quarto pipeline
- **`quarto-navigation-envelope` is metadata only** - modifying it doesn't affect the rendered sidebar
- **JavaScript DOM replacement is the correct approach** for this use case
- **We were fighting against Quarto's architecture** instead of working with it

**Status**: UNABLE TO FIX - JavaScript DOM replacement remains the only viable injection method, as it's the proper way to modify rendered sidebar content in Quarto.

#### ❌ User Story 7.6: Stable ID Generation - INVESTIGATED BUT INVALID REQUIREMENT

**As a developer, I want section IDs to follow Pandoc's rules to avoid collisions and improve accessibility.**

**Investigation Results:**
- **`pandoc.utils.make_id()` function does not exist** in the current Pandoc Lua API
- **The requirement was based on incorrect assumptions** about available functions
- **Current ID generation using global counters is acceptable** for the current use case

**Status**: INVALID - Function doesn't exist in the API, current approach is sufficient.

### ✅ Epic 8: Enhanced Text Resolution Features - COMPLETED

#### ✅ User Story 8.0: Title-Nav Parameter Support - COMPLETED

**As a user of this extension, I'd like to be able to use an optional `title-nav` parameter in my `.qmd` file headers to override the navbar display text without affecting the page title.**

**✅ Completed Solution:**
- Support `title-nav` field in YAML headers as highest priority for navbar text
- Keep existing `title` field for page titles (unaffected by navbar)
- Maintain current priority system: `title-nav` > special mappings > `title` > smart filename conversion
- Ensure `title-nav` works consistently across all file types and nesting levels
- Update documentation to explain the `title-nav` parameter usage

#### ✅ User Story 8.1: Folder Special Mappings - COMPLETED

**As a user of this extension, I'd like to be able to create special mappings for folders/directories, not just individual files.**

**✅ Completed Solution:**
- Extend special mappings to support directory paths (e.g., `/weeks/` or `/assessments/`)
- Support both exact directory matches and nested directory patterns
- Apply custom titles and order values to directories
- Handle directory vs file path matching logic
- Update configuration documentation with folder mapping examples

#### ✅ User Story 8.2: Smart Folder Name Conversion - COMPLETED

**As a user of this extension, I'd like folder names to automatically get intelligent conversion treatment that makes navigation more readable and consistent, regardless of the specific naming convention used.**

**✅ Completed Solution:**
- Apply generic smart conversion logic to directory names (not hardcoded patterns)
- Convert any folder name using consistent rules:
  - `week01/` → `Week 01`
  - `princess01queen/` → `Princess 01 Queen`
  - `week-01/` → `Week 01`
  - `testThisOut/` → `Test This Out`
  - `test-this-out/` → `Test This Out`
  - `lab_solutions/` → `Lab Solutions`
- Use the same generic conversion logic for both files and folders
- Ensure the conversion is pattern-agnostic and handles any naming convention
- Keep special mappings as highest priority for folder names
- Update documentation to reflect that both files and folders get smart conversion

**Implementation Details:**
- Added `convert_folder_name_to_title()` function to `navbar-scanner.lua`
- Generic conversion handles kebab-case, camelCase, and word+numeral patterns
- Special rule for "word + numerals" → "Word Numerals" (e.g., `week01` → `Week 01`)
- Comprehensive debug logging for troubleshooting
- Integrated with existing folder mapping system

#### ✅ User Story 8.3: Order-Nav Metadata Support - COMPLETED

**As a user of this extension, I'd like to be able to specify the order of files in my navbar directly in the YAML front matter of each `.qmd` file, using an optional `order-nav` parameter that works alongside my existing `title-nav` parameter.**

**✅ Completed Solution:**
- Add `order-nav: 1` to a file's YAML header to control its position
- `order-nav` works with the existing ordering system
- Special mappings still take priority over `order-nav`
- Files without `order-nav` fall back to current behavior

**Example Usage:**
```yaml
---
title: Week 01 Lecture
title-nav: 🗣️ W01 Lecture
order-nav: 1
---
```

**Acceptance Criteria:**
1. ✅ Files with `order-nav` metadata appear in the specified order
2. ✅ Special mappings still take priority over `order-nav` values
3. ✅ Files without `order-nav` maintain current alphabetical sorting
4. ✅ The feature works consistently across all file types and nesting levels
5. ✅ Existing functionality (special mappings, title-nav, etc.) is preserved

**Technical Implementation:**
- Extended metadata extraction to include `order-nav` field
- Integrated with existing order resolution system
- Maintained current priority hierarchy
- Added appropriate logging and error handling

#### ✅ User Story 8.4: Collapsed State Control - COMPLETED

**As a user of this extension, I'd like to be able to control whether specific sections in my navbar are expanded or collapsed by default, using an optional `collapsed` parameter in special mappings.**

**✅ Completed Solution:**
- Add `collapsed: true/false` to special mappings for directories
- When `collapsed: true`, the section starts collapsed (user must click to expand)
- When `collapsed: false`, the section starts expanded (current behavior)
- Default to `collapsed: false` if not specified (maintains backward compatibility)
- Support both folder and file special mappings

**Example Usage:**
```yaml
special-mappings:
  - path: "/assessments/"
    title: "✍️ Assessments"
    order: 7
    collapsed: false  # Keep expanded
  - path: "/group-projects/"
    title: "👥 Group Projects"
    order: 8
    collapsed: false  # Keep expanded
  - path: "/weeks/"
    title: "🗓️ Weeks"
    order: 9
    collapsed: true   # Start collapsed
```

**Acceptance Criteria:**
1. ✅ `collapsed: true` makes sections start collapsed by default
2. ✅ `collapsed: false` makes sections start expanded by default
3. ✅ Default behavior is `collapsed: false` when parameter is omitted (backward compatible)
4. ✅ The feature works for both directory and file special mappings
5. ✅ Existing functionality (order, title, etc.) is preserved
6. ✅ The collapsed state is properly applied during HTML generation

**Technical Implementation:**
- Added `collapsed` field to special mapping configuration validation
- Extended folder mapping processing to include collapsed state
- Updated HTML template generation to respect collapsed parameter
- Maintained Bootstrap collapse functionality and accessibility
- Added appropriate logging for collapsed state processing

### ✅ Epic 9: Navigation Exclusion Controls - COMPLETED

#### ✅ User Story 9.1: Pattern-Based Exclusion - COMPLETED

**As a user of this extension, I'd like to be able to exclude files and directories from appearing in the navigation menu using pattern matching.**

**✅ Completed Solution:**
- Add `exclude` configuration parameter that accepts an array of patterns
- Support exact path matching (e.g., `/weeks/week01/draft.qmd`)
- Support wildcard patterns (e.g., `*draft*.qmd`, `*/drafts/`, `*temp*`)
- Support regex patterns for advanced filtering
- Apply exclusions during file scanning phase before hierarchy building
- Log excluded items for debugging purposes
- Handle both file and directory exclusions with single parameter

**Implementation Details:**
- Pattern type detection (literal vs regex)
- Glob-to-regex conversion for wildcard patterns
- Comprehensive logging and debugging support
- Production-ready with active usage in course configurations

#### ❌ User Story 9.2: Metadata-Based Exclusion - ABANDONED

**As a user of this extension, I'd like to be able to exclude files based on their YAML front matter content.**

**Status: ABANDONED**
- This feature will not be implemented
- Pattern-based exclusion provides sufficient functionality for current needs
- Metadata-based exclusion would add complexity without significant benefit

#### ✅ User Story 9.3: Exclusion Configuration Validation - COMPLETED

**As a user of this extension, I'd like clear feedback when my exclusion configuration is invalid or problematic.**

**✅ Completed Solution:**
- Validate exclusion patterns for syntax errors
- Check for conflicting or redundant exclusion rules
- Warn about potentially dangerous exclusion patterns (e.g., excluding all content)
- Provide helpful error messages with suggestions for fixing issues
- Log exclusion configuration for debugging purposes
- Validate metadata exclusion syntax and values

**Implementation Details:**
- Comprehensive type validation for exclusion patterns
- Detailed error messages with context and suggestions
- Graceful handling of malformed configurations
- Extensive logging for debugging and troubleshooting

#### ✅ User Story 9.4: Exclusion Performance Optimisation - COMPLETED

**As a user of this extension, I'd like the exclusion system to be fast and not significantly slow down navigation generation.**

**✅ Completed Solution:**
- Implement efficient pattern matching algorithms
- Cache exclusion results during file scanning
- Use early termination for obvious exclusion cases
- Profile and optimise exclusion logic for large file sets
- Add performance logging for exclusion operations
- Minimise metadata parsing overhead for exclusion checks

**Implementation Details:**
- Pattern type detection to avoid unnecessary regex conversion
- Early termination for obvious exclusion cases
- Efficient algorithms with minimal overhead
- Performance logging for monitoring and optimization

### 🔮 Epic 10: Tree-Preserving File System Scanner

#### User Story 10.1: Natural Hierarchy Preservation

**As a developer, I want the file system scanner to preserve the natural directory hierarchy during scanning instead of flattening everything and then rebuilding the structure.**

**Current Problem:**
- Scanner flattens all files into a single table
- Complex post-processing required to extract hierarchy information
- Path components must be parsed and reassembled
- Level calculations done after scanning
- Difficult to apply exclusions and mappings to specific tree levels

**Proposed Solution:**
- Refactor `scan_recursive` to return tree structure instead of flat table
- Preserve directory hierarchy naturally during scanning
- Eliminate need for `build_hierarchy` post-processing function
- Simplify exclusion and special mapping application logic
- Maintain same output format for compatibility

**Benefits:**
- **Natural Structure**: Tree hierarchy preserved as-is during scanning
- **No Path Parsing**: Directory structure maintained without string operations
- **Simpler Processing**: Exclusions and mappings applied directly to tree nodes
- **Better Performance**: No post-processing loops or component extraction
- **More Maintainable**: Clearer logic and easier debugging

**Implementation Plan:**
1. **Create `scan_recursive_tree` function** that returns tree structure
2. **Update processing logic** to work with trees instead of flat tables
3. **Simplify hierarchy building** by using tree structure directly
4. **Maintain compatibility** with existing HTML generation code
5. **Update documentation** to reflect new architecture

**Technical Details:**
- Tree nodes contain: `type`, `name`, `level`, `children`, `path` (for files)
- Directory nodes have `children` array
- File nodes have `path`, `fs_path`, `filename` properties
- Recursive structure mirrors actual file system hierarchy
- No changes to user configuration or output format

## Implementation Priority

### ✅ COMPLETED
1. **Epic 1**: Core Extension Setup (Foundation)
2. **Epic 2**: Path Matching and Scope Detection (Core Logic)
3. **Epic 3**: File System Scanning (Data Collection)
4. **Epic 4**: Text Resolution System (Content Processing)
5. **Epic 5**: HTML Generation (Output Creation)
6. **Epic 6**: Navbar Injection and Replacement (Integration)
7. **Epic 7**: Code Refactoring and Architecture Improvements (Maintainability)
8. **Epic 8**: Enhanced Text Resolution Features (New Requirements) - ✅ **COMPLETED**
9. **Epic 9**: Navigation Exclusion Controls (Content Filtering) - ✅ **COMPLETED**

### 🎯 NEXT PRIORITY
10. **Epic 10**: Tree-Preserving File System Scanner (Architecture Improvement)
    - Preserve natural directory hierarchy during scanning
    - Eliminate complex post-processing path parsing
    - Simplify exclusion and mapping application logic
    - Improve performance and maintainability

### 🔮 FUTURE ENHANCEMENTS
10. **Epic 10**: Tree-Preserving File System Scanner (Architecture Improvement)
    - Preserve natural directory hierarchy during scanning
    - Eliminate complex post-processing path parsing
    - Simplify exclusion and mapping application logic
    - Improve performance and maintainability

## Technical Notes

- Use relative paths throughout (no hardcoded `/DS105/`)
- Support both local development (`localhost:8888`) and production (`github.io`) URLs
- Build-time generation (not runtime JavaScript)
- Compatible with existing Quarto sidebar structure
- Follow Lua best practices and Quarto extension patterns
- **Order values take priority over directory/file distinction**
- **Special mappings support both files and folders**
- **Modular architecture for maintainability**
- **Comprehensive testing for reliability**
- **Exclusion system provides fine-grained content control** 