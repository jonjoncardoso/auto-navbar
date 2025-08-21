-- Auto Navbar Utils
-- Reusable utility functions for the auto-navbar extension

local utils = {}

-- Normalise a filesystem path using Pandoc facilities
function utils.fs_normalize(path)
  if not path then return nil end
  return pandoc.path.normalize(tostring(path))
end

-- Join filesystem path segments and normalise
function utils.fs_join(...)
  local parts = { ... }
  return utils.fs_normalize(pandoc.path.join(parts))
end

-- Make path relative to base using Pandoc facilities
function utils.fs_make_relative(path, base)
  if not path or not base then return path end
  return pandoc.path.make_relative(path, base)
end

-- Detect if a path is a file or directory
-- Uses Pandoc's path utilities for OS-agnostic behavior
function utils.is_file_or_directory(path)
  if not path then return nil end
  
  local normalized_path = utils.fs_normalize(path)
  if not normalized_path then return nil end
  
  -- If not a file, check if it's a directory by trying to list its contents
  local ok, items = pcall(pandoc.system.list_directory, normalized_path)
  if ok and items then
    return "directory"
  end

  -- Try to open as file first
  local file_handle = io.open(normalized_path, "r")
  if file_handle then
    file_handle:close()
    return "file"
  end
  
  -- If neither file nor directory, return nil (path doesn't exist)
  return nil
end

-- Convert file system path to web path using Quarto's project structure
function utils.extract_web_path(fs_path)
  if not fs_path then return "/" end

  if quarto.log.loglevel >= 3 then
    quarto.log.temp("Auto Navbar: extract_web_path: Input fs_path = '" .. tostring(fs_path) .. "'")
  end

  -- Normalise FS paths
  local normalized_path = utils.fs_normalize(fs_path) or fs_path
  if quarto.log.loglevel >= 3 then
    quarto.log.temp("Auto Navbar: extract_web_path: normalized_path = '" .. tostring(normalized_path) .. "'")
  end
  
  local project_dir = quarto.project.directory and tostring(quarto.project.directory) or nil
  if quarto.log.loglevel >= 3 then
    quarto.log.temp("Auto Navbar: extract_web_path: project_dir = '" .. tostring(project_dir) .. "'")
  end

  if project_dir then
    local normalized_project_dir = utils.fs_normalize(project_dir) or project_dir
    if quarto.log.loglevel >= 3 then
      quarto.log.temp("Auto Navbar: extract_web_path: normalized_project_dir = '" .. tostring(normalized_project_dir) .. "'")
    end
    
    local relative_path = pandoc.path.make_relative(normalized_path, normalized_project_dir)
    if quarto.log.loglevel >= 3 then
      quarto.log.temp("Auto Navbar: extract_web_path: relative_path = '" .. tostring(relative_path) .. "'")
    end

    -- Determine if this is a file or directory
    local path_type = utils.is_file_or_directory(normalized_path)
    if quarto.log.loglevel >= 3 then
      quarto.log.temp("Auto Navbar: extract_web_path: path_type = '" .. tostring(path_type) .. "'")
    end

    -- Ensure forward slashes for web paths
    local web_relative = tostring(relative_path):gsub("\\", "/")
    if quarto.log.loglevel >= 3 then
      quarto.log.temp("Auto Navbar: extract_web_path: web_relative = '" .. web_relative .. "'")
    end
    
    if path_type == "file" then
      -- For files, convert .qmd to .html and don't add trailing slash
      local stem, ext = pandoc.path.split_extension(web_relative)
      if quarto.log.loglevel >= 3 then
        quarto.log.temp("Auto Navbar: extract_web_path: file detected, stem = '" .. tostring(stem) .. "', ext = '" .. tostring(ext) .. "'")
      end
      
      if stem and stem ~= "" then
        local result = utils.normalize_href("/" .. stem .. ".html")
        if quarto.log.loglevel >= 3 then
          quarto.log.temp("Auto Navbar: extract_web_path: file returning = '" .. result .. "'")
        end
        return result
      else
        if quarto.log.loglevel >= 3 then
          quarto.log.temp("Auto Navbar: extract_web_path: file returning '/' (empty stem)")
        end
        return "/"
      end
    elseif path_type == "directory" then
      -- For directories, add trailing slash
      local result = utils.normalize_href("/" .. web_relative .. "/")
      if quarto.log.loglevel >= 3 then
        quarto.log.temp("Auto Navbar: extract_web_path: directory returning = '" .. result .. "'")
      end
      return result
    else
      -- Fallback: treat as file if we can't determine type
      local stem, ext = pandoc.path.split_extension(web_relative)
      if quarto.log.loglevel >= 3 then
        quarto.log.temp("Auto Navbar: extract_web_path: fallback, stem = '" .. tostring(stem) .. "', ext = '" .. tostring(ext) .. "'")
      end
      
      if stem and stem ~= "" then
        local result = utils.normalize_href("/" .. stem .. "/")
        if quarto.log.loglevel >= 3 then
          quarto.log.temp("Auto Navbar: extract_web_path: fallback returning = '" .. result .. "'")
        end
        return result
      else
        if quarto.log.loglevel >= 3 then
          quarto.log.temp("Auto Navbar: extract_web_path: fallback returning '/' (empty stem)")
        end
        return "/"
      end
    end
  else
    if quarto.log.loglevel >= 3 then
      quarto.log.temp("Auto Navbar: extract_web_path: returning '/' (no project_dir)")
    end
    return "/"
  end
end

-- Convert web path to file system path (relative to project root), normalised
function utils.web_path_to_fs_path(web_path)
  if not web_path then return nil end
  
  if quarto.log.loglevel >= 3 then
    quarto.log.temp("Auto Navbar: web_path_to_fs_path: Input web_path = '" .. tostring(web_path) .. "'")
  end
  
  -- Preserve trailing slash for directories, but clean up multiple slashes
  local clean = tostring(web_path):gsub("^/+", ""):gsub("//+", "/")
  
  -- Check if input had trailing slash (indicating directory)
  local had_trailing_slash = tostring(web_path):match("/+$") ~= nil
  if quarto.log.loglevel >= 3 then
    quarto.log.temp("Auto Navbar: web_path_to_fs_path: had_trailing_slash = " .. tostring(had_trailing_slash))
  end
  
  if had_trailing_slash then
    -- Ensure single trailing slash for directories
    clean = clean:gsub("/+$", "") .. "/"
  end
  
  if quarto.log.loglevel >= 3 then
    quarto.log.temp("Auto Navbar: web_path_to_fs_path: clean = '" .. clean .. "'")
  end
  
  -- Let pandoc.path.normalize handle cross-platform path conversion
  local result = pandoc.path.normalize(clean)
  if quarto.log.loglevel >= 3 then
    quarto.log.temp("Auto Navbar: web_path_to_fs_path: returning = '" .. result .. "'")
  end
  
  return result
end

-- Normalise web hrefs for consistent comparison and output
function utils.normalize_href(href)
  if not href or href == "" then return "/" end
  local s = tostring(href)
  -- Ensure forward slashes and collapse duplicates
  s = s:gsub("//+", "/")
  -- Ensure leading slash
  if not s:match("^/") then
    s = "/" .. s
  end
  -- Remove trailing slash for .html files only
  if s:match("%.html/?$") then
    s = s:gsub("/+$", "")
  end
  return s
end

-- Produce a stable compare key for active-state checks
-- Rules:
-- - Normalise slashes and leading slash
-- - If path ends with '/', treat it as '/index.html'
-- - If path ends with '.html', keep it
function utils.normalized_compare_key(path)
  local s = utils.normalize_href(path or "/")
  -- if s:match("/$") then
  --   -- map directory to index.html
  --   if s == "/" then
  --     return "/index.html"
  --   else
  --     return s:gsub("/$", "/index.html")
  --   end
  -- end
  return s
end

return utils 