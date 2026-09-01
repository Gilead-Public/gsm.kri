# Cache helper functions for test data
# 
# This file provides caching functionality to speed up test data generation in gsm.kri.
# It caches the mapped_data and mapping_output objects to avoid re-running expensive
# workflow pipelines on every test load.
#
# Key features:
# - Uses tools::R_user_dir("gsm", "cache") for cross-platform cache storage
# - Checks modification times of YAML workflow files to determine if cache is outdated
# - Provides functions to clear cache or force refresh
# - Reduces test load times significantly (especially on slower systems)
#
# Cache files created:
# - mapped_data.rds: Cached result of workr::RunWorkflows(mappings_wf, lData)
# - mappings_wf.rds: Cached mappings_wf object
# - mapping_output.rds: Cached mapping output names
#
# Usage:
# - mapped_data <- get_cached_mapped_data(lData, mappings_wf)
# - mapping_output <- get_cached_mapping_output(mappings_wf)  
# - clear_cache() # to remove all cache files

# Set up cache directory using R_user_dir()
get_cache_dir <- function(cache_subdir = NULL) {
  base_cache_dir <- tools::R_user_dir("gsm", "cache")
  
  if (!is.null(cache_subdir)) {
    cache_dir <- file.path(base_cache_dir, cache_subdir)
  } else {
    cache_dir <- base_cache_dir
  }
  
  if (!dir.exists(cache_dir)) {
    dir.create(cache_dir, recursive = TRUE)
  }
  return(cache_dir)
}

# Get list of workflow files and their modification times
get_workflow_mtime <- function(workflow_paths) {
  workflow_files <- unlist(lapply(workflow_paths, function(path) {
    list.files(path, pattern = "\\.yaml$", full.names = TRUE, recursive = TRUE)
  }))
  
  if (length(workflow_files) == 0) {
    return(Sys.time())
  }
  
  max(file.info(workflow_files)$mtime, na.rm = TRUE)
}

# Check if cached data is outdated
is_cache_outdated <- function(cache_file, source_mtime) {
  if (!file.exists(cache_file)) {
    return(TRUE)
  }
  
  cache_mtime <- file.info(cache_file)$mtime
  return(cache_mtime < source_mtime)
}

# Get or create cached mapped data
get_cached_mapped_data <- function(lData, mappings_wf, force_refresh = FALSE, cache_dir = NULL) {
  if (is.null(cache_dir)) {
    cache_dir <- get_cache_dir()
  }
  mapped_data_cache <- file.path(cache_dir, "mapped_data.rds")
  mappings_wf_cache <- file.path(cache_dir, "mappings_wf.rds")
  
  # Get modification time of relevant workflow files
  workflow_paths <- c(
    system.file("workflow/1_mappings", package = "gsm.mapping"),
    system.file("workflow", package = "gsm.core")
  )
  
  source_mtime <- get_workflow_mtime(workflow_paths)
  
  # Check if cache is outdated or force refresh is requested
  if (force_refresh || 
      is_cache_outdated(mapped_data_cache, source_mtime) ||
      is_cache_outdated(mappings_wf_cache, source_mtime)) {
    
    # Generate fresh mapped data
    mapped_data <- workr::RunWorkflows(mappings_wf, lData)
    
    # Save to cache
    saveRDS(mapped_data, mapped_data_cache)
    saveRDS(mappings_wf, mappings_wf_cache)
    
    return(mapped_data)
  } else {
    # Load from cache
    return(readRDS(mapped_data_cache))
  }
}

# Get mapping output names
get_cached_mapping_output <- function(mappings_wf, force_refresh = FALSE, cache_dir = NULL) {
  if (is.null(cache_dir)) {
    cache_dir <- get_cache_dir()
  }
  mapping_output_cache <- file.path(cache_dir, "mapping_output.rds")
  
  # Get modification time of relevant workflow files
  workflow_paths <- c(
    system.file("workflow/1_mappings", package = "gsm.mapping"),
    system.file("workflow", package = "gsm.core")
  )
  
  source_mtime <- get_workflow_mtime(workflow_paths)
  
  # Check if cache is outdated or force refresh is requested
  if (force_refresh || is_cache_outdated(mapping_output_cache, source_mtime)) {
    
    # Generate mapping output
    mapping_output <- map(mappings_wf, ~ .x$steps[[1]]$output) %>% unlist()
    
    # Save to cache
    saveRDS(mapping_output, mapping_output_cache)
    
    return(mapping_output)
  } else {
    # Load from cache
    return(readRDS(mapping_output_cache))
  }
}

# Clear cache files
clear_cache <- function(cache_dir = NULL) {
  if (is.null(cache_dir)) {
    cache_dir <- get_cache_dir()
  }
  cache_files <- list.files(cache_dir, pattern = "(mapped_data|mappings_wf|mapping_output)\\.rds$", full.names = TRUE)
  if (length(cache_files) > 0) {
    file.remove(cache_files)
  }
  message("Cache cleared: ", length(cache_files), " files removed")
}