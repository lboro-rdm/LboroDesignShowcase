library(shiny)

ui <- fluidPage(
  titlePanel("Articles Explorer"),
  
  sidebarPanel(
    selectInput("year", "Select Year:", choices = NULL),
    selectInput("keyword", "Select Keyword:", choices = NULL),
    selectInput("author_filter", "Select Author:", choices = NULL)
  ),
    
    mainPanel(
      uiOutput("article_grid") 
    )
  )
