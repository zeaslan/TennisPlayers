# This R script scrapes player information and statistics data from https://www.atptour.com/

# Load required packages
library(rvest)
library(tidyverse)
library(glue)
library(here)
library(lubridate)
library(maps)

# PLAYER INFO 

# Create a function to collect player information
info_importer <- function(url){
  
  # Get the HTML page
  url_contents <- read_html(x = glue("https://www.atptour.com", url))
  
  # Get the player name
  player <- html_elements(url_contents, css = ".player-profile-hero-name div") %>%
    html_text2() %>%
    str_flatten(collapse = " ")
  
  # Get the player's current ranking
  ranking <- html_elements(url_contents, css = "tr:nth-child(1) td:nth-child(3) .stat-value") %>%
    html_text2() %>%
    as.numeric()
  
  # Get the player's birth date
  birthday <- html_elements(url_contents, css = ".table-birthday") %>%
    html_text2() %>%
    str_remove_all("\r") %>%
    str_extract_all("(?<=\\().+?(?=\\))") %>%
    ymd()
  
  # Get the handedness information
  handedness <- html_elements(url_contents, css = "td:nth-child(2) .table-value") %>%
    html_text2() 
  
  if (handedness == "\r Right-Handed, Two-Handed Backhand") {
    handedness <- "Right"
  } else {
    handedness <- "Left"
  }
  
  # Get the player's nationality
  nationality <- html_elements(url_contents, css = "td:nth-child(1) .table-value") %>%
    html_text2() %>%
    str_remove_all("\r") 
    
    ## Keep only the country info
    all_countries <- str_c(unique(world.cities$country.etc), collapse = "|")
    nationality <- sapply(str_extract_all(nationality, all_countries), toString)
  
  # Get the height info of the player  
  height <- html_elements(url_contents, css = ".table-height-cm-wrapper") %>%
    html_text2() %>%
    str_extract_all("(?<=\\().+?(?=\\))") %>%
    str_remove("cm") %>%
    as.numeric()
  
  # Get the year in which the player turned pro
  turned_pro <- html_elements(url_contents, css = "td:nth-child(2) .table-big-value") %>%
    html_text2() %>%
    str_remove_all("\r ") %>%
    as.numeric()
  
  # Get the number of titles the player has
  # This will create warnings ("NAs introduced") as some players' profiles are different 
  titles <- html_elements(url_contents, css = "tr:nth-child(2) td:nth-child(4) .stat-value") %>%
    html_text2() %>%
    str_remove_all("\r") %>%
    as.numeric()
  
    ## Deal with the NAs; extract the correct information for those players
    ## Collect also the prize money information with the same correction
      if (is.na(titles) == TRUE){
          titles <- html_elements(url_contents, css = "td:nth-child(5) .stat-value") %>%
            html_text2() %>%
            str_remove_all("\r") %>%
            as.numeric()
          prize_money <- html_elements(url_contents, css = "td:nth-child(6) .stat-value") %>%
            html_text2() %>%
            str_remove_all("\r") %>%
            str_remove_all(",") %>%
            str_remove_all("\\$") %>%
            as.numeric()
       } else {
          prize_money <- html_elements(url_contents, css = "tr:nth-child(2) td:nth-child(5) .stat-value") %>%
            html_text2() %>%
            str_remove_all("\r") %>%
            str_remove_all(",") %>%
            str_remove_all("\\$") %>%
            as.numeric()
       }
  
  # Create a data frame 
  player_info <- tibble(
    player = player, 
    ranking = ranking,
    birthday = birthday,
    handedness = handedness,
    nationality = nationality,
    height = height,
    turned_pro = turned_pro,
    prize_money = prize_money,
    titles = titles
  )
  
  # Drop the duplicate rows for the players with different profile pages
  player_info <- player_info %>%
    drop_na()
 
   return(player_info)
  
}

# Collect the URLs for each player 
paths_url <- read_html(x = "https://www.atptour.com/en/rankings/singles")

player_links <- html_elements(paths_url, css = ".player-cell-wrapper a:nth-child(1)") %>%
  html_attr('href') 

# Iterate over each player's URL to create a final data frame
player_info <- map_df(player_links, info_importer)

# Manually correct 4 players nationality
player_info <- player_info %>%
  mutate(nationality = case_when(player == "Marin Cilic" ~ "Bosnia Herzegovina",
                                 player == "Daniel Evans" ~ "United Kingdom",
                                 player == "Soonwoo Kwon" ~ "South Korea",
                                 player == "Andy Murray" ~ "United Kingdom",
                                 TRUE ~ nationality))


# PLAYER STATISTICS

# Creating a function that scrapes player statistics
stats_importer <- function(url){

  # Get the HTML page
  url_contents <- read_html(x = glue("https://www.atptour.com", url, "player-stats"))
  
  # Get the player name
  player <- html_elements(url_contents, css = ".player-profile-hero-name div") %>%
    html_text2() %>%
    str_flatten(collapse = " ")

  # Get the statistics table
  stat_table <- html_elements(url_contents, css = "#playerMatchFactsContainer , th, #playerMatchFactsContainer td") %>%
    nth(1) %>%
    html_table(header = FALSE) %>%
    pivot_wider(names_from = X1, values_from = X2) %>%
    select(-c(`Singles Service Record`, `Singles Return Record`))
  
  # Create one final data frame and return results
  player_stats <- tibble(player = player,
                                  stat_table)
  
  return(player_stats)
}

# Collect the URLs for each player 
paths_url <- read_html(x = "https://www.atptour.com/en/rankings/singles")

player_links <- html_elements(paths_url, css = ".player-cell-wrapper a:nth-child(1)") %>%
  html_attr('href') %>%
  str_remove_all("overview")

# Iterate over each player's URL to create a final data frame
player_stats <- map_df(player_links, stats_importer)


# Convert the columns into numeric 
stats_list <- list(player_stats)
stats_1 <- purrr::map_df(stats_list[[1]][c(4:6, 8, 10:13, 15, 17:19)], parse_number)
stats_1 <- stats_1/100 #convert them into percentages
stats_2 <- purrr::map_df(stats_list[[1]][c(2:3, 7, 9, 14, 16)], parse_number)

player_stats <- tibble(player = player_stats$player,
                       stats_1,
                       stats_2)


# FINAL COMBINED DATA

# Merge the two data frames
tennis_players <- left_join(player_info, player_stats, by = "player")

# Save the data frame as a csv file
write_csv(tennis_players, file = here("tennis_players.csv"))