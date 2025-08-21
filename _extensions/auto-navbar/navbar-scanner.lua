-- Navbar Scanner Module
-- Handles file system scanning and hierarchical structure discovery

-- Key Design Decisions:
-- - Scan directories recursively up to configured max levels
-- - Filter for .qmd files only
-- - Convert file system paths to web paths
-- - Build hierarchical structure from flat file list
-- - Support OS-agnostic path handling

local scanner = {}

-- Import utils via require path configured in main filter
local utils = require("navbar-utils")

-- Private function to detect pattern type (literal vs regex)
local function __detect_pattern_type(pattern)
  if string.find(pattern, "*", 1, true) then
    return "regex"
  else
    return "literal"
  end
end

-- Private function to convert glob pattern to Lua regex
local function __glob_to_regex(glob_pattern)
  -- Escape special regex characters except *
  local escaped = glob_pattern:gsub("[%^%$%(%)%.%[%]%+%-%?]", "%%%1")
  
  -- Convert * to .* for regex matching
  local regex = escaped:gsub("%*", ".*")
  
  -- Ensure the pattern matches the entire string
  return "^" .. regex .. "$"
end

-- Convert folder name to readable title (generic, pattern-agnostic approach)
function scanner.convert_folder_name_to_title(folder_name)
  if not folder_name then 
    quarto.log.debug("  [FOLDER CONVERSION] Input is nil, returning nil")
    return nil 
  end

  if quarto.log.loglevel >= 3 then
    quarto.log.temp("  [FOLDER CONVERSION] Converting folder name: '" .. folder_name .. "'")
  end

  -- Generic conversion: handle any naming convention
  local title = folder_name
  
  -- Replace underscores and hyphens with spaces
  title = title:gsub("_", " ")
  title = title:gsub("-", " ")
  
  -- Handle camelCase and PascalCase by inserting spaces before capitals
  -- But preserve numbers and avoid breaking up common patterns
  title = title:gsub("(%l)(%u)", "%1 %2") -- lowercase followed by uppercase
  title = title:gsub("(%d)(%u)", "%1 %2") -- digit followed by uppercase
  title = title:gsub("(%u)(%l)", "%1%2") -- uppercase followed by lowercase (keep together)
  
  -- Special rule: separate word from numerals with a space
  -- This handles cases like "week01" → "week 01"
  title = title:gsub("(%a)(%d+)", "%1 %2") -- letter followed by digits
  
  -- Clean up multiple spaces and trim
  title = title:gsub("%s+", " ") -- Replace multiple spaces with single space
  title = title:gsub("^%s*(.-)%s*$", "%1") -- Trim leading/trailing spaces
  
  -- Capitalize first letter and words after spaces
  title = title:gsub("^%l", string.upper) -- First letter
  title = title:gsub(" %l", function(s) return " " .. string.upper(s:sub(2)) end) -- Words after spaces

  if quarto.log.loglevel >= 3 then
    quarto.log.temp("  [FOLDER CONVERSION] Generic conversion result: '" .. title .. "'")
  end
  return title
end

-- Check if a path should be excluded based on exclusion patterns
function scanner.should_exclude(path, exclude_patterns)
  if not exclude_patterns or #exclude_patterns == 0 then
    return false
  end
  
  for _, pattern in ipairs(exclude_patterns) do
    local pattern_str = pandoc.utils.stringify(pattern)
    if pattern_str then
      -- Convert .qmd patterns to .html for matching
      local converted_pattern = pattern_str:gsub("%.qmd$", ".html")
      
      -- Detect pattern type and apply appropriate matching
      local pattern_type = __detect_pattern_type(converted_pattern)
      
      if pattern_type == "regex" then
        -- Convert glob pattern to Lua regex and match
        local regex_pattern = __glob_to_regex(converted_pattern)
        if string.match(path, regex_pattern) then
          if quarto.log.loglevel >= 3 then
            quarto.log.temp("Scanner: Excluding path '" .. path .. "' due to regex pattern '" .. pattern_str .. "' (converted to '" .. regex_pattern .. "')")
          end
          return true
        end
      else
        -- Literal pattern matching (current behavior)
        if string.find(path, converted_pattern, 1, true) then
          if quarto.log.loglevel >= 3 then
            quarto.log.temp("Scanner: Excluding path '" .. path .. "' due to literal pattern '" .. pattern_str .. "' (converted to '" .. converted_pattern .. "')")
          end
          return true
        end
      end
    end
  end
  
  return false
