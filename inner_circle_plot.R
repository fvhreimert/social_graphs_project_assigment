library(jsonlite)
library(dplyr)
library(tidyr)
library(ggplot2)
library(viridis)
library(igraph)
library(ggraph)

# ------------------------------------------------------------
# 1. Load and clean data
# ------------------------------------------------------------

file_path <- "/Users/frederikreimert/Library/CloudStorage/OneDrive-DanmarksTekniskeUniversitet/2025E/social_graphs/social_graphs_project_assigment/data/mushroom_data_merged.json"
data <- fromJSON(file_path)

rank_order <- c("Kingdom", "Division", "Class", "Order", "Family", "Genus", "Species")

filtered_data <- data %>%
  filter(
    !is.na(taxonomy$Kingdom),
    !is.na(taxonomy$Division),
    !is.na(taxonomy$Class),
    !is.na(taxonomy$Order),
    !is.na(taxonomy$Family),
    !is.na(taxonomy$Genus),
    !is.na(taxonomy$Species),
    taxonomy$Kingdom  != "",
    taxonomy$Division != "",
    taxonomy$Class    != "",
    taxonomy$Order    != "",
    taxonomy$Family   != "",
    taxonomy$Genus    != "",
    taxonomy$Species  != ""
  )

# ------------------------------------------------------------
# 2. Long taxonomy with unique node IDs
# ------------------------------------------------------------

tax_long <- filtered_data %>%
  select(views_all_time, taxonomy) %>%
  unnest_wider(taxonomy) %>%
  pivot_longer(
    cols = all_of(rank_order),
    names_to = "rank",
    values_to = "taxon"
  ) %>%
  mutate(
    rank = factor(rank, levels = rank_order),
    node_id = paste(rank, taxon, sep = "::")
  )

# ------------------------------------------------------------
# 3. Build vertices using node_id as igraph vertex name
# ------------------------------------------------------------

vertices <- tax_long %>%
  group_by(node_id, rank) %>%
  summarise(
    taxon = first(taxon),
    value = sum(views_all_time),
    .groups = "drop"
  ) %>%
  rename(name = node_id)    # critical: igraph vertex ID

# ------------------------------------------------------------
# 4. Build edges using node_id only
# ------------------------------------------------------------
test_vertices <- tax_long %>%
  group_by(node_id, rank) %>%
  summarise(
    taxon = first(taxon),
    value = sum(views_all_time),
    .groups = "drop"
  ) %>%
  rename(name = node_id)

head(test_vertices, 10)
table(test_vertices$rank)

edges <- filtered_data$taxonomy %>%
  select(all_of(rank_order)) %>%
  mutate(row_id = row_number()) %>%
  pivot_longer(
    cols = -row_id,
    names_to = "rank",
    values_to = "taxon"
  ) %>%
  mutate(rank = factor(rank, levels = rank_order)) %>%
  arrange(row_id, rank) %>%
  mutate(
    node_id      = paste(rank, taxon, sep = "::"),
    next_node_id = lead(node_id)
  ) %>%
  filter(!is.na(next_node_id)) %>%
  select(from = node_id, to = next_node_id) %>%
  distinct()

# ------------------------------------------------------------
# 5. Build graph
# ------------------------------------------------------------

g <- graph_from_data_frame(edges, vertices = vertices, directed = TRUE)

# ------------------------------------------------------------
# 6. Ensure a single root exists
# ------------------------------------------------------------

# ------------------------------------------------------------
# 7. Plot circlepacking
# ------------------------------------------------------------

ggraph(g, layout = "circlepack", weight = value, root = root) +
  geom_node_circle(aes(fill = rank, color = rank)) +
  scale_fill_viridis_d() +
  scale_color_viridis_d() +
  theme_void() +
  theme(legend.position = "right")

