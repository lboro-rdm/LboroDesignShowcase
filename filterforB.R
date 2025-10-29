library(tidyverse)
library(jsonlite)

# ---- PARAMETERS ----
input_file <- "20251029.csv"     # path to your input CSV
output_file <- "filtered.csv" # path for output
keywords_file <- "unique_keywords.csv"
target_id <- 3426125

# ---- PROCESS ----
df <- read.csv(input_file) %>%
  filter(account_id == target_id)

# ---- OUTPUT ----
write.csv(df, output_file, row.names = FALSE)

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