end

-- Private function to extract metadata from a file
local function __extract_file_metadata(file_info)
  if quarto.log.loglevel >= 3 then
    quarto.log.temp("  [NAVBAR SCANNER] Extracting metadata from: " .. (file_info.fs_path or "nil"))
  end
  
  -- Extract metadata using Pandoc
  local file_content = ""
  local file_handle = io.open(file_info.fs_path, "r")
  if file_handle then
    file_content = file_handle:read("*all")
    file_handle:close()
  end

  if file_content and file_content ~= "" then
    local ok, doc = pcall(pandoc.read, file_content, "markdown")
    if ok and doc and doc.meta then
      -- Extract title from metadata
      local title = nil
      if doc.meta.title then
        title = pandoc.utils.stringify(doc.meta.title)
      end
      
      -- Extract title-nav from metadata (priority over title)
      local title_nav = nil
      if doc.meta["title-nav"] then
        title_nav = pandoc.utils.stringify(doc.meta["title-nav"])
      end
      
      -- Extract order-nav from metadata
      local order_nav = nil
      if doc.meta["order-nav"] then
        order_nav = pandoc.utils.stringify(doc.meta["order-nav"])
        quarto.log.debug("  [NAVBAR SCANNER] Found order-nav metadata: '" .. tostring(order_nav) .. "' in file: " .. tostring(file_info.fs_path))
        -- Store the metadata for later use in order resolution
        file_info.metadata = {
          order_nav = order_nav
        }
      end
      
      -- Use title-nav if available, otherwise fall back to title
      file_info.title = title_nav or title or file_info.filename
    else
      file_info.title = file_info.filename
    end
  else
    file_info.title = file_info.filename
  end
end

