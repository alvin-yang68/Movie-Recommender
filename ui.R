## ui.R
library(shiny)
library(shinydashboard)
library(recommenderlab)
library(data.table)
library(ShinyRatingInput)
library(shinyjs)

source('functions/helpers.R')

shinyUI(
    dashboardPage(
          skin = "blue",
          dashboardHeader(title = "Book Recommender"),
          dashboardSidebar(
            sidebarMenu(
              # Setting id makes input$tabs give the tabName of currently-selected tab
              id = "tabs",
              menuItem("By Genre", tabName = "genre", icon = icon("dashboard")),
              menuItem("By Rating", icon = icon("dashboard"), tabName = "rating")
            )
          ),
          dashboardBody(includeCSS("css/movies.css"),
              tabItems(
                tabItem(
                  tabName = "genre",
                  fluidRow(
                    box(width = 12, title = "Step 1: Select Your Favorite Genre", status = "info", solidHeader = TRUE, collapsible = TRUE,
                        div(class = "genreitems",
                            uiOutput('genres_dropdown')
                        )
                    )
                  ),
                  fluidRow(
                    useShinyjs(),
                    box(
                      width = 12, status = "info", solidHeader = TRUE,
                      title = "Step 2: Discover movies you might like",
                      br(),
                      withBusyIndicatorUI(
                        actionButton("btnGenre", "Click here to get your recommendations", class = "btn-warning")
                      ),
                      br(),
                      tableOutput("results_by_genre")
                    )
                  )
                ),
                tabItem(
                  tabName = "rating",
                  fluidRow(
                    box(width = 12, title = "Step 1: Rate as many movies as possible", status = "info", solidHeader = TRUE, collapsible = TRUE,
                        div(class = "rateitems",
                            uiOutput('ratings_book_grid')
                        )
                    )
                  ),
                  fluidRow(
                    useShinyjs(),
                    box(
                      width = 12, status = "info", solidHeader = TRUE,
                      title = "Step 2: Discover movies you might like",
                      br(),
                      withBusyIndicatorUI(
                        actionButton("btnRating", "Click here to get your recommendations", class = "btn-warning")
                      ),
                      br(),
                      tableOutput("results")
                    )
                  )
                )
              )
          )
    )
) 