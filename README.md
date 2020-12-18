# Movie Recommender

Link to RShiny App for a movie recommendation based on user's review: 
https://alvin-yang68.shinyapps.io/movie-recommender/

## Description

A movie recommender application was built using RShiny (an R package to build interactive web apps). The web app will recommend the top-10 movies based on the user's input. There are two ways of recommending the movies:

1. System 1: recommendation based on genres. It takes the user's favorite genre as input and recommend the top-10 movies based on the selected genre.
2. System 2: item-based collaborative recommendation system. It asks for user to rate (1-5 stars) as many movies as possible before recommending the top-10 movies based on the ratings they gave.

In both systems, the MovieLens 1M Dataset from https://grouplens.org/datasets/movielens/ was used. The dataset contains about 1 million anonymous ratings of approximately 3,900 movies made by 6,040 MovieLens users who joined MovieLens in 2000.

## System 1

To get recommendations just given a genre, we take the full list of available
movies, and then filter out all the movies that don't fall into the genre
passed in. 

Then we consider 3 factors to rank each movie

1. ave_ratings: This factor intuitively symbolizes the average 
person's opinion on this movie. It is very useful to identify **beloved movies**. 

2. num_ratings: This is important to judge **popular movies**. While a movie
might be very disliked, many people actually might have an increased interest 
in the movie. A (potentially controversial) example might include the modern 
Transformers sequels, which might not have critical acclaim and might even have
low user ratings.
But, because this series are staples of the American social circles, the movies 
are widely watched and remain among the most popular series to this day.

3. ave_ratings_timestamp: This factor is important to judge **trending movies**. 
Many movies might appeal to users as they might be timely. A great example 
of such content might be holiday movies as Christmas movies would likely gain
great popularity in late December but are likely unpopular for the rest of the year.

We then convert each of these factors calculated for each movie and rank
all the movies for each of these factors. We use these three rankings to calculate
a final_ranking which is just a sum of these three factors.

Why do we simply sum these three factors and use the rankings?
Firstly, it is not entirely clear in this system which factors are actually more important
at any given time of year. Maybe certain holidays drive a movies desirability much
more than others? Beyond just the limited data we have to make predictions in system 1,
we use the rankings instead of the values themselves standardize the effect of each 
these factors. Another potential approach might be to normalize each of these columns
to have mean 0 and a variance of 1. 

This method returns the full data combined from the ratings and movies dataset
along with the three calculated factors we mention above.

## System 2

Item-based CF is a model-based approach which produces recommendations based on the relationship between movies inferred from the rating matrix. The assumption behind this approach is that users will prefer movies that are similar to other movies they like.

We used the `recommenderlab` package to train an Item-based CF model after the user inputted their ratings and then use the model to generate the top-10 movies. These are the parameters and assumptions we made:

- We set `normalize="center"` to perform centering for the normalization.
- We set the nearest neighborhood size `k` is set to 500. 
- We use Pearson correlation (centered cosine) as a similarity measure since it treats missing ratings as "average" and can handle "tough raters" and "easy raters" better.
- To make a recommendation based on the model we use the similarities to calculate a weighted sum of the user’s ratings for related items.
- As we are interested in RMSE for the evaluation procedure, we set `type="ratings"` so there will not be any missing values in the `realRatingMatrix` after running the algorithm.