-- Private function to process file hierarchy information
local function __process_file_hierarchy(file_info, scope_prefix)
  -- Process path for hierarchy building
  local path = file_info.path
  local scope = scope_prefix or ""
  
  if quarto.log.loglevel >= 3 then
    quarto.log.temp("  [NAVBAR SCANNER] Processing file path: " .. path)
  end
  
  -- Remove scope prefix from path for relative positioning
  local clean_path = path
  local clean_scope = scope
  
  -- Normalize paths for comparison
  if clean_scope and clean_scope ~= "" then
    clean_scope = clean_scope:gsub("^/+", ""):gsub("/+$", "")
    clean_path = clean_path:gsub("^/+", ""):gsub("/+$", "")
    
    if clean_path:find(clean_scope, 1, true) == 1 then
      local relative_path = clean_path:sub(#clean_scope + 2) -- +2 for "/"
      if quarto.log.loglevel >= 3 then
        quarto.log.temp("Navbar Scanner: Stripped scope, relative path: " .. relative_path)
      end
      file_info.relative_path = relative_path
    else
      if quarto.log.loglevel >= 3 then
        quarto.log.temp("Navbar Scanner: No scope prefix match")
      end
      file_info.relative_path = clean_path
    end
  else
    file_info.relative_path = clean_path:gsub("^/+", ""):gsub("/+$", "")
  end
  
  -- Split path into components for hierarchy
  local components = {}
  if file_info.relative_path and file_info.relative_path ~= "" then
    for component in file_info.relative_path:gmatch("[^/]+") do
      table.insert(components, component)
    end
  end
  
  if quarto.log.loglevel >= 3 then
    quarto.log.temp("Navbar Scanner: Components: " .. table.concat(components, ", "))
  end
  
  if #components == 0 then
    if quarto.log.loglevel >= 3 then
      quarto.log.temp("Navbar Scanner: Skipping file with no components")
    end
    return false
  end
  
  -- Build hierarchy path
  file_info.hierarchy_path = components
  file_info.level = #components
  
  return true
end

-- Recursive function to scan directories
local function __scan_recursive(current_path, current_level, max_levels, scope_prefix, relative_base, files_table)
  if current_level > max_levels then 
    if quarto.log.loglevel >= 3 then
      quarto.log.temp("  [NAVBAR SCANNER] Reached max level " .. current_level .. " > " .. max_levels .. ", stopping recursion")
    end
    return 
  end
  
  local path_type = utils.is_file_or_directory(current_path)
  if path_type ~= "directory" then return end

  quarto.log.debug("  [NAVBAR SCANNER] Scanning level " .. current_level .. " at: " .. current_path)
  
  -- Cross-platform directory listing using Pandoc
  local entries = {}
  local ok, items = pcall(pandoc.system.list_directory, current_path)
  if ok and items then
    if quarto.log.loglevel >= 3 then
      quarto.log.temp("  [NAVBAR SCANNER] Level " .. current_level .. " - found " .. #items .. " items")
    end
    for _, item in ipairs(items) do
      if item and item ~= "." and item ~= ".." then
        table.insert(entries, item)
      end
    end
  else
    quarto.log.warning("  [NAVBAR SCANNER] Failed to list directory: '" .. tostring(current_path) .. "'")
    if quarto.log.loglevel >= 3 then
      quarto.log.temp("  [NAVBAR SCANNER] Directory listing failed, ok=" .. tostring(ok) .. ", items=" .. tostring(items))
    end
    return
  end

  for _, item in ipairs(entries) do
    local item_path = utils.fs_join(current_path, item)
    local item_relative = relative_base and (relative_base .. "/" .. item) or item

    -- Use our utility function to properly detect files vs directories
    local item_type = utils.is_file_or_directory(item_path)
    
    if item_type == "file" then
      -- Consider only .qmd files
      local stem, ext = pandoc.path.split_extension(item)
      if ext == ".qmd" then
        -- Build web path: relative to scope, with .html extension
        local html_rel = item_relative:gsub("%.qmd$", ".html")
        local web_path = scope_prefix and (scope_prefix .. "/" .. html_rel) or ("/" .. html_rel)

        -- Cleanup repeated slashes
        web_path = web_path:gsub("//+", "/")
        
        if quarto.log.loglevel >= 3 then
          quarto.log.temp("  [NAVBAR SCANNER] Level " .. current_level .. " - Found .qmd file: " .. item .. " -> " .. web_path)
        end

        table.insert(files_table, {
          path = web_path,
          filename = item,
          fs_path = item_path
        })
      end
    elseif item_type == "directory" then
      -- It's a directory, scan recursively
      if quarto.log.loglevel >= 3 then
        quarto.log.temp("  [NAVBAR SCANNER] Level " .. current_level .. " - Found directory: " .. item .. ", recursing to level " .. (current_level + 1))
      end
      __scan_recursive(item_path, current_level + 1, max_levels, scope_prefix, item_relative, files_table)
    else
      if quarto.log.loglevel >= 3 then
        quarto.log.temp("  [NAVBAR SCANNER] Level " .. current_level .. " - Skipping unknown item type: " .. item)
      end
    end
  end
end

-- Scan directory recursively for .qmd files
function scanner.scan_directory(root_path, max_levels, scope_prefix)
  
  -- Convert max_levels to number if it's a Pandoc object
  if max_levels and type(max_levels) ~= "number" then
    max_levels = tonumber(pandoc.utils.stringify(max_levels))
  end

  quarto.log.debug("  [NAVBAR SCANNER] Scanning " .. (root_path or "nil") .. " (max levels: " .. tostring(max_levels or "nil") .. ")")

  local files = {}

  -- Convert web path to file system path
  local fs_root_path = utils.web_path_to_fs_path(root_path)
  if quarto.log.loglevel >= 3 then
    quarto.log.temp("  [NAVBAR SCANNER] web_path_to_fs_path output: '" .. tostring(fs_root_path) .. "'")
  end

  -- Get project directory for absolute path
  local project_dir = quarto.project.directory and tostring(quarto.project.directory) or nil
  if not project_dir then
    quarto.log.error("[AUTO NAVBAR] | NAVBAR SCANNER | Could not determine project directory")
    return files
  end

  -- Build absolute path to scan
  local absolute_path = utils.fs_join(project_dir, fs_root_path)
  if not absolute_path or absolute_path == "" then
    quarto.log.error("[AUTO NAVBAR] | NAVBAR SCANNER | Absolute path to scan is nil or empty. Cannot proceed with directory scan.")
    return files
  end
  if quarto.log.loglevel >= 3 then
    quarto.log.temp("  [NAVBAR SCANNER] absolute_path to scan: '" .. tostring(absolute_path) .. "'")
  end

  local path_type = utils.is_file_or_directory(absolute_path)
  if path_type == "directory" then
    if quarto.log.loglevel >= 3 then
      quarto.log.temp("  [NAVBAR SCANNER] Path is a directory, scanning here")
    end
    -- Path is a directory, scan it directly
  else
    if quarto.log.loglevel >= 3 then
      quarto.log.temp("  [NAVBAR SCANNER] Path is not a directory, trying parent")
    end
    -- Try parent directory
    absolute_path = pandoc.path.directory(absolute_path)
    if quarto.log.loglevel >= 3 then
      quarto.log.temp("  [NAVBAR SCANNER] Updated absolute_path to parent: '" .. absolute_path .. "'")
    end
  end

  -- Start recursive scanning
  __scan_recursive(absolute_path, 1, max_levels, scope_prefix, "", files)

  quarto.log.debug("  [NAVBAR SCANNER] | Found " .. #files .. " .qmd files")
  if quarto.log.loglevel >= 3 then
    quarto.log.temp('files', files)
  end

  -- Extract metadata and process hierarchy for each file
  for i, file_info in ipairs(files) do
    __extract_file_metadata(file_info)
    if not __process_file_hierarchy(file_info, scope_prefix) then
      -- Skip files with no valid hierarchy
      goto continue
    end
  end
  
  ::continue::



  -- Sort files by hierarchy level and then by filename
  table.sort(files, function(a, b)
    if a.level ~= b.level then
      return a.level < b.level
    end
    return a.filename < b.filename
  end)

  return files
end

-- Build hierarchical structure from flat file list
function scanner.build_hierarchy(files, max_levels, scope_prefix)
  if quarto.log.loglevel >= 3 then
    quarto.log.temp("Scanner: build_hierarchy called with " .. #files .. " files")
  end
  
  local hierarchy = { children = {} }
  
  for i, file_info in ipairs(files) do
    if quarto.log.loglevel >= 3 then
      quarto.log.temp("Scanner: Processing file " .. i .. ": " .. tostring(file_info.filename) .. ", hierarchy_path: " .. tostring(file_info.hierarchy_path and table.concat(file_info.hierarchy_path, ", ") or "nil"))
    end
    
    local current_level = hierarchy
    
    -- Navigate to the appropriate level in the hierarchy
    for j, component in ipairs(file_info.hierarchy_path) do
      if quarto.log.loglevel >= 3 then
        quarto.log.temp("Scanner: Component " .. j .. ": " .. tostring(component) .. ", is_last: " .. tostring(j == #file_info.hierarchy_path))
      end
      
      if j == #file_info.hierarchy_path then
        -- This is the file level, add the file
        if quarto.log.loglevel >= 3 then
          quarto.log.temp("Scanner: Adding file to hierarchy: " .. tostring(file_info.filename))
        end
        local file_entry = {
          type = "file",
          name = component,
          path = file_info.path,
          title = file_info.title,
          filename = file_info.filename,
          fs_path = file_info.fs_path,
          qmd_filename = file_info.filename,
          qmd_fs_path = file_info.fs_path,
          level = j
        }
        
        -- Preserve order value if it exists
        if file_info.order then
          file_entry.order = file_info.order
          quarto.log.debug("  [NAVBAR SCANNER] Applied existing order " .. file_info.order .. " to file: " .. tostring(file_info.filename))
        end
        
        -- Apply order from metadata if no special mapping order exists
        if not file_info.order and file_info.metadata and file_info.metadata.order_nav then
          local metadata_order = tonumber(file_info.metadata.order_nav)
          if metadata_order then
            file_entry.order = metadata_order
            quarto.log.debug("  [NAVBAR SCANNER] Applied order-nav metadata order " .. metadata_order .. " to file: " .. tostring(file_info.filename))
          end
        end
        
        -- Insert at current level
        table.insert(current_level.children, file_entry)
      else
        -- This is a directory level, create or navigate to it
        local found_dir = nil
        
        for _, item in ipairs(current_level.children) do
          if item.type == "directory" and item.name == component then
            found_dir = item
            if quarto.log.loglevel >= 3 then
              quarto.log.temp("Scanner: Found existing directory: " .. tostring(component))
            end
            break
          end
        end
        
        if not found_dir then
          -- Create new directory entry
          if quarto.log.loglevel >= 3 then
            quarto.log.temp("Scanner: Creating new directory: " .. tostring(component))
          end
          
          -- Apply smart folder name conversion (same logic as files)
          if quarto.log.loglevel >= 3 then
            quarto.log.temp("  [FOLDER CONVERSION] Calling convert_folder_name_to_title for component: '" .. component .. "'")
          end
          local folder_title = scanner.convert_folder_name_to_title(component)
          quarto.log.debug("  [NAVBAR SCANNER] Converted folder name: '" .. component .. "' -> '" .. (folder_title or "nil") .. "'")
          
          
          found_dir = {
            type = "directory",
            name = component,
            title = folder_title,  -- Use converted title instead of raw name
            level = j,
            children = {}
          }
          
          -- Apply folder special mappings if this directory has one (highest priority)
          if scanner.folder_mappings and scanner.folder_mappings[component] then
            local folder_mapping = scanner.folder_mappings[component]
            found_dir.title = folder_mapping.title  -- Override with special mapping
            found_dir.order = folder_mapping.order
            
            -- Apply collapsed state from special mapping
            if folder_mapping.collapsed ~= nil then
              found_dir.collapsed = folder_mapping.collapsed
            else
              found_dir.collapsed = false  -- Default to collapsed: false (expanded)
            end
            
            if quarto.log.loglevel >= 3 then
              quarto.log.temp("Scanner: Applied folder mapping to " .. component .. " -> title: " .. tostring(folder_mapping.title) .. ", order: " .. tostring(folder_mapping.order or "nil") .. ", collapsed: " .. tostring(found_dir.collapsed))
            end
          else
            -- Set default collapsed state for folders without special mappings
            found_dir.collapsed = false  -- Default to collapsed: false (expanded)
          end
          
          table.insert(current_level.children, found_dir)
        end
        
        current_level = found_dir
      end
    end
  end
  
  -- Sort the hierarchy by order values first, then by type, then alphabetically
  local function sort_hierarchy(node)
    if node.children then
      -- Sort children: order values first, then directories, then files
      table.sort(node.children, function(a, b)
        -- Check for order values first (highest priority)
        local a_order = a.order
        local b_order = b.order

        -- If both have order values, sort by order
        if a_order and b_order then
          return a_order < b_order
        elseif a_order then
          -- a has order, b doesn't - a comes first regardless of type
          return true
        elseif b_order then
          -- b has order, a doesn't - b comes first regardless of type
          return false
        else
          -- Neither has order, use type-based sorting
          -- Directories come before files
          if a.type == "directory" and b.type == "file" then
            return true
          elseif a.type == "file" and b.type == "directory" then
            return false
          else
            -- Both are same type, sort alphabetically
            return a.name < b.name
          end
        end
      end)

      -- Recursively sort children
      for _, child in ipairs(node.children) do
        if child.type == "directory" then
          sort_hierarchy(child)
        end
      end
    end
  end

  sort_hierarchy(hierarchy)
  
  if quarto.log.loglevel >= 3 then
    quarto.log.temp("Scanner: Final hierarchy structure: " .. type(hierarchy) .. ", count: " .. #hierarchy.children)
  end
  for i, item in ipairs(hierarchy.children) do
    if quarto.log.loglevel >= 3 then
      quarto.log.temp("Scanner: Top level item " .. i .. ": type=" .. tostring(item.type) .. ", name=" .. tostring(item.name or item.filename) .. ", order=" .. tostring(item.order or "nil") .. ", collapsed=" .. tostring(item.collapsed or "nil"))
    end
  end
  
  if quarto.log.loglevel >= 3 then
    quarto.log.temp("  [NAVBAR SCANNER] Hierarchy contains: " .. #hierarchy.children .. " items")
    quarto.log.temp(hierarchy)
  end

  return hierarchy
end

return scanner 