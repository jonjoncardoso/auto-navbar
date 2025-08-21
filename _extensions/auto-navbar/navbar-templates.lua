-- Navbar Templates Module
-- Contains HTML templates for Quarto sidebar structure

-- Key Design Decisions:
-- - Match Quarto's sidebar classes and structure exactly
-- - Support Bootstrap collapse functionality
-- - Include proper accessibility attributes
-- - Generate unique IDs for collapsible sections
-- - Use semantic HTML structure

local templates = {}

local utils = require("navbar-utils")

-- Generate unique ID for collapsible sections
local id_counter = 0
local function generate_id()
  id_counter = id_counter + 1
  return "quarto-sidebar-section-" .. id_counter
end

-- Convert hierarchy to HTML using proper Quarto sidebar classes
function templates.hierarchy_to_html(hierarchy, current_path, generator, special_mappings, current_depth, scope)
  if quarto.log.loglevel >= 3 then
    quarto.log.temp("Templates: hierarchy_to_html called with hierarchy type: " .. type(hierarchy) .. ", current_path: " .. tostring(current_path) .. ", depth: " .. tostring(current_depth or 1))
  end
  
  if not hierarchy or not hierarchy.children or #hierarchy.children == 0 then
    if quarto.log.loglevel >= 3 then
      quarto.log.temp("Templates: Hierarchy is empty or nil, returning empty string")
    end
    return ""
  end

  -- Set default depth if not provided
  current_depth = current_depth or 1
  
  if quarto.log.loglevel >= 3 then
    quarto.log.temp("Templates: Processing hierarchy with " .. #hierarchy.children .. " items at depth " .. current_depth)
  end
  
  -- Use appropriate classes based on depth level
  local ul_class = ""
  if current_depth == 1 then
    ul_class = 'list-unstyled mt-1'
  else
    ul_class = 'list-unstyled'
  end
  
  local html = '<ul class="' .. ul_class .. '">'
  
  for i, item in ipairs(hierarchy.children) do
    if quarto.log.loglevel >= 3 then
      quarto.log.temp("Templates: Processing item " .. i .. ", type: " .. type(item) .. ", content: " .. tostring(item))
    end
    
    if item.type == "file" then
      -- Generate file link with proper Quarto sidebar classes
      local href = item.path
      local text = generator.resolve_text(item.path, special_mappings, nil, item.qmd_filename, item.qmd_fs_path, scope)
      local is_active = item.path == current_path
      
      if quarto.log.loglevel >= 3 then
        quarto.log.temp("Templates: File item - href: " .. tostring(href) .. ", text: " .. tostring(text) .. ", is_active: " .. tostring(is_active))
      end
      
      local active_class = is_active and ' active' or ""
      html = html .. templates.sidebar_item(text, href, is_active)
      
    elseif item.type == "directory" then
      -- Generate directory section with proper Quarto sidebar section classes
      if quarto.log.loglevel >= 3 then
        quarto.log.temp("Templates: Directory item - name: " .. tostring(item.name) .. ", children count: " .. (item.children and #item.children or "nil"))
      end
      
      local section_id = generate_id()
      local display_text = item.title or item.name
      
      -- Use collapsed state from hierarchy instead of hardcoded true
      local is_expanded = true  -- Default to expanded for backward compatibility
      if item.collapsed ~= nil then
        is_expanded = not item.collapsed  -- collapsed: true means is_expanded: false
      end
      
      -- Recursively generate content for this directory with incremented depth
      local section_content = templates.hierarchy_to_html(item, current_path, generator, special_mappings, current_depth + 1, scope)
      
      html = html .. templates.sidebar_section(section_id, display_text, section_content, is_expanded, current_depth)
      
    else
      if quarto.log.loglevel >= 3 then
        quarto.log.temp("Templates: Unknown item type: " .. tostring(item.type or "nil"))
      end
    end
  end
  
  html = html .. '</ul>'
  if quarto.log.loglevel >= 3 then
    quarto.log.temp("Templates: Generated HTML length: " .. #html .. ", preview: " .. html:sub(1, 200))
  end
  return html
end

-- Clean directory name for display
function templates.clean_directory_name(name)
  -- Convert kebab-case to Title Case
  local clean_name = name:gsub("_", " ")
  clean_name = clean_name:gsub("-", " ")
  clean_name = clean_name:gsub("^%l", string.upper)
  clean_name = clean_name:gsub(" %l", function(s) return " " .. string.upper(s:sub(2)) end)

  return clean_name
end

-- Check if hierarchy contains current page
function templates.contains_current_page(hierarchy, normalized_current)
  if not hierarchy or not hierarchy.children then
    return false
  end

  for _, item in ipairs(hierarchy.children) do
    if item.type == "file" and utils.normalized_compare_key(item.path) == normalized_current then
      return true
    elseif item.type == "directory" then
      if templates.contains_current_page(item, normalized_current) then
        return true
      end
    end
  end

  return false
end

-- Basic navbar container template - matches Quarto's sidebar structure exactly
function templates.navbar_container(content)
  return string.format([[
<nav id="quarto-sidebar" class="sidebar collapse collapse-horizontal sidebar-navigation docked overflow-auto"
    style="top: 58px; max-height: calc(-58px + 100vh);">
    <div class="sidebar-menu-container">
        %s
    </div>
</nav>
]], content)
end

-- Quarto sidebar item template - matches original-nav.js exactly
function templates.sidebar_item(text, href, is_active)
  local active_class = is_active and ' active' or ''
  return string.format([[
<li class="sidebar-item">
    <div class="sidebar-item-container">
        <a href="%s" class="sidebar-item-text sidebar-link%s">
            <span class="menu-text">%s</span></a>
    </div>
</li>
]], href or '#', active_class, text or '')
end

-- Quarto sidebar section template - matches original-nav.js exactly
function templates.sidebar_section(id, title, content, is_expanded, depth)
  local expanded_attr = is_expanded and ' aria-expanded="true"' or ' aria-expanded="false"'
  local collapsed_class = is_expanded and '' or ' collapsed'
  local show_class = is_expanded and ' show' or ''
  local depth_class = depth and (' depth' .. depth) or ' depth1'

  return string.format([[
<li class="sidebar-item sidebar-item-section">
    <div class="sidebar-item-container">
        <a class="sidebar-item-text sidebar-link text-start%s" data-bs-toggle="collapse"
            data-bs-target="#%s"%s>
            <span class="menu-text">%s</span></a>
        <a class="sidebar-item-toggle text-start" data-bs-toggle="collapse"
            data-bs-target="#%s"%s aria-label="Toggle section">
            <i class="bi bi-chevron-right ms-2"></i>
        </a>
    </div>
    <ul id="%s" class="collapse list-unstyled sidebar-section%s%s">
        %s
    </ul>
</li>
]], collapsed_class, id, expanded_attr, title or '', 
   id, expanded_attr, id, depth_class, show_class, content or '')
end

return templates 