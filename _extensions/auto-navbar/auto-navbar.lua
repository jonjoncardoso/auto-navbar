-- Auto Navbar Extension
-- Automatically generates navigation bars based on file system structure

-- Key Design Decisions:
-- - Use relative paths throughout for portability
-- - Build-time generation (not runtime JavaScript)
-- - Compatible with existing Quarto sidebar structure
-- - Follow Lua best practices and Quarto extension patterns
-- - Order resolution priority: Special mappings > order-nav metadata > File type > Alphabetical

-- Import function for local modules (OS-agnostic)
-- Based on Stack Overflow solutions for Lua module loading
function import(script)
  local path = PANDOC_SCRIPT_FILE:match("(.*[/\\])")
  if path then
    -- Add the script directory to package.path for OS-agnostic loading
    local script_path = path .. "?.lua"
    package.path = script_path .. ";" .. package.path
    return require(script:gsub("%.lua$", ""))
  else
    -- Fallback: try direct require
    return require(script:gsub("%.lua$", ""))
  end
end

-- Import local modules
local scanner = import("navbar-scanner.lua")
local generator = import("navbar-generator.lua")
local templates = import("navbar-templates.lua")
local utils = import("navbar-utils.lua")

-- Get current document path for matching
local function __get_current_path()
  local current_path = ""

  if quarto.doc.input_file then
    local full_path = tostring(quarto.doc.input_file)
    if quarto.log.loglevel >= 3 then
      quarto.log.temp("Auto Navbar: __get_current_path: quarto.doc.input_file = '" .. tostring(quarto.doc.input_file) .. "'")
      quarto.log.temp("Auto Navbar: __get_current_path: full_path (tostring) = '" .. full_path .. "'")
    end
    current_path = utils.extract_web_path(full_path)
    if quarto.log.loglevel >= 3 then
      quarto.log.temp("Auto Navbar: __get_current_path: after extract_web_path = '" .. current_path .. "'")
    end
  end

  if quarto.log.loglevel >= 3 then
    quarto.log.temp("Auto Navbar: __get_current_path: final current_path = '" .. current_path .. "'")
  end
  return current_path
end

-- Match current path against configuration
local function __match_path_config(current_path, config)
  if quarto.log.loglevel >= 3 then
    quarto.log.temp("Auto Navbar: Path matching: Current path = '" .. tostring(current_path) .. "'")
    quarto.log.temp("Auto Navbar: Path matching: Current path type = " .. type(current_path))
  end

  -- Get all configuration keys
  local config_keys = {}
  for key, _ in pairs(config) do
    if key ~= "_logLevel" then -- Skip the log level flag
      table.insert(config_keys, key)
    end
  end

  if quarto.log.loglevel >= 3 then
    quarto.log.temp("Auto Navbar: Path matching: Config keys to check:")
    for _, key in ipairs(config_keys) do
      quarto.log.temp("Auto Navbar:   - '" .. tostring(key) .. "'")
    end
  end

  -- Try to find a matching configuration
  for _, config_key in ipairs(config_keys) do
    local config_value = config[config_key]
    if quarto.log.loglevel >= 3 then
      quarto.log.temp("Auto Navbar: Path matching: Checking against '" .. tostring(config_key) .. "'")
    end

    -- Check exact match first
    if current_path == config_key then
      quarto.log.info("Auto Navbar: Path matching: EXACT MATCH found!")
      return config_value
    end

    -- Check partial match (config key is a prefix of current path)
    if string.find(current_path, config_key, 1, true) then
      quarto.log.info("Auto Navbar: Path matching: PREFIX MATCH found!")
      return config_value
    end

    if quarto.log.loglevel >= 3 then
      quarto.log.temp("Auto Navbar: Path matching: No match for '" .. tostring(config_key) .. "'")
    end
  end

  if quarto.log.loglevel >= 3 then
    quarto.log.temp("Auto Navbar: Path matching: NO MATCHES FOUND for any config key")
  end
  return nil
end

-- Determine scanning scope based on matched configuration
local function __determine_scope(current_path, matched_config, matched_key)
  -- Use the matched configuration path as the scope
  -- This ensures we scan the correct directory (e.g., /2023/winter-term/)
  -- rather than the specific file path (e.g., /2023/winter-term/index/)
  local scope = matched_key or current_path
  
  -- Normalize the scope to ensure consistent format with leading slash and trailing slash for directories
  if scope then
    scope = utils.normalize_href(scope)
    -- Ensure directories end with trailing slash
    if not scope:match("%.html$") then
      scope = scope .. "/"
    end
  end
  
  if quarto.log.loglevel >= 3 then
    quarto.log.temp("Auto Navbar: __determine_scope: current_path = '" .. tostring(current_path) .. "', matched_key = '" .. tostring(matched_key) .. "', normalized scope = '" .. tostring(scope) .. "'")
  end

  return scope
