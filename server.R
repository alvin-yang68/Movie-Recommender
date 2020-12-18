load("System1.rda") 
load("System2.rda")
load("movieIds.rda")

OPTIMAL_N = 10
CF_PARAMETERS = list(k=500, method="pearson", normalize="center")
library(dplyr)
# mypackages = c("shiny", "shinydashboard", "recommenderlab", "shinyjs", "data.table", "reshape2", "dplyr")   # required packages
# tmp = setdiff(mypackages, rownames(installed.packages()))  # packages need to be installed
# if (length(tmp) > 0) install.packages(tmp)
# lapply(mypackages, require, character.only = TRUE)
# 
# # Install ShinyRatingInput.  This is needed as package is no longer in cran
# if (!("ShinyRatingInput" %in% installed.packages())) {
#   install.packages("devtools")
#   devtools::install_github("stefanwilhelm/ShinyRatingInput")
# }

ratings = read.csv('ratings.dat', 
                   sep = ':',
                   colClasses = c('integer', 'NULL'), 
                   header = FALSE)
colnames(ratings) = c('UserID', 'MovieID', 'Rating', 'Timestamp')

get_user_ratings = function(value_list) {
  dat = data.table(MovieID = sapply(strsplit(names(value_list), "_"), 
                                    function(x) ifelse(length(x) > 1, x[[2]], NA)),
                   Rating = unlist(as.character(value_list)))
  dat = dat[!is.null(Rating) & !is.na(MovieID)]
  dat[Rating == " ", Rating := 0]
  dat[, ':=' (MovieID = as.numeric(MovieID), Rating = as.numeric(Rating))]
  dat = dat[Rating > 0]
}

# System 1

# extract year

get_system1_recommendations_MovieID = function(top_n_to_return, genre) {
  best_movies = get_top_N_movies_data_by_genre(top_n_to_return, genre)
  return (best_movies$MovieID)
}

get_top_N_movies_data_by_genre = function(top_n_to_return, genre) {
  full_movies_data_by_genre = get_full_movies_data_by_genre(genre);
  ret = full_movies_data_by_genre %>%
    mutate(final_rank = as.double(ave_ratings_rank + ave_ratings_timestamp_rank + num_ratings_rank)) %>%
    top_n(top_n_to_return, -((final_rank))) %>%
    select('MovieID', 'Title', 'final_rank', 'ave_ratings_rank', 'ave_ratings_timestamp_rank', 'num_ratings_rank') %>%
    arrange(desc(-(final_rank)))
  
  return(ret);
}

get_full_movies_data_by_genre = function(genre_name) {
  matching_movie_idxs_for_this_genre = genre_matrix[,genre_name] == 1
  movies_for_this_genre = movies[matching_movie_idxs_for_this_genre,]
  ratings_by_movie_data = ratings %>% 
    group_by(MovieID) %>% 
    summarize(
      num_ratings = n(), 
      ave_ratings = round(mean(Rating), dig=4),
      ave_ratings_timestamp = round(mean(Timestamp), dig=4),
    );
  ret = movies_for_this_genre %>%
    left_join(ratings_by_movie_data, by = 'MovieID') %>%
    replace(is.na(.), 0) %>% 
    mutate(ave_ratings_rank = dense_rank(desc(ave_ratings))) %>% 
    mutate(num_ratings_rank = dense_rank(desc(num_ratings))) %>% 
    mutate(ave_ratings_timestamp_rank = dense_rank(desc(ave_ratings_timestamp))) %>%
    arrange(desc(ave_ratings), desc(num_ratings), desc(ave_ratings_timestamp))
  return(ret);
}


# System 2
predict_CF = function(active_user) {
  tmp = matrix(data=NA, 1, length(movieIDs))
  colnames(tmp) = movieIDs
  tmp[1, active_user$MovieID] = active_user$Rating
  r.pred = predict(r.model, as(tmp, "realRatingMatrix"), OPTIMAL_N)
  return(as(r.pred, "list"))
}


# read in data
myurl = "https://liangfgithub.github.io/MovieData/"
movies = readLines(paste0(myurl, 'movies.dat?raw=true'))
movies = strsplit(movies, split = "::", fixed = TRUE, useBytes = TRUE)
movies = matrix(unlist(movies), ncol = 3, byrow = TRUE)
movies = data.frame(movies, stringsAsFactors = FALSE)
colnames(movies) = c('MovieID', 'Title', 'Genres')
movies$MovieID = as.integer(movies$MovieID)
movies$Title = iconv(movies$Title, "latin1", "UTF-8")

# Get unique movie genres for dropdown
unique_genres = c()
for (unsplit_genres in movies$Genres) {
  split_genres = strsplit(unsplit_genres[1], "|", fixed = TRUE)
  # Not sure why split_genres returns a list of list instead of a single list
  for (genresArr in split_genres) {
    for (eachGenre in genresArr) {
      if (!(eachGenre %in% unique_genres)) {
        unique_genres = append(unique_genres, eachGenre)
      } 
    }
  }
}

small_image_url = "https://liangfgithub.github.io/MovieImages/"
movies$image_url = sapply(movies$MovieID, 
                          function(x) paste0(small_image_url, x, '.jpg?raw=true'))

shinyServer(function(input, output, session) {
  # show the books to be rated
  
  output$ratings_book_grid <- renderUI({
    num_rows <- 20
    num_movies <- 6 # movies per row
    
    lapply(1:num_rows, function(i) {
      list(fluidRow(lapply(1:num_movies, function(j) {
        list(box(width = 2,
                 div(style = "text-align:center", img(src = movies$image_url[(i - 1) * num_movies + j], height = 150)),
                 #div(style = "text-align:center; color: #999999; font-size: 80%", books$authors[(i - 1) * num_books + j]),
                 div(style = "text-align:center", strong(movies$Title[(i - 1) * num_movies + j])),
                 div(style = "text-align:center; font-size: 150%; color: #f0ad4e;", ratingInput(paste0("select_", movies$MovieID[(i - 1) * num_movies + j]), label = "", dataStop = 5)))) #00c0ef
      })))
    })
  })
  outputOptions(output, "ratings_book_grid", suspendWhenHidden = FALSE)  
  
  # show genre dropdown
  output$genres_dropdown <- renderUI({
    selectInput("genreDropdown", "Genre:", as.list(unique_genres))
  })
  
  #Hide ratings container
  transition_to_loading_state <- function() {
    useShinyjs()
    jsCode <- "document.querySelector('[data-widget=collapse]').click();"
    runjs(jsCode)
  }
  
  df_genre <- eventReactive(input$btnGenre, {
    withBusyIndicatorServer("btnGenre", {
      transition_to_loading_state()
      value_list = reactiveValuesToList(input)
      selected_genre = value_list$genreDropdown
      top_genre_movies = get_top_N_movies_data_by_genre(OPTIMAL_N, selected_genre)
      user_results = (1:10)/10
      recom_genre_results <- data.table(Rank = 1:10, 
                                  MovieID = top_genre_movies$MovieID, 
                                  Title = top_genre_movies$Title, 
                                  Predicted_rating =  user_results)
    })
  })
  
  # Calculate recommendations when the sbumbutton is clicked
  df <- eventReactive(input$btnRating, {
    withBusyIndicatorServer("btnRating", { # showing the busy indicator
      transition_to_loading_state()
      
      # get the user's rating data
      value_list <- reactiveValuesToList(input)
      user_ratings <- get_user_ratings(value_list)
      ###
      # user_ratings
      # MovieID Rating
      # 1:       3      5
      # 2:       2      4
      # 3:       8      2
      ###
      #TODO:  Currently returning first 10 books as recommendation.  Plug in CF algo here.
      user_results = (1:10)/10
      user_predicted_ids = predict_CF(user_ratings) # 
      user_predicted_ids = lapply(user_predicted_ids, function(x) substring(x,2))
      user_predicted_ids = as.numeric(unlist(user_predicted_ids))
    }) # still busy
    
  }) # clicked on button
  
  output$results_by_genre <- renderUI({
    num_rows <- 2
    num_movies <- 5
    recom_result = df_genre()
    lapply(1:num_rows, function(i) {
      list(fluidRow(lapply(1:num_movies, function(j) {
        movie_idx = i * j
        movie_id = recom_result$MovieID[movie_idx]
        movie_title = recom_result$Title[movie_idx]
        rec_movie = movies[movies$MovieID == movie_id,]
        box(width = 2, status = "success", solidHeader = TRUE, title = paste0("Rank ", (i - 1) * num_movies + j),
            div(style = "text-align:center", 
                a(img(src = rec_movie$image_url, height = 150))
            ),
            div(style="text-align:center; font-size: 100%", 
                strong(movie_title)
            )
            
        )        
      }))) # columns
    }) # rows
  })
  
  # display the recommendations
  output$results <- renderUI({
    num_rows <- 2
    num_movies <- 5
    recom_movie_ids <- df()
    
    lapply(1:num_rows, function(i) {
      list(fluidRow(lapply(1:num_movies, function(j) {
        movie_idx = i * j
        movie_id = recom_movie_ids[movie_idx]
        rec_movie = movies[movies$MovieID == movie_id,]
        box(width = 2, status = "success", solidHeader = TRUE, title = paste0("Rank ", (i - 1) * num_movies + j),
            div(style = "text-align:center", 
                a(img(src = rec_movie$image_url, height = 150))
            ),
            div(style="text-align:center; font-size: 100%", 
                strong(rec_movie$Title)
            )
            
        )         
      }))) # columns
    }) # rows
    
  }) # renderUI function
  
}) # server function