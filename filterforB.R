library(tidyverse)
library(jsonlite)

# ---- PARAMETERS ----
input_file <- "20251031.csv"     # path to your input CSV
output_public <- "1288_public.csv" # path for output
output_draft <- "78_private.csv"
keywords_file <- paste0("unique_keywords_", Sys.Date(), ".csv")
target_id <- 3426125

# ---- PROCESS ----
df <- read.csv(input_file) %>%
  filter(account_id == target_id)

# ---- SPLIT BY STATUS ----
df_public <- df %>% filter(status == "public")
df_draft  <- df %>% filter(status == "draft")

# ---- OUTPUT ----
write.csv(df_public, output_public, row.names = FALSE)
write.csv(df_draft, output_draft, row.names = FALSE)

all_keywords <- df %>%
  mutate(
    keywords = map(keywords, ~ {
      # Ensure it's valid JSON-like text
      json_text <- str_replace_all(.x, "'", "\"")
      tryCatch(fromJSON(json_text), error = function(e) NULL)
    })
  ) %>%
  pull(keywords) %>%
  flatten_chr() %>%
  unique() %>%
  sort()

write_csv(tibble(keyword = all_keywords), keywords_file)

### WRITE TO JSON FOR SHINY ###

dir.create("data", showWarnings = FALSE)

# Example: keep only what you need
df_subset <- df_public %>%
  select(article_id, title, authors, description, doi, keywords, publication_date)

# Write to JSON (pretty formatting helps with version control diffs)
write_json(df_subset, "data/articles.json", pretty = TRUE, auto_unbox = TRUE)
