-- Navbar Generator Module
-- Handles HTML generation and text resolution

-- Key Design Decisions:
-- - Generate HTML that matches Quarto's sidebar classes and structure
-- - Support nested sections with proper Bootstrap collapse functionality
-- - Include proper CSS classes and data attributes
-- - Generate unique IDs for collapsible sections
-- - Ensure accessibility attributes are included

local generator = {}

local utils = require("navbar-utils")

-- Extract metadata from .qmd files using Pandoc's reader
function generator.extract_metadata_from_file(file_path)
  if not file_path then return nil end

  local file_handle = io.open(file_path, "r")
  if not file_handle then
    return nil
  end

  local content = file_handle:read("*all")
  file_handle:close()

  -- Parse with Pandoc to robustly handle YAML front matter
  local ok, parsed_doc = pcall(function()
    return pandoc.read(content, 'markdown')
  end)

  if not ok or not parsed_doc or not parsed_doc.meta then
    quarto.log.warning("Navbar Generator: Failed to parse YAML via pandoc.read for " .. tostring(file_path))
    return {
      title = nil,
      title_nav = nil,
      raw_meta = nil
    }
  end

  local meta = parsed_doc.meta
  local title = nil
  local title_nav = nil
  local order_nav = nil

  if meta.title then
    title = pandoc.utils.stringify(meta.title)
    if title == "" then title = nil end
  end

  -- Support custom navbar title override via `title-nav`
  if meta["title-nav"] then
    title_nav = pandoc.utils.stringify(meta["title-nav"]) 
    if title_nav == "" then title_nav = nil end
  end

      -- Support custom navbar order override via `order-nav`
    if meta["order-nav"] then
    order_nav = pandoc.utils.stringify(meta["order-nav"]) 
    if order_nav == "" then order_nav = nil end
  end

  return {
    title = title,
    title_nav = title_nav,
    order_nav = order_nav,
    raw_meta = meta
  }
end

-- Text resolution priority system
function generator.resolve_text(file_path, special_mappings, metadata, qmd_filename, qmd_fs_path, scope)
  if quarto.log.loglevel >= 3 then
    quarto.log.temp("Navbar Generator: Resolving text for file_path: " .. (file_path or "nil"))
    quarto.log.temp("Navbar Generator: qmd_filename: " .. (qmd_filename or "nil"))
  end

  -- Load metadata from file if available; fall back to provided metadata
  local file_meta = nil
  
  if qmd_filename then
    -- Convert web path to filesystem path and .html to .qmd
    local qmd_web_path = file_path:gsub("%.html$", ".qmd")
    local full_qmd_path = utils.web_path_to_fs_path(qmd_web_path)
    
    if full_qmd_path then
      -- Make it absolute by joining with project directory
      local project_dir = quarto.project.directory and tostring(quarto.project.directory) or nil
      if project_dir then
        full_qmd_path = utils.fs_join(project_dir, full_qmd_path)
      end
      
      file_meta = generator.extract_metadata_from_file(full_qmd_path)
    else
      if quarto.log.loglevel >= 3 then
        quarto.log.temp("Navbar Generator: qmd_filename = '" .. tostring(qmd_filename) .. "', could not convert web path")
      end
    end
  end
  
  if not file_meta and metadata then
    -- Normalise provided metadata shape
    file_meta = {
      title = metadata.title,
      title_nav = metadata["title-nav"] or metadata.title_nav,
      raw_meta = metadata
    }
  end

  -- Priority 1: YAML title-nav override from file metadata
  if file_meta and file_meta.title_nav and file_meta.title_nav ~= "" then
    return file_meta.title_nav
  end

  -- Priority 2: Special mappings (explicit overrides)
  if special_mappings and file_path and type(special_mappings) == "table" then
    for _, mapping in ipairs(special_mappings) do
      if mapping and mapping.path then
        local mapping_path = pandoc.utils.stringify(mapping.path)
        if mapping_path and type(mapping_path) == "string" then
          -- Fix: Use full path matching instead of filename-only matching
          if scope then
            -- Construct full scope-relative path for comparison
            local full_mapping_path = scope .. mapping_path:gsub("^/+", "")
            local normalized_mapping_path = utils.normalize_href(full_mapping_path)
            
            -- Convert file path to .qmd extension for comparison (since mappings use .qmd paths)
            local qmd_file_path = file_path:gsub("%.html$", ".qmd")
            
            -- Check if the file path matches the full mapping path
            if qmd_file_path == normalized_mapping_path then
              local title_str = mapping.title and pandoc.utils.stringify(mapping.title) or mapping_path:gsub("^/+", ""):gsub("%.qmd$", "")
              if quarto.log.loglevel >= 3 then
                quarto.log.temp("Navbar Generator: Special mapping matched (full path): " .. normalized_mapping_path .. " -> " .. title_str)
              end
              return title_str
            end
          else
            -- Fallback to filename matching if no scope provided (for backward compatibility)
            local mapping_filename = mapping_path:match("([^/]+)%.qmd$")
            if mapping_filename then
              local file_filename = file_path:match("([^/]+)%.html$")
              if file_filename and mapping_filename == file_filename then
                local title_str = mapping.title and pandoc.utils.stringify(mapping.title) or mapping_filename
                if quarto.log.loglevel >= 3 then
                  quarto.log.temp("Navbar Generator: Special mapping matched (filename fallback): " .. mapping_filename .. " -> " .. title_str)
                end
                return title_str
              end
            end
          end
        end
      end
    end
  end

  -- Priority 3: YAML title from file metadata
  if file_meta and file_meta.title and file_meta.title ~= "" then
    return file_meta.title
  end

  -- Priority 4: Smart filename conversion (use QMD filename if available)
  local filename_to_convert = qmd_filename or file_path
  local smart_title = generator.convert_filename_to_title(filename_to_convert)
  if smart_title then
    return smart_title
  end

  -- Priority 5: Fallback to cleaned filename
  local fallback_title = generator.clean_filename(filename_to_convert)
  return fallback_title
