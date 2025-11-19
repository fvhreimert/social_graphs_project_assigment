library(jsonlite)
library(dplyr)
library(tidyr) # Though not strictly needed for this fix, it's good practice to load it with dplyr

# --- 1. DATA LOADING AND PREPARATION ---
file_path <- "/Users/frederikreimert/Library/CloudStorage/OneDrive-DanmarksTekniskeUniversitet/2025E/social_graphs/social_graphs_project_assigment/data/mushroom_data_merged.json"
data <- fromJSON(file_path)

# Create a single, flat dataframe
flat_data <- as.data.frame(data$taxonomy)
flat_data$views <- data$views

# --- 2. FILTERING ---
# Now filter the new flat_data dataframe
keep <- !(
  is.na(flat_data$Kingdom)  | flat_data$Kingdom  %in% c("", "NA", NA) |
    is.na(flat_data$Division) | flat_data$Division %in% c("", "NA", NA) |
    is.na(flat_data$Class)    | flat_data$Class    %in% c("", "NA", NA) |
    is.na(flat_data$Order)    | flat_data$Order    %in% c("", "NA", NA) |
    is.na(flat_data$Family)   | flat_data$Family   %in% c("", "NA", NA) |
    is.na(flat_data$Genus)    | flat_data$Genus    %in% c("", "NA", NA) |
    is.na(flat_data$Species)  | flat_data$Species  %in% c("", "NA", NA)
)
filtered_flat_data <- flat_data[keep, ]
head(filtered_flat_data)

# Print length of unique(filtered_flat_data$Division

# --- 3. RESHAPE AND SUMMARIZE ---

# We start with the filtered_flat_data from your previous code
long_format_data <- filtered_flat_data %>%
  select(Division, Class, Order, Family, Genus, views) %>%
  pivot_longer(
    cols = -views,
    names_to = "rank",
    values_to = "name"
  ) %>%
  group_by(rank, name) %>%
  summarize(
    avg_views = mean(views, na.rm = TRUE),
    .groups = 'drop'
  )

long_format_data
