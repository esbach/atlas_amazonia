# Script to simplify polygons.geojson
# This reduces the file size by simplifying the polygon geometries

library(sf)
library(jsonlite)

# Read the GeoJSON file
cat("Reading polygons.geojson...\n")
polygons <- st_read("public/polygons.geojson", quiet = TRUE)

cat(sprintf("Original file: %d features\n", nrow(polygons)))
cat(sprintf("Original size: %.2f MB\n", file.info("public/polygons.geojson")$size / 1024 / 1024))

# Simplify the geometries
# IMPORTANT: st_simplify works much better with projected coordinates (meters)
# than with geographic coordinates (degrees). We'll transform to a projected
# CRS, simplify, then transform back.

# Check current CRS
cat(sprintf("Current CRS: %s\n", st_crs(polygons)$input))

# Tolerance in METERS (for projected coordinates)
# Tolerance guide (in meters):
# - 10:    Very light simplification (~10m) - preserves fine detail
# - 50:    Light simplification (~50m) - good for most purposes
# - 100:   Moderate simplification (~100m)
# - 500:   Heavy simplification (~500m) - significant reduction
# - 1000:  Very aggressive simplification (~1km) - may distort shapes
# - 10000: Extreme simplification (~10km) - maximum size reduction

tolerance_meters <- 1000  # Adjust this value as needed (in meters)

cat(sprintf("Simplifying with tolerance = %d meters...\n", tolerance_meters))

# Use a projected CRS suitable for South America
# EPSG:3857 (Web Mercator) is simple and widely used, though not equal-area
# For better area preservation, could use EPSG:102033 (South America Albers)
# or find a UTM zone that covers the data extent

# Detect an appropriate UTM zone based on data extent, or use Web Mercator
bbox <- st_bbox(polygons)
center_lon <- mean(c(bbox["xmin"], bbox["xmax"]))
utm_zone <- floor((center_lon + 180) / 6) + 1

# Use Web Mercator (EPSG:3857) for simplicity - works globally
# Or use South America Albers Equal Area (EPSG:102033) for better area preservation
target_crs <- "EPSG:3857"  # Web Mercator

cat(sprintf("Transforming to %s for simplification...\n", target_crs))
polygons_projected <- st_transform(polygons, crs = target_crs)

# Simplify in projected coordinates
cat("Applying simplification...\n")
polygons_simplified_projected <- st_simplify(
  polygons_projected, 
  dTolerance = tolerance_meters, 
  preserveTopology = TRUE
)

# Transform back to original CRS
cat("Transforming back to original CRS...\n")
polygons_simplified <- st_transform(polygons_simplified_projected, crs = st_crs(polygons))

# Verify simplification worked by comparing vertex counts
original_coords <- sum(sapply(st_geometry(polygons), function(x) nrow(st_coordinates(x))))
simplified_coords <- sum(sapply(st_geometry(polygons_simplified), function(x) nrow(st_coordinates(x))))
reduction_pct <- (1 - simplified_coords / original_coords) * 100

cat(sprintf("Vertex reduction: %.0f -> %.0f (%.1f%% reduction)\n", 
            original_coords, simplified_coords, reduction_pct))

# Write the simplified version
# IMPORTANT: Control coordinate precision to prevent file size increase
# 
# Why files can get bigger with small tolerance:
# 1. Very small tolerance (0.0001) removes few vertices
# 2. st_write may use more decimal places than the original file
# 3. The preserveTopology flag may add vertices to maintain relationships
#
# Solution: Round coordinates AND use appropriate tolerance

output_file <- "public/polygons_simplified.geojson"

# Method: Convert to WKT, round coordinates in text, convert back
# This is simpler than manually reconstructing geometries
cat("Reducing coordinate precision...\n")

# Function to round coordinates by converting through WKT
round_sf_coords <- function(sf_obj, digits = 6) {
  # Convert to WKT (Well-Known Text) format
  wkt_strings <- st_as_text(st_geometry(sf_obj))
  
  # Round coordinates in WKT strings using regex
  # Pattern matches decimal numbers in coordinate pairs
  wkt_rounded <- gsub(
    sprintf("(-?\\d+\\.\\d{%d})\\d+", digits), 
    "\\1", 
    wkt_strings
  )
  
  # Convert back to sf geometries
  st_set_geometry(sf_obj, st_as_sfc(wkt_rounded, crs = st_crs(sf_obj)))
}

# Round to 6 decimal places (≈ 0.1m precision for lat/lon)
# You can adjust this: lower = smaller file, less precision
coord_precision <- 6
polygons_simplified_rounded <- round_sf_coords(polygons_simplified, digits = coord_precision)

# Write the file
# st_write will respect the rounded coordinates
st_write(polygons_simplified_rounded, output_file, delete_dsn = TRUE, quiet = TRUE)

cat(sprintf("Simplified file: %d features\n", nrow(polygons_simplified)))
cat(sprintf("New size: %.2f MB\n", file.info(output_file)$size / 1024 / 1024))
cat(sprintf("Reduction: %.1f%%\n", (1 - file.info(output_file)$size / file.info("public/polygons.geojson")$size) * 100))
cat(sprintf("Saved to: %s\n", output_file))

# Optional: Test multiple tolerance values to find the best balance
# Uncomment the section below to automatically test multiple tolerance values

if (FALSE) {  # Set to TRUE to enable multi-tolerance testing
  cat("\n=== Testing multiple tolerance values (in meters) ===\n")
  tolerance_values <- c(50, 100, 500, 1000, 5000, 10000)  # In meters
  
  # Transform once for all tests
  polygons_proj_test <- st_transform(polygons, crs = target_crs)
  
  for (tol_m in tolerance_values) {
    cat(sprintf("\nTesting tolerance = %d meters...\n", tol_m))
    
    # Simplify in projected coordinates
    test_simplified_proj <- st_simplify(polygons_proj_test, dTolerance = tol_m, preserveTopology = TRUE)
    test_simplified <- st_transform(test_simplified_proj, crs = st_crs(polygons))
    test_simplified_rounded <- round_sf_coords(test_simplified, digits = coord_precision)
    
    test_file <- sprintf("public/polygons_tol_%dm.geojson", tol_m)
    st_write(test_simplified_rounded, test_file, delete_dsn = TRUE, quiet = TRUE)
    
    original_size <- file.info("public/polygons.geojson")$size / 1024 / 1024
    new_size <- file.info(test_file)$size / 1024 / 1024
    reduction <- (1 - new_size / original_size) * 100
    
    # Count vertices for this tolerance
    test_coords <- sum(sapply(st_geometry(test_simplified), function(x) nrow(st_coordinates(x))))
    vertex_reduction <- (1 - test_coords / original_coords) * 100
    
    cat(sprintf("  File: %s\n", test_file))
    cat(sprintf("  Size: %.2f MB (%.1f%% file size reduction)\n", new_size, reduction))
    cat(sprintf("  Vertices: %.0f (%.1f%% vertex reduction)\n", test_coords, vertex_reduction))
  }
}

cat("\nDone! You can now use polygons_simplified.geojson in your app.\n")
cat("Update App.vue to load 'polygons_simplified.geojson' instead of 'polygons.geojson'\n")

