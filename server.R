library(shiny)
library(jsonlite)
library(tidyverse)
library(r2d3)

server <- function(input, output, session) {
  
  taxonomy <- fromJSON("gptTaxonomy.json")
  
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
    authors_list <- sort(unique(df$author))
    
    updateSelectInput(session, "year",
                      choices = c("All", years),
                      selected = "All")
    
    updateSelectInput(session, "author_filter",
                      choices = c("All", authors_list),
                      selected = "All")
    
    # Facet dropdowns
    updateSelectInput(session, "facet_geo",
                      choices = c("All", taxonomy$geography_places),
                      selected = "All")
    
    updateSelectInput(session, "facet_nature",
                      choices = c("All", taxonomy$landscapes_nature),
                      selected = "All")
    
    updateSelectInput(session, "facet_animals",
                      choices = c("All", taxonomy$animals_insects),
                      selected = "All")
    
    updateSelectInput(session, "facet_art",
                      choices = c("All", taxonomy$art_movements_styles),
                      selected = "All")
    
    updateSelectInput(session, "facet_design",
                      choices = c("All", taxonomy$design_elements_patterns),
                      selected = "All")
    
    updateSelectInput(session, "facet_architecture",
                      choices = c("All", taxonomy$architecture_built_environment),
                      selected = "All")
    
    updateSelectInput(session, "facet_fashion",
                      choices = c("All", taxonomy$fashion_textiles),
                      selected = "All")
  })
  
  # ---- Filter reactive ----
  filtered <- reactive({
    
    df <- articles()
    
    if (input$year != "All") {
      df <- df %>% filter(year == input$year)
    }
    
    if (input$author_filter != "All") {
      df <- df %>% filter(author == input$author_filter)
    }
    
    # helper function
    keyword_filter <- function(data, keyword) {
      data %>% filter(map_lgl(keywords, ~ keyword %in% .x))
    }
    
    if (input$facet_geo != "All") {
      df <- keyword_filter(df, input$facet_geo)
    }
    
    if (input$facet_nature != "All") {
      df <- keyword_filter(df, input$facet_nature)
    }
    
    if (input$facet_animals != "All") {
      df <- keyword_filter(df, input$facet_animals)
    }
    
    if (input$facet_art != "All") {
      df <- keyword_filter(df, input$facet_art)
    }
    
    if (input$facet_design != "All") {
      df <- keyword_filter(df, input$facet_design)
    }
    
    if (input$facet_architecture != "All") {
      df <- keyword_filter(df, input$facet_architecture)
    }
    
    if (input$facet_fashion != "All") {
      df <- keyword_filter(df, input$facet_fashion)
    }
    
    df %>% arrange(title)
  })
  

# r2d3 taxonomy bubbles ---------------------------------------------------

  
  
  output$taxonomy_bubbles <- renderD3({
    
    taxonomy   <- fromJSON("gptTaxonomy.json")
    df_filtered <- filtered()   # reactive: already-filtered article data frame
    
    # Map each taxonomy key to its corresponding Shiny facet input
    facet_inputs <- list(
      geography_places               = input$facet_geo,
      landscapes_nature              = input$facet_nature,
      animals_insects                = input$facet_animals,
      art_movements_styles           = input$facet_art,
      design_elements_patterns       = input$facet_design,
      architecture_built_environment = input$facet_architecture,
      fashion_textiles               = input$facet_fashion
    )
    
    # For each taxonomy category, count how many FILTERED articles
    # have at least one keyword belonging to that category
    bubble_data <- imap_dfr(taxonomy, function(terms, key) {
      
      # Count articles where any keyword matches a term in this category
      n_articles <- df_filtered %>%
        filter(map_lgl(keywords, ~ any(.x %in% terms))) %>%
        nrow()
      
      tibble(
        label         = key,
        count         = length(terms),          # number of taxonomy terms
        article_count = n_articles,             # dynamic: filtered article count
        category      = key,
        selected      = !is.null(facet_inputs[[key]]) &&
          facet_inputs[[key]] != "All",
        first_term    = if (length(terms) > 0) terms[[1]] else "All"
      )
    })
    
    r2d3(
      data       = bubble_data,
      script     = file.path(getwd(), "taxonomy_bubbles.js"),
      d3_version = 6
    )
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
