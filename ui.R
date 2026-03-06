library(shiny)

ui <- fluidPage(
  titlePanel("Design Showcase Explorer"),
  
  sidebarPanel(
    selectInput("year", "Select Year:", choices = NULL),
    selectInput("author_filter", "Select Author:", choices = NULL),
    selectInput("facet_geo", "Places", choices = NULL),
    selectInput("facet_nature", "Nature", choices = NULL),
    selectInput("facet_animals", "Animals", choices = NULL),
    selectInput("facet_art", "Art movements", choices = NULL),
    selectInput("facet_design", "Design elements", choices = NULL),
    selectInput("facet_architecture", "Architecture", choices = NULL),
    selectInput("facet_fashion", "Fashion/Textiles", choices = NULL)
  ),
    
    mainPanel(
      uiOutput("article_grid") 
    )
  )
