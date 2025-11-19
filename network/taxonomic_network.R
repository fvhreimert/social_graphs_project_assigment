library(jsonlite)
library(dplyr)
library(tidyr)
library(purrr)
library(igraph)
library(ggraph)
library(ggplot2)
library(tidygraph)
library(viridis)
library(paletteer)

# --- 1. DATA LOADING AND PREPARATION ---
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

print(names(filtered_data))

# --- 2. SPECIES COUNTS PER TAXON ---
full_taxonomy <- as_tibble(filtered_data$taxonomy) %>%
  select(Kingdom, Division, Class, Order, Family, Genus) %>%
  mutate(Species = filtered_data$taxonomy$Species)

long_taxonomy <- full_taxonomy %>%
  pivot_longer(
    cols = -Species,
    names_to = "rank",
    values_to = "name"
  ) %>%
  filter(!is.na(name) & name != "")

node_species_counts <- long_taxonomy %>%
  group_by(name) %>%
  summarise(species_count = n_distinct(Species), .groups = "drop")

# --- 3. NETWORK CONSTRUCTION ---
hier <- tibble(
  Division = filtered_data$taxonomy$Division,
  Class = filtered_data$taxonomy$Class,
  Order = filtered_data$taxonomy$Order,
  Family = filtered_data$taxonomy$Family,
  Genus = filtered_data$taxonomy$Genus
)

edge_pairs <- function(x) tibble(
  from = x[-length(x)],
  to = x[-1]
)

edges <- hier %>%
  pmap_dfr(~edge_pairs(c(...))) %>%
  distinct()

g_tidy <- as_tbl_graph(edges, directed = TRUE)

# --- 4. ADD ATTRIBUTES ---
node_ranks <- long_taxonomy %>%
  select(name, rank) %>%
  distinct()

g_tidy <- g_tidy %>%
  activate(nodes) %>%
  left_join(node_ranks, by = "name") %>%
  left_join(node_species_counts, by = "name")

# --- 5. VISUALIZATION ---
lay <- create_layout(g_tidy, layout = "tree", circular = TRUE)
lay$y <- lay$y * 0.4
lay$x <- lay$x * 0.5

p <- ggraph(lay) +
  geom_edge_diagonal(alpha = 0.4) +
  geom_node_point(
    aes(
      color = rank,
      size = species_count,
      alpha = ifelse(rank == "Genus", 0.5, 0.9)
    )
  ) +
  scale_alpha_identity() +
  scale_size_continuous(range = c(0.5, 35), guide = "none") +
  scale_color_paletteer_d("nationalparkcolors::Acadia") +
  geom_node_text(
    aes(
      x = x * 1.07,
      y = y * 1.07,
      filter = rank == "Genus",
      label = sub(" .*", "", name),
      angle = -((-node_angle(x, y) + 90) %% 180) + 90
    ),
    size = 2,
    hjust = "outward"
  ) +
  labs(
    title = "A. Taxonomic Network of Fungi",
    subtitle = "Nodes sized by number of species; labeled at Genus level",
    color = "Taxonomic Rank"
  ) +
  coord_fixed(clip = "off") +
  scale_x_continuous(expand = expansion(mult = 0.15)) +
  scale_y_continuous(expand = expansion(mult = 0.15)) +
  theme_void() +
  theme(
    legend.position = "bottom",                    # legend moved
    legend.direction = "horizontal",
    plot.margin = margin(10, 10, 10, 10)
  )


p

ggsave(
  "/Users/frederikreimert/Library/CloudStorage/OneDrive-DanmarksTekniskeUniversitet/2025E/social_graphs/social_graphs_project_assigment/network/taxonomic_network_by_species_count_with_genus_labels.png",
  plot = p,
  width = 12,
  height = 12,
  dpi = 300
)

# Print number of each taxonomic rank in the filtered dataset
rank_counts <- long_taxonomy %>%
  group_by(rank) %>%
  summarise(count = n_distinct(name), .groups = "drop")
print(rank_counts)
# Print total number of species in the filtered dataset
total_species <- n_distinct(full_taxonomy$Species)
cat("Total number of species in filtered dataset:", total_species, "\n")

names(data)
