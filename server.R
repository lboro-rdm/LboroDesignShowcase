library(shiny)
library(jsonlite)
library(tidyverse)

server <- function(input, output, session) {
  
  # ---- Load and clean data ----
  articles <- reactive({
    df <- fromJSON("data/articles.json", flatten = TRUE)
    
    # Ensure consistent date format and create author column
    df <- df %>%
      mutate(
        publication_date = as.Date(publication_date, format = "%d/%m/%Y"),
        year = format(publication_date, "%Y"),
        # Parse authors JSON and collapse names
        author = map_chr(authors, function(a) {
          # Parse JSON string to list
          authors_list <- jsonlite::fromJSON(a)
          # Combine first + last names
          paste(paste0(authors_list$last_name, ", ", authors_list$first_name), collapse = ", ")
        })
      )
    
    
    # Handle keyword lists that might be in JSON array format or comma-separated
    df <- df %>%
      mutate(
        keywords = map(keywords, function(k) {
          if (is.character(k)) {
            if (str_detect(k, "\\[")) {
              jsonlite::fromJSON(k)
            } else {
              str_split(k, ",\\s*")[[1]]
            }
          } else {
            k
          }
        })
      )
    
    df
  })
  
  # ---- Populate dropdowns ----
  observe({
    df <- articles()
    
    years <- sort(unique(df$year), decreasing = TRUE)
    keywords <- sort(unique(unlist(df$keywords)))
    authors_list <- sort(unique(df$author))
    
    updateSelectInput(session, "year",
                      choices = c("All", years),
                      selected = "All")
    
    updateSelectInput(session, "keyword",
                      choices = c("All", keywords),
                      selected = "All")
    
    updateSelectInput(session, "author_filter",
                      choices = c("All", authors_list),
                      selected = "All")
  })
  
  # ---- Filter reactive ----
  filtered <- reactive({
    df <- articles()
    
    if (input$year != "All") {
      df <- df %>% filter(year == input$year)
    }
    
    if (input$keyword != "All") {
      df <- df %>% filter(map_lgl(keywords, ~ input$keyword %in% .x))
    }
    
    if (input$author_filter != "All") {
      df <- df %>% filter(author == input$author_filter)
    }
    
    df <- df %>% arrange(title)
    
    df
  })
  
  # ---- Display titles in a grid ----
  output$article_grid <- renderUI({
    df <- filtered()
    
    if (nrow(df) == 0) {
      return(tags$p("No matching items found.", class = "text-muted"))
    }
    
    # Bootstrap card grid
    fluidRow(
      lapply(seq_len(nrow(df)), function(i) {
        article <- df[i, ]
        
        column(
          width = 4,
          div(
            class = "card mb-3 shadow-sm p-3",
            style = "height: 100%;",
            tags$h5(article$title),
            tags$p(article$author, class = "text-muted small"),
            if (!is.na(article$doi)) {
              tags$a(href = paste0("https://doi.org/", article$doi),
                     "View DOI", target = "_blank")
            }
          )
        )
      })
    )
  })
}
