# Tennis Players 

### Overview

The finalized report [here](./part2_tennisplayers.md) uses data that is scraped from [Association of Tennis Professionals website](https://www.atptour.com/) to analyze the biographic information and statistics of world's top 100 male tennis players. In order to reproduce the scraped [tennis_players.csv](./tennis_players.csv) data, you should, first of all, run [data_scraping.R](./data_scraping.R).  

### Required Packages 

You should have following packages installed: 

```
library(tidyverse)
library(tidymodels)
library(here)
library(patchwork)
library(lubridate)
library(kableExtra)
library(scales)
library(rvest)
library(glue)
library(maps)
```