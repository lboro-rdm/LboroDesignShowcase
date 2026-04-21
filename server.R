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

  
  
  # ── Drill-down state ──────────────────────────────────────────
  drilldown_category <- reactiveVal(NULL)   # NULL = show L1 overview
  
  # Handle L1 bubble click → drill down, or "__back__" → return to L1
  observeEvent(input$bubble_drilldown, {
    val <- input$bubble_drilldown
    if (val == "__back__") {
      drilldown_category(NULL)
      
      # Reset all facet dropdowns
      updateSelectInput(session, "facet_geo",          selected = "All")
      updateSelectInput(session, "facet_nature",        selected = "All")
      updateSelectInput(session, "facet_animals",       selected = "All")
      updateSelectInput(session, "facet_art",           selected = "All")
      updateSelectInput(session, "facet_design",        selected = "All")
      updateSelectInput(session, "facet_architecture",  selected = "All")
      updateSelectInput(session, "facet_fashion",       selected = "All")
      # Add any additional facet inputs here if you expand them later
      
      } else {
      drilldown_category(val)
    }
  })
  
  # Handle L2 bubble click → update the matching facet selectInput
  # Maps taxonomy JSON keys → Shiny selectInput IDs
  observeEvent(input$bubble_term_click, {
    click <- input$bubble_term_click
    
    facet_map <- list(
      geography_places               = "facet_geo",
      landscapes_nature              = "facet_nature",
      animals_insects                = "facet_animals",
      art_movements_styles           = "facet_art",
      design_elements_patterns       = "facet_design",
      architecture_built_environment = "facet_architecture",
      fashion_textiles               = "facet_fashion",
      interiors_products             = "facet_interiors",    # add if you have this input
      materials_processes            = "facet_materials",    # add if you have this input
      culture_heritage               = "facet_culture",      # add if you have this input
      history_time_periods           = "facet_history",      # add if you have this input
      psychology_emotions            = "facet_psychology",   # add if you have this input
      social_issues                  = "facet_social",       # add if you have this input
      futurism_speculative           = "facet_futurism",     # add if you have this input
      sensory_experience             = "facet_sensory"       # add if you have this input
    )
    
    input_id <- facet_map[[click$category]]
    if (!is.null(input_id)) {
      # Toggle: if already selected reset to "All", otherwise apply the term
      new_val <- if (isTRUE(click$selected)) "All" else click$term
      updateSelectInput(session, input_id, selected = new_val)
    }
  })
  
  # ── Bubble diagram output ─────────────────────────────────────
  output$taxonomy_bubbles <- renderD3({
    
    taxonomy    <- fromJSON("gptTaxonomy.json")
    df_filtered <- filtered()           # your existing filtered() reactive
    active_cat  <- drilldown_category() # NULL or a category key string
    
    if (is.null(active_cat)) {
      # ── Level 1: one bubble per top-level category ────────────
      bubble_data <- imap_dfr(taxonomy, function(terms, key) {
        n_articles <- df_filtered %>%
          filter(map_lgl(keywords, ~ any(.x %in% terms))) %>%
          nrow()
        
        tibble(
          level         = 1L,
          label         = key,
          display_label = key %>%
            str_replace_all("_", " ") %>%
            str_to_title(),
          article_count = n_articles,
          category      = key,
          parent        = NA_character_,
          selected      = FALSE
        )
      })
      
    } else {
      # ── Level 2: one bubble per term within the clicked category
      terms <- taxonomy[[active_cat]]
      
      # Which facet input corresponds to this category?
      facet_map <- list(
        geography_places               = "facet_geo",
        landscapes_nature              = "facet_nature",
        animals_insects                = "facet_animals",
        art_movements_styles           = "facet_art",
        design_elements_patterns       = "facet_design",
        architecture_built_environment = "facet_architecture",
        fashion_textiles               = "facet_fashion",
        interiors_products             = "facet_interiors",
        materials_processes            = "facet_materials",
        culture_heritage               = "facet_culture",
        history_time_periods           = "facet_history",
        psychology_emotions            = "facet_psychology",
        social_issues                  = "facet_social",
        futurism_speculative           = "facet_futurism",
        sensory_experience             = "facet_sensory"
      )
      active_input_id  <- facet_map[[active_cat]]
      current_facet_val <- if (!is.null(active_input_id)) input[[active_input_id]] else "All"
      
      bubble_data <- map_dfr(terms, function(term) {
        n_articles <- df_filtered %>%
          filter(map_lgl(keywords, ~ term %in% .x)) %>%
          nrow()
        
        tibble(
          level         = 2L,
          label         = term,
          display_label = term,
          article_count = n_articles,
          category      = active_cat,
          parent        = active_cat,
          selected      = !is.null(current_facet_val) && current_facet_val == term
        )
      })
    }
    
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