end

-- Validate auto-navbar configuration structure
local function __validate_config(config)
  -- TODO: I'm not happy with this validation function. It doesn't produce useful feedback to extension users.
  if quarto.log.loglevel >= 3 then
    quarto.log.temp("Auto Navbar: Validation: Starting validation of config")
    quarto.log.temp("Auto Navbar: Validation: Config type = " .. type(config))
  end

  if not config or type(config) ~= "table" then
    quarto.log.error("Auto Navbar: Configuration must be a table")
    return false
  end

  if quarto.log.loglevel >= 3 then
    quarto.log.temp("Auto Navbar: Validation: Config is a table, checking " .. #config .. " entries")
  end

  for path_key, path_config in pairs(config) do
    if quarto.log.loglevel >= 3 then
      quarto.log.temp("Auto Navbar: Validation: Checking key '" ..tostring(path_key) .. "' (type: " .. type(path_config) .. ")")
    end

    -- Skip internal configuration flags
    if path_key == "_logLevel" then
      if quarto.log.loglevel >= 3 then
        quarto.log.temp("Auto Navbar: Validation: Skipping internal flag: " .. path_key)
      end
      goto continue
    end

    -- Validate path key
    if type(path_key) ~= "string" or path_key == "" then
      quarto.log.warning("Auto Navbar: Path key must be a non-empty string, got: " .. tostring(path_key))
      if quarto.log.loglevel >= 3 then
        quarto.log.temp("Auto Navbar: Validation: FAILED at path key validation")
      end
      return false
    end

    -- Validate path config object
    if type(path_config) ~= "table" then
      quarto.log.warning("Auto Navbar: Path configuration must be a table for: " .. path_key)
      if quarto.log.loglevel >= 3 then
        quarto.log.temp("Auto Navbar: Validation: FAILED at path config validation")
      end
      return false
    end

    if quarto.log.loglevel >= 3 then
      quarto.log.temp("Auto Navbar: Validation: Path config is a table, checking fields")
    end

    -- Validate levels field
    if path_config.levels then
      if quarto.log.loglevel >= 3 then
        quarto.log.temp("Auto Navbar: Validation: Found levels field: " .. tostring(path_config.levels) .. " (type: " .. type(path_config.levels) .. ")")
      end

      -- Convert Pandoc objects to Lua values for validation
      local levels_value = path_config.levels
      if type(levels_value) == "table" then
        levels_value = pandoc.utils.stringify(levels_value)
        if quarto.log.loglevel >= 3 then
          quarto.log.temp("Auto Navbar: Validation: Converted levels to string: " .. tostring(levels_value))
        end
      end

      -- Convert string to number if possible
      local levels_number = tonumber(levels_value)
      if not levels_number or levels_number < 1 then
        quarto.log.warning("Auto Navbar: levels must be a positive number for: " ..
        path_key .. ", got: " .. tostring(path_config.levels))
        if quarto.log.loglevel >= 3 then
          quarto.log.temp("Auto Navbar: Validation: FAILED at levels validation")
        end
        return false
      end

      if quarto.log.loglevel >= 3 then
        quarto.log.temp("Auto Navbar: Validation: Levels validation passed: " .. levels_number)
      end
    else
      if quarto.log.loglevel >= 3 then
        quarto.log.temp("Auto Navbar: Validation: No levels field found (optional)")
      end
    end

    -- Validate exclude field
    if path_config.exclude then
      if quarto.log.loglevel >= 3 then
        quarto.log.temp("Auto Navbar: Validation: Found exclude field (type: " .. type(path_config.exclude) .. ")")
      end
      if type(path_config.exclude) ~= "table" then
        quarto.log.warning("Auto Navbar: exclude must be a table for: " .. path_key)
        if quarto.log.loglevel >= 3 then
          quarto.log.temp("Auto Navbar: Validation: FAILED at exclude type validation")
        end
        return false
      end

      if quarto.log.loglevel >= 3 then
        quarto.log.temp("Auto Navbar: Validation: Exclude is a table, checking " .. #path_config.exclude .. " entries")
      end

      -- Validate each exclusion pattern
      for i, pattern in ipairs(path_config.exclude) do
        if quarto.log.loglevel >= 3 then
          quarto.log.temp("Auto Navbar: Validation: Checking exclusion pattern " .. i .. " (type: " .. type(pattern) .. ")")
        end
        if type(pattern) ~= "string" and type(pattern) ~= "table" then
          quarto.log.warning("Auto Navbar: exclude pattern " ..
          i .. " must be a string or Pandoc object for: " .. path_key)
          if quarto.log.loglevel >= 3 then
            quarto.log.temp("Auto Navbar: Validation: FAILED at exclude pattern " .. i .. " type validation")
          end
          return false
        end
        if quarto.log.loglevel >= 3 then
          quarto.log.temp("Auto Navbar: Validation: Exclusion pattern " .. i .. " validation passed")
        end
      end
      if quarto.log.loglevel >= 3 then
        quarto.log.temp("Auto Navbar: Validation: All exclude validation passed")
      end
    else
      if quarto.log.loglevel >= 3 then
        quarto.log.temp("Auto Navbar: Validation: No exclude field found (optional)")
      end
    end

    -- Validate special-mappings field
    if path_config["special-mappings"] then
      if quarto.log.loglevel >= 3 then
        quarto.log.temp("Auto Navbar: Validation: Found special-mappings field (type: " .. type(path_config["special-mappings"]) .. ")")
      end
      if type(path_config["special-mappings"]) ~= "table" then
        quarto.log.warning("Auto Navbar: special-mappings must be a table for: " .. path_key)
        if quarto.log.loglevel >= 3 then
          quarto.log.temp("Auto Navbar: Validation: FAILED at special-mappings type validation")
        end
        return false
      end

      if quarto.log.loglevel >= 3 then
        quarto.log.temp("Auto Navbar: Validation: Special-mappings is a table, checking " .. #path_config["special-mappings"] .. " entries")
      end

      -- Validate each mapping object
      for i, mapping in ipairs(path_config["special-mappings"]) do
        if quarto.log.loglevel >= 3 then
          quarto.log.temp("Auto Navbar: Validation: Checking mapping " .. i .. " (type: " .. type(mapping) .. ")")
        end
        if type(mapping) ~= "table" then
          quarto.log.warning("Auto Navbar: special-mapping " .. i .. " order must be a number for: " .. path_key)
          if quarto.log.loglevel >= 3 then
            quarto.log.temp("Auto Navbar: Validation: FAILED at mapping " .. i .. " type validation")
          end
          return false
        end

        -- Convert Pandoc objects to Lua values for validation
        local path_value = mapping.path
        local title_value = mapping.title
        local order_value = mapping.order

        if type(path_value) == "table" then
          path_value = pandoc.utils.stringify(path_value)
          if quarto.log.loglevel >= 3 then
            quarto.log.temp("Auto Navbar: Validation: Mapping " .. i .. " path converted to: " .. tostring(path_value))
          end
        end

        if type(title_value) == "table" then
          title_value = pandoc.utils.stringify(title_value)
          if quarto.log.loglevel >= 3 then
            quarto.log.temp("Auto Navbar: Validation: Mapping " .. i .. " title converted to: " .. tostring(title_value))
          end
        end

        if order_value and type(order_value) == "table" then
          order_value = pandoc.utils.stringify(order_value)
          if quarto.log.loglevel >= 3 then
            quarto.log.temp("Auto Navbar: Validation: Mapping " .. i .. " order converted to: " .. tostring(order_value))
          end
        end

        if not path_value or type(path_value) ~= "string" then
          quarto.log.warning("Auto Navbar: special-mapping " .. i .. " missing or invalid path for: " .. path_key)
          if quarto.log.loglevel >= 3 then
            quarto.log.temp("Auto Navbar: Validation: FAILED at mapping " .. i .. " path validation")
          end
          return false
        end

        if not title_value or type(title_value) ~= "string" then
          quarto.log.warning("Auto Navbar: special-mapping " .. i .. " missing or invalid title for: " .. path_key)
          if quarto.log.loglevel >= 3 then
            quarto.log.temp("Auto Navbar: Validation: FAILED at mapping " .. i .. " title validation")
          end
          return false
        end

        if order_value and type(order_value) ~= "string" then
          -- Try to convert string to number
          local order_number = tonumber(order_value)
          if not order_number then
            quarto.log.warning("Auto Navbar: special-mapping " .. i .. " order must be a number for: " .. path_key)
            if quarto.log.loglevel >= 3 then
              quarto.log.temp("Auto Navbar: Validation: FAILED at mapping " .. i .. " order validation")
            end
            return false
          end
          if quarto.log.loglevel >= 3 then
            quarto.log.temp("Auto Navbar: Validation: Mapping " .. i .. " order converted to number: " .. order_number)
          end
        end

        -- Validate collapsed field
        local collapsed_value = mapping.collapsed
        if collapsed_value then
          -- quarto.log.temp("Auto Navbar: Validation: Found collapsed field in mapping " .. i .. " (type: " .. type(collapsed_value) .. ")")
          
          if type(collapsed_value) == "table" then
            collapsed_value = pandoc.utils.stringify(collapsed_value)
            -- quarto.log.temp("Auto Navbar: Validation: Mapping " .. i .. " collapsed converted to string: " .. tostring(collapsed_value))
          end
          
          -- Convert string to boolean if possible
          if type(collapsed_value) == "string" then
            if collapsed_value == "true" then
              collapsed_value = true
            elseif collapsed_value == "false" then
              collapsed_value = false
            else
              quarto.log.warning("Auto Navbar: special-mapping " .. i .. " collapsed must be true/false for: " .. path_key .. ", got: " .. tostring(collapsed_value))
              if quarto.log.loglevel >= 3 then
                quarto.log.temp("Auto Navbar: Validation: FAILED at mapping " .. i .. " collapsed validation")
              end
              return false
            end
          elseif type(collapsed_value) ~= "boolean" then
            quarto.log.warning("Auto Navbar: special-mapping " .. i .. " collapsed must be a boolean for: " .. path_key .. ", got: " .. tostring(collapsed_value))
            if quarto.log.loglevel >= 3 then
              quarto.log.temp("Auto Navbar: Validation: FAILED at mapping " .. i .. " collapsed validation")
            end
            return false
          end
          
          -- quarto.log.temp("Auto Navbar: Validation: Mapping " .. i .. " collapsed validation passed: " .. tostring(collapsed_value))
        else
          -- quarto.log.temp("Auto Navbar: Validation: No collapsed field found in mapping " .. i .. " (will use default: false)")
        end

        if quarto.log.loglevel >= 3 then
          quarto.log.temp("Auto Navbar: Validation: Mapping " .. i .. " validation passed")
        end
      end
      if quarto.log.loglevel >= 3 then
        quarto.log.temp("Auto Navbar: Validation: All special-mappings validation passed")
      end
    else
      if quarto.log.loglevel >= 3 then
        quarto.log.temp("Auto Navbar: Validation: No special-mappings field found (optional)")
      end
    end

    if quarto.log.loglevel >= 3 then
      quarto.log.temp("Auto Navbar: Validation: All validation passed for key '" .. path_key .. "'")
    end

    ::continue::
  end

  return true
end

-- Configuration parsing and validation
local function __parse_config(doc)
  if quarto.log.loglevel >= 3 then
    quarto.log.temp("Auto Navbar: Step 1: Got config")
  end
  local config = doc.meta["auto-navbar"]
  quarto.log.info("Auto Navbar: auto-navbar config found: " .. (config and "yes" or "no"))

  if not config then
    if quarto.log.loglevel >= 3 then
      quarto.log.temp("Auto Navbar: Step 1 FAILED: No config found")
    end
    return nil
  end


  if quarto.log.loglevel >= 3 then
    quarto.log.temp("Auto Navbar: Step 2: Validating config")
  end
  -- Validate configuration structure
  if not __validate_config(config) then
    quarto.log.warning("Auto Navbar: Configuration validation failed, skipping auto-navbar generation")
    if quarto.log.loglevel >= 3 then
      quarto.log.temp("Auto Navbar: Step 2 FAILED: Validation failed")
    end
    return nil
  end

  if quarto.log.loglevel >= 3 then
    quarto.log.temp("Auto Navbar: Step 3: Getting current path")
  end
  -- Get current document path
  local current_path = __get_current_path()

  if quarto.log.loglevel >= 3 then
    quarto.log.temp("Auto Navbar: Current path determined: " .. tostring(current_path))
    quarto.log.temp("Auto Navbar: Step 4: Available config keys")
    quarto.log.temp("Auto Navbar: Available config keys:")
  end
  for key, value in pairs(config) do
    if key ~= "_logLevel" then -- Skip the log level flag
      if quarto.log.loglevel >= 3 then
        quarto.log.temp("Auto Navbar:   - " .. tostring(key))
      end
    end
  end

  if quarto.log.loglevel >= 3 then
    quarto.log.temp("Auto Navbar: Step 5: Attempting path match")
  end
  local matched_config = __match_path_config(current_path, config)

  if quarto.log.loglevel >= 3 then
    quarto.log.temp("Auto Navbar: Path matching result: " .. (matched_config and "matched" or "no match"))
  end

  if not matched_config then
    if quarto.log.loglevel >= 3 then
      quarto.log.temp("Auto Navbar: Step 5 FAILED: No path match found")
    end
    return nil
  end

  if quarto.log.loglevel >= 3 then
    quarto.log.temp("Auto Navbar: Step 5 SUCCESS: Path matched")
  end

  -- Find the config key that matched
  local matched_key = nil
  for key, value in pairs(config) do
    if value == matched_config then
      matched_key = key
      break
    end
  end

  -- Determine scanning scope
  local scope = __determine_scope(current_path, matched_config, matched_key)
  
  if quarto.log.loglevel >= 3 then
    quarto.log.temp("Auto Navbar: __parse_config: returning scope = '" .. tostring(scope) .. "'")
  end

  return {
    config = matched_config,
    scope = scope,
    current_path = current_path
  }
end

-- Private function to apply exclusions to files and check special mapping conflicts
local function __apply_exclusions(files, parsed_config)
  if not parsed_config.config.exclude then
    quarto.log.debug("  [AUTO NAVBAR] No exclusions provided")
    return files
  end
  
  quarto.log.debug("  [AUTO NAVBAR] Checking exclusions for " .. #files .. " files")
  
  -- Check if any special mappings reference excluded files
  if parsed_config.config["special-mappings"] then
    for _, mapping in ipairs(parsed_config.config["special-mappings"]) do
      if mapping and mapping.path then
        local mapping_path = pandoc.utils.stringify(mapping.path)
        if mapping_path then
          -- Convert .qmd to .html for comparison
          local converted_mapping_path = mapping_path:gsub("%.qmd$", ".html")
          -- Build full web path for comparison
          local full_mapping_path = parsed_config.scope and (parsed_config.scope .. converted_mapping_path) or converted_mapping_path
          
          -- Check if this special mapping would be excluded
          if scanner.should_exclude(full_mapping_path, parsed_config.config.exclude) then
            quarto.log.warning("  [AUTO NAVBAR] Special mapping for '" .. mapping_path .. "' references a file that will be excluded! This mapping will have no effect.")
          end
        end
      end
    end
  end
  
  local filtered_files = {}
  
  for _, file_info in ipairs(files) do
    if not scanner.should_exclude(file_info.path, parsed_config.config.exclude) then
      table.insert(filtered_files, file_info)
    else
      quarto.log.debug("  [AUTO NAVBAR] Excluded file from final list: " .. file_info.path)
    end
  end
  
  quarto.log.debug("  [AUTO NAVBAR] After exclusions: " .. #filtered_files .. " files remaining")
  return filtered_files
end

-- Private function to apply special mappings to files
local function __apply_special_mappings(files, parsed_config)
  -- TODO: Refactor this to be more efficient and less repetitive.
  if not parsed_config.config["special-mappings"] then
    quarto.log.debug("  [AUTO NAVBAR] No special mappings provided")
    return files, 0, 0
  end
  
  local total_specified = #parsed_config.config["special-mappings"]
  quarto.log.debug("  [AUTO NAVBAR] Applying special mappings to " .. #files .. " files")
  
  -- Build lookup table for O(1) access - now using path-aware matching
  local mapping_lookup = {}
  local folder_mappings = {} -- Store folder mappings separately
  local applied_count = 0 -- Track how many mappings were applied
  local unmatched_mappings = {} -- Track mappings that don't find matches
  
  for _, mapping in ipairs(parsed_config.config["special-mappings"]) do
    if mapping and mapping.path then
      local mapping_path = pandoc.utils.stringify(mapping.path)
      if mapping_path then
        -- Check if this is a folder path (ends with /) or file path
        local is_folder = mapping_path:match("/+$") ~= nil
        if is_folder then
          -- It's a folder path like "/weeks/"
          local folder_name = mapping_path:gsub("^/+", ""):gsub("/+$", "")
          local folder_title = mapping.title and pandoc.utils.stringify(mapping.title) or folder_name
          local folder_order = mapping.order and tonumber(pandoc.utils.stringify(mapping.order)) or nil
          
          -- Extract collapsed state from special mapping
          local folder_collapsed = false  -- Default to collapsed: false (expanded)
          if mapping.collapsed ~= nil then
            if type(mapping.collapsed) == "table" then
              local collapsed_str = pandoc.utils.stringify(mapping.collapsed)
              folder_collapsed = (collapsed_str == "true")
            else
              folder_collapsed = mapping.collapsed
            end
          end
          
          folder_mappings[folder_name] = {
            title = folder_title,
            order = folder_order,
            collapsed = folder_collapsed
          }
          quarto.log.debug("  [AUTO NAVBAR] Found **FOLDER** special mapping: " .. folder_name .. " -> " .. folder_title .. " (order: " .. tostring(folder_order or "nil") .. ", collapsed: " .. tostring(folder_collapsed) .. ")")
        else
          -- It's a file path like "/index.qmd" - now store with full path for path-aware matching
          if quarto.log.loglevel >= 3 then
            quarto.log.temp("Auto Navbar: Before fix - mapping_path = '" .. mapping_path .. "', scope = '" .. parsed_config.scope .. "'")
          end
          
          -- Construct full scope-relative path to prevent scope leakage
          local full_mapping_path = parsed_config.scope .. mapping_path:gsub("^/+", "")
          local normalized_mapping_path = utils.normalize_href(full_mapping_path)
          
          if quarto.log.loglevel >= 3 then
            quarto.log.temp("Auto Navbar: After fix - full_mapping_path = '" .. full_mapping_path .. "', normalized_mapping_path = '" .. normalized_mapping_path .. "'")
          end
          
          mapping_lookup[normalized_mapping_path] = {
            order = mapping.order and tonumber(pandoc.utils.stringify(mapping.order)) or nil
          }
          quarto.log.debug("  [AUTO NAVBAR] Found **FILE** special mapping: " .. normalized_mapping_path .. " -> order " .. tostring(mapping.order or "nil"))
        end
      end
    end
  end
  
  -- Store folder mappings in the scanner module for later use
  scanner.folder_mappings = folder_mappings
  
  -- Apply mappings with path-aware lookup - O(n) instead of O(n²)
  -- Note: Now using full relative paths instead of just filename stems
  for _, file_info in ipairs(files) do
    -- Get the relative path from the scope for comparison
    local relative_path = file_info.relative_path
    if relative_path then
      -- Convert to .qmd extension for comparison with special mappings (since mappings use .qmd paths)
      -- Construct full scope-relative path to match the special mapping keys
      local qmd_path = parsed_config.scope .. relative_path:gsub("%.html$", ".qmd")
      local normalized_qmd_path = utils.normalize_href(qmd_path)
      
      local mapping = mapping_lookup[normalized_qmd_path]
      if mapping and mapping.order then
        file_info.order = mapping.order
        applied_count = applied_count + 1
        quarto.log.debug("  [AUTO NAVBAR] Applied order " .. mapping.order .. " to " .. relative_path .. " (path: " .. normalized_qmd_path .. ")")
      end
      
      -- Apply order from file metadata if no special mapping order exists
      if not file_info.order and file_info.metadata and file_info.metadata.order_nav then
        local metadata_order = tonumber(file_info.metadata.order_nav)
        if metadata_order then
          file_info.order = metadata_order
        end
      end
    end
  end
  
  -- Count folder mappings as "applied" if they contain any files
  for folder_name, folder_data in pairs(folder_mappings) do
    local has_files = false
    for _, file_info in ipairs(files) do
      if file_info.relative_path and file_info.relative_path:find(folder_name .. "/", 1, true) then
        has_files = true
        break
      end
    end
    
    if has_files then
      applied_count = applied_count + 1
      quarto.log.debug("  [AUTO NAVBAR] Applied folder mapping: " .. folder_name .. " (contains files)")
    end
  end
  
  -- Check for unmatched file mappings and warn about them
  for mapping_path, mapping_data in pairs(mapping_lookup) do
    local found = false
    for _, file_info in ipairs(files) do
      if file_info.relative_path then
        -- Construct full scope-relative path to match the special mapping keys
        local qmd_path = parsed_config.scope .. file_info.relative_path:gsub("%.html$", ".qmd")
        local normalized_qmd_path = utils.normalize_href(qmd_path)
        if normalized_qmd_path == mapping_path then
          found = true
          break
        end
      end
    end
    
    if not found then
      table.insert(unmatched_mappings, mapping_path)
    end
  end
  
  -- Check for unmatched folder mappings and warn about them
  for folder_name, _ in pairs(folder_mappings) do
    local found = false
    for _, file_info in ipairs(files) do
      -- Check if any file is in this folder
      if file_info.relative_path and file_info.relative_path:find(folder_name .. "/", 1, true) then
        found = true
        break
      end
    end
    
    if not found then
      table.insert(unmatched_mappings, folder_name .. "/")
    end
  end
  
  -- Log warnings for unmatched mappings
  if #unmatched_mappings > 0 then
    quarto.log.warning("  [AUTO NAVBAR] Found " .. #unmatched_mappings .. " special mappings that don't match any files/folders:")
    for _, unmatched in ipairs(unmatched_mappings) do
      quarto.log.warning("    - " .. unmatched)
    end
  end
  
  return files, applied_count, total_specified
end

-- Private function to debug log special mappings
local function __debug_special_mappings(parsed_config)
  if parsed_config.config["special-mappings"] then
    if quarto.log.loglevel >= 3 then
      quarto.log.temp("Auto Navbar: Special mappings found: " .. #parsed_config.config["special-mappings"])
    end
    for i, mapping in ipairs(parsed_config.config["special-mappings"]) do
      local path_str = mapping.path and pandoc.utils.stringify(mapping.path) or "nil"
      local title_str = mapping.title and pandoc.utils.stringify(mapping.title) or "nil"
      local order_str = mapping.order and pandoc.utils.stringify(mapping.order) or "nil"
      if quarto.log.loglevel >= 3 then
        quarto.log.temp("Auto Navbar: Special mapping " .. i .. ": path=" .. path_str .. ", title=" .. title_str .. ", order=" .. order_str)
      end
    end
  else
    if quarto.log.loglevel >= 3 then
      quarto.log.temp("Auto Navbar: No special mappings found in config")
    end
  end
end

-- Main extension function
function Pandoc(doc)
  -- Parse configuration
  -- Scan directory structure
  -- Apply exclusions
  -- Apply special mappings
  -- Build hierarchy
  -- Debug logging
  -- Generate HTML navbar
  -- Inject into document
  -- TODO: Make sure the quarto.log.info() shows each major step being executed.

  -- Only process HTML documents
  if not quarto.doc.is_format("html") then
    return doc
  end

  -- Parse configuration first to check if we're in scope
  local parsed_config = __parse_config(doc)
  if not parsed_config then
    -- No configuration found means this page is not in scope
    -- Return immediately without any logging or processing
    return doc
  end

  -- We're in scope, so now we can start logging and processing
  quarto.log.info("[AUTO NAVBAR] Extension called for page in scope: " .. parsed_config.scope)

  quarto.log.debug("  [AUTO NAVBAR] STEP 1 starting...")

  -- Now that we have a valid config, set the log level
  local log_level = 1             -- Default level: 1 = info (error, warning, info)
  local config_log_level = "info" -- Default config level

  if doc.meta["auto-navbar"] and doc.meta["auto-navbar"]["_logLevel"] then
    -- Extract the actual string value from the Pandoc object
    config_log_level = pandoc.utils.stringify(doc.meta["auto-navbar"]["_logLevel"])
    -- Convert string log level to numeric value as expected by logging library
    if config_log_level == "error" then
      log_level = -1 -- -1 = error only
    elseif config_log_level == "warning" then
      log_level = 0  -- 0 = error and warning
    elseif config_log_level == "info" then
      log_level = 1  -- 1 = error, warning, and info
    elseif config_log_level == "debug" then
      log_level = 2  -- 2 = error, warning, info, and debug
    elseif config_log_level == "trace" then
      log_level = 3  -- 3 = error, warning, info, debug, and trace
    else
      quarto.log.warning("[AUTO NAVBAR] Invalid _logLevel '" .. config_log_level .. "', using default 'info' (level 1)")
      config_log_level = "info"
      log_level = 1
    end
  end

  -- Set the log level for this extension
  local previous_level = quarto.log.setloglevel(log_level)
  if quarto.log.loglevel >= 3 then
    quarto.log.temp("Auto Navbar: Log level set from " .. tostring(previous_level) .. " to " .. tostring(log_level) .. " (config: " .. config_log_level .. ")")
  end

  quarto.log.info("[AUTO NAVBAR] STEP 1 completed | Found scope:" .. parsed_config.scope)

  quarto.log.debug("  [AUTO NAVBAR] STEP 2 starting...")
  quarto.log.debug("  [AUTO NAVBAR] Current path: " .. parsed_config.current_path)
  if quarto.log.loglevel >= 3 then
    quarto.log.temp("Auto Navbar: Levels: " .. tostring(parsed_config.config.levels) .. " (to be converted to number)")
  end

  -- Scan directory structure
  quarto.log.debug("  [AUTO NAVBAR] Starting directory scan for scope: " .. parsed_config.scope)
  local files = scanner.scan_directory(parsed_config.scope, parsed_config.config.levels, parsed_config.scope)

  local num_found = #files
  quarto.log.info("[AUTO NAVBAR] STEP 2 completed | Scanned " .. num_found .. " files")

  if #files == 0 then
    quarto.log.error("[AUTO NAVBAR] No files found during scanning")
  end

  -- Apply exclusions FIRST - remove excluded files before special mappings
  files = __apply_exclusions(files, parsed_config)
  local num_excluded = num_found - #files
  quarto.log.info("[AUTO NAVBAR] STEP 3 completed | Applied exclusions to " .. num_excluded .. " files")

  -- Apply special mappings order values to files using efficient lookup table
  quarto.log.debug("  [AUTO NAVBAR] STEP 4 starting...")
  local applied_count, total_specified
  files, applied_count, total_specified = __apply_special_mappings(files, parsed_config)
  quarto.log.info("[AUTO NAVBAR] STEP 4 completed | Applied " .. applied_count .. " special mappings out of " .. total_specified .. " specified")

  -- Build hierarchy (exclusions and special mappings now applied)
  quarto.log.debug("  [AUTO NAVBAR] STEP 5 starting...")
  local hierarchy = scanner.build_hierarchy(files, parsed_config.config.levels, parsed_config.scope)
  quarto.log.info("[AUTO NAVBAR] STEP 5 completed | Hierarchy contains: " .. #hierarchy.children .. " items")

  -- Debug special mappings
  __debug_special_mappings(parsed_config)


  quarto.log.debug("  [AUTO NAVBAR] STEP 6 starting...")
  -- Generate HTML navbar
  if quarto.log.loglevel >= 3 then
    quarto.log.temp("Auto Navbar: About to call templates.hierarchy_to_html with hierarchy type: " .. type(hierarchy))
  end
  if type(hierarchy) == "table" then
    if quarto.log.loglevel >= 3 then
      quarto.log.temp("Auto Navbar: Hierarchy keys: " .. table.concat({}, ", "))
      for i, item in ipairs(hierarchy) do
        quarto.log.temp("Auto Navbar: Hierarchy item " .. i .. " type: " .. type(item) .. ", content: " .. tostring(item))
      end
    end
  end

  local navbar_html = templates.hierarchy_to_html(hierarchy, parsed_config.current_path, generator,
    parsed_config.config["special-mappings"], 1, parsed_config.scope)
  if quarto.log.loglevel >= 3 then
    quarto.log.temp("Auto Navbar: HTML generated, length: " .. (navbar_html and #navbar_html or "nil") .. ", content preview: " .. (navbar_html and navbar_html:sub(1, 200) or "nil"))
  end

  -- Wrap in container
  local full_navbar = templates.navbar_container(navbar_html)
  if quarto.log.loglevel >= 3 then
    quarto.log.temp("Auto Navbar: Full navbar created, length: " .. (full_navbar and #full_navbar or "nil"))
  end

  quarto.log.info("[AUTO NAVBAR] STEP 6 completed | Generated navbarHTML: " .. #full_navbar .. " characters")

  -- Save generated HTML to temporary file for inspection
  -- local temp_file_path = "auto-navbar-debug.html"
  -- local file_handle = io.open(temp_file_path, "w")
  -- if file_handle then
  --   file_handle:write(full_navbar)
  --   file_handle:close()
  -- if quarto.log.loglevel >= 3 then
  --   quarto.log.temp("Auto Navbar: Generated HTML saved to: " .. temp_file_path)
  -- end
  -- end

  quarto.log.debug("  [AUTO NAVBAR] STEP 7 starting...")
  -- Inject the navbar into the document using JavaScript
  local navbar_script = [[
<script type="text/javascript">
// Auto Navbar Injection Script
(function() {
  var navbarHTML = `]] .. full_navbar:gsub("`", "\\`") .. [[`;

  // Wait for DOM to be ready
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', injectNavbar);
  } else {
    injectNavbar();
  }

  function injectNavbar() {
    // Find the sidebar element
    var sidebar = document.querySelector('#quarto-sidebar');
    if (sidebar) {
      // Get the current URL
      var currentUrl = window.location.href;
      
      // Dynamic base path detection for any deployment context
      var processedNavbarHTML = navbarHTML;
      
      // Function to detect the base path from current URL
      function getBasePath() {
        var pathname = window.location.pathname;
        var segments = pathname.split('/').filter(function(segment) { return segment.length > 0; });
        return segments.length > 0 ? '/' + segments[0] + '/' : '/';
      }
      
      // Get the current base path and apply it to href attributes that need it
      var basePath = getBasePath();
      if (basePath !== '/') {
        // Smart replacement: only replace href="/" patterns that are root-relative
        // This prevents double-prefixing issues
        var tempDiv = document.createElement('div');
        tempDiv.innerHTML = processedNavbarHTML;
        
        // Find all links and update only the root-relative ones
        var links = tempDiv.querySelectorAll('a[href^="/"]');
        links.forEach(function(link) {
          var href = link.getAttribute('href');
          // Only update if it's a root-relative path and doesn't already have the base path
          if (href.startsWith('/') && !href.startsWith(basePath)) {
            link.setAttribute('href', basePath + href.substring(1));
          }
        });
        
        processedNavbarHTML = tempDiv.innerHTML;
        console.log('Auto Navbar: Applied dynamic base path: ' + basePath);
      } else {
        console.log('Auto Navbar: No base path needed (root deployment)');
      }
      
      // Replace the entire sidebar with our processed navbar
      sidebar.outerHTML = processedNavbarHTML;
      console.log('Auto Navbar: Navbar injected successfully');
    } else {
      console.warn('Auto Navbar: Sidebar element not found');
    }
  }
})();
</script>
]]

  -- Add the script to the document
  table.insert(doc.blocks, pandoc.RawBlock("html", navbar_script))

  quarto.log.info("[AUTO NAVBAR] STEP 7 completed | Navbar injected into document via JavaScript")
  return doc
end