end

-- Convert filename to readable title
function generator.convert_filename_to_title(file_path)
  if not file_path then return nil end

  -- Extract the last part of the path (the actual filename)
  local path_parts = {}
  for part in file_path:gmatch("[^/\\]+") do
    table.insert(path_parts, part)
  end

  if #path_parts > 0 then
    local last_part = path_parts[#path_parts]
    -- Remove file extension
    last_part = last_part:gsub("%.qmd$", "")

    -- Handle common patterns
    if last_part:match("^w%d+") then
      -- Pattern: w01-practice.qmd → W01 Practice
      local week_num = last_part:match("^w(%d+)")
      local rest = last_part:sub(5) -- Remove "w01" part
      rest = rest:gsub("^%-", "") -- Remove leading dash
      rest = rest:gsub("_", " ") -- Replace underscores with spaces
      return "W" .. week_num .. " " .. rest:gsub("^%l", string.upper)
    end

    -- Convert kebab-case to Title Case
    local title = last_part:gsub("_", " ") -- Replace underscores with spaces
    title = title:gsub("-", " ") -- Replace hyphens with spaces
    title = title:gsub("^%l", string.upper) -- Capitalize first letter
    title = title:gsub(" %l", function(s) return " " .. string.upper(s:sub(2)) end) -- Capitalize words

    return title
  end

  return nil
end

-- Clean filename for fallback
function generator.clean_filename(file_path)
  if not file_path then return "Unknown" end

  -- Extract filename without extension
  local filename = file_path:match("([^/\\]+)%.?[^%.]*$")
  if not filename then return "Unknown" end

  -- Basic cleaning
  filename = filename:gsub("_", " ")
  filename = filename:gsub("-", " ")
  filename = filename:gsub("^%l", string.upper)

  return filename
end

-- Generate Quarto-compatible HTML
function generator.generate_html(hierarchy, current_path)
  if quarto.log.loglevel >= 3 then
    quarto.log.temp("Navbar Generator: Generating HTML for hierarchy")
  end

  -- TODO: Generate HTML that matches Quarto's sidebar classes and structure
  -- TODO: Support nested sections with proper Bootstrap collapse functionality
  -- TODO: Include proper CSS classes and data attributes
  -- TODO: Generate unique IDs for collapsible sections
  -- TODO: Ensure accessibility attributes are included

  return "<div class='auto-navbar-placeholder'>Placeholder HTML</div>"
end

-- Convert directory structure to nested HTML lists
function generator.build_menu_structure(hierarchy, current_path)
  if quarto.log.loglevel >= 3 then
    quarto.log.temp("Navbar Generator: Building menu structure")
  end

  -- TODO: Convert directory structure to nested HTML lists
  -- TODO: Create collapsible sections for directories
  -- TODO: Maintain proper nesting levels
  -- TODO: Handle mixed content (files and directories at same level)
  -- TODO: Support unlimited nesting (within level limits)

  return "<ul class='auto-navbar-menu'>Placeholder Menu</ul>"
end

return generator 