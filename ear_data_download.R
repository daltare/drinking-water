library(dplyr)
library(readr)

# create link to the dataset
year <- 2018
dataset_link <- paste0('https://www.waterboards.ca.gov/drinking_water/certlic/drinkingwater/documents/ear/earsurveyresults_', 
                       year, 
                       'ry.zip')

# create a temporary file (to store the zip file)
temp_file <- tempfile()

# download the zip file
download.file(dataset_link, temp_file)

# get the name of the text file
file_name <- unzip(temp_file, list = TRUE) %>% pull(Name)

# create a connection to the file
con <- unz(temp_file, file_name)

# read the data into a data frame
df_ear_results <- read_tsv(con)
# NOTE: to see problems/errors in importing data from the text file to R, use: 
# problems(df_ear_results)

# remove the temp file
unlink(temp_file)
