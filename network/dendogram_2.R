library(jsonlite)
library(dplyr)
library.dynam('tidyr', 'tidyr', '/Library/Frameworks/R.framework/Versions/4.3-x86_64/Resources/library')
library(purrr)
library(igraph)
library(ggraph)
library(ggplot2)
library(tidygraph)

# --- 1. DATA LOADING AND PREPARATION (Unchanged) ---
file_path <- "/Users/frederikreimert/Library/CloudStorage/OneDrive-DanmarksTekniskeUniversitet/2025E/social_graphs/social_graphs_project_assigment/data/mushroom_data_merged.json"
data <- fromJSON(file_path)
tax <- data$taxonomy
keep <- !(
  is.na(tax$Kingdom)  | tax$Kingdom  %in% c("", "NA", NA) |
    is.na(tax$Division) | tax$Division %in% c("", "NA", NA) |
    is.na(tax$Class)    | tax$Class    %in% c("", "NA", NA) |
    is.na(tax$Order)    | tax$Order    %in% c("", "NA", NA) |
    is.na(tax$Family)   | tax$Family   %in% c("", "NA", NA) |
    is.na(tax$Genus)    | tax$Genus    %in% c("", "NA", NA) |
    is.na(tax$Species)  | tax$Species  %in% c("", "NA", NA)
)
filtered_data <- data[keep, ]

# --- 2. NETWORK CONSTRUCTION (Unchanged) ---
tax <- filtered_data$taxonomy
hier <- tibble(
  Kingdom = tax$Kingdom,
  Division = tax$Division,
  Class = tax$Class,
  Order = tax$Order,
  Family = tax$Family,
  Genus = tax$Genus
)
edge_pairs <- function(x) tibble(
  from = x[-length(x)],
  to = x[-1]
)
edges <- hier |>
  pmap_dfr(~edge_pairs(c(...))) |>
  distinct()
g_tidy <- as_tbl_graph(edges, directed = TRUE)

# --- 3. ADD ATTRIBUTES FOR VISUALIZATION (Mostly Unchanged) ---
species_counts <- as_tibble(filtered_data$taxonomy) |>
  group_by(Genus) |>
  summarise(species_count = n_distinct(Species), .groups = 'drop') |>
  rename(name = Genus)

rank_levels <- c("Kingdom", "Division", "Class", "Order", "Family", "Genus")
node_attributes <- hier |>
  pivot_longer(everything(), names_to = "rank", values_to = "name") |>
  distinct(name, .keep_all = TRUE) |>
  mutate(rank = factor(rank, levels = rank_levels))

g_tidy <- g_tidy |>
  activate(nodes) |>
  left_join(node_attributes, by = "name") |>
  left_join(species_counts, by = "name") |>
  mutate(
    species_count = ifelse(is.na(species_count), 0, species_count)
  )

# --- 4. NETWORK VISUALIZATION (Completely Revised) ---

# Get the maximum species count for scaling the bar heights
max_species <- max(g_tidy %>% activate(nodes) %>% as_tibble() %>% pull(species_count))

# Define plot parameters for layout
bar_max_height <- 0.5 # The radial height of the tallest bar
label_padding <- 0.05 # The gap between the bar and the label

set.seed(1)
p <- ggraph(g_tidy, layout = 'dendrogram', circular = TRUE) +
  # Layer 1: The dendrogram itself, with thin black lines
  geom_edge_diagonal(color = "black", width = 0.5) +
  
  # Layer 2: The bars, drawn as thick segments extending from each Genus node
  geom_node_segment(aes(
    filter = rank == 'Genus', # Apply only to Genus nodes
    # x/y are the node's original position, xend/yend are the new endpoint
    xend = x * (1 + (species_count / max_species) * bar_max_height),
    yend = y * (1 + (species_count / max_species) * bar_max_height),
    color = species_count # Map bar color to the species count
  ),
  linewidth = 2.5 # This controls the thickness of the "bar"
  ) +
  
  # Layer 3: The Genus labels, positioned just outside the bars and rotated
  geom_node_text(aes(
    filter = rank == 'Genus', # Apply only to Genus nodes
    label = name,
    # Position labels at the end of the bar + a small padding
    x = x * (1 + (species_count / max_species) * bar_max_height + label_padding),
    y = y * (1 + (species_count / max_species) * bar_max_height + label_padding),
    # Calculate the angle of the label for rotation
    angle = atan2(y, x) * 180 / pi,
    # Adjust justification based on which side of the circle the label is on
    hjust = ifelse(x < 0, 1, 0)
  ),
  size = 2.5,
  repel = FALSE # Must be false to maintain alignment
  ) +
  
  # Set the color scale for the bars (similar to the example)
  scale_color_viridis_c(option = "plasma", name = "# Species") +
  
  # Use coord_fixed() to ensure the plot is circular and not an oval
  coord_fixed() +
  
  # Clean up the theme by removing axes, background, etc.
  theme_void()

print(p)

ggsave(
  "/Users/frederikreimert/Library/CloudStorage/OneDrive-DanmarksTekniskeUniversitet/2025E/social_graphs/social_graphs_project_assigment/network/taxonomic_circular_barplot.png",
  plot = p,
  width = 14,
  height = 14,
  dpi = 300
)