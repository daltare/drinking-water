# clean / format EAR data


# load packages -----------------------------------------------------------
library(tidyverse)
library(purrr)



# download data -----------------------------------------------------------
data_file_url <- 'https://www.waterboards.ca.gov/drinking_water/certlic/drinkingwater/documents/ear/resultset_2020ry.zip'
temp_folder <- tempdir()
data_file_name <- basename(data_file_url)

## download to temp file ----
download.file(url = data_file_url, 
              destfile = file.path(temp_folder, data_file_name))



# read data ---------------------------------------------------------------
## read raw data as character & fix line breaks ----
dataset_raw <- read_file(file = file.path(temp_folder, data_file_name))
dataset_raw <- str_replace_all(string = dataset_raw, 
                               pattern = '\r\n(?!CA\\d{7})', # replace all "\r\n" line breaks, except when the are followed by "CA#######" ("CA" followed by 7 digits), which represents a new ID
                               replacement = ' ') 

## read data into dataframe ----
df_ear <- read_tsv(file = dataset_raw,
                        col_types = cols(.default = col_character()))

## read errors ----
problem_list <- problems()
# View(problem_list)

# glimpse(df_ear)

## check - make sure first two characters of WSID field are always 'CA' and the 
## length of the WSID field is always 9 (i.e. make sure each row starts with a valid WSID)
# df_ear %>% mutate(check = substr(WSID, 1, 2)) %>% count(check)
# df_ear %>% mutate(check = nchar(WSID)) %>% count(check)



# clean / format data --------------------------------------------------------------
##  check last column (OldShortName_QuestionText) for tabs (\t) ----
## (if tabs are present, indicates that there are tab delimiters embedded in individual fields, 
## probably in the QuestionResults field)
df_ear_revised <- df_ear %>% 
    mutate(OldShortName_QuestionText_rev = str_remove(string = OldShortName_QuestionText, 
                                                      pattern = ".*\t")) # https://stackoverflow.com/questions/67596145/r-find-extract-string-from-right

## add column to indicate if row needs to be revised ----
df_ear_revised <- df_ear_revised %>%
    mutate(revise = OldShortName_QuestionText != OldShortName_QuestionText_rev)

# glimpse(df_ear_revised)

## combine last two fields (for rows that need to be revised) ----
## (used to create a revised QuestionResults field if it was erroneously truncated
## due to embedded tabs)
df_ear_revised <- df_ear_revised %>% 
    mutate(QuestionResults_rev = case_when(
        revise == TRUE ~ paste(QuestionResults, 
                               OldShortName_QuestionText, 
                               sep = ' '),
        TRUE ~ QuestionResults)
    )


## fix QuestionResults_rev field ----
## (split based on tab delimiters, then drop the last element, which should be the 
## true value for the OldShortName_QuestionText field)
df_ear_revised <- df_ear_revised %>% 
    mutate(QuestionResults_rev = str_split(string = QuestionResults_rev, # split the QuestionResults_rev column into vector of separate character strings, by tabs (\t)
                                           pattern = '\t')) %>%
    mutate(QuestionResults_rev = map(.x = QuestionResults_rev,
                                     .f = ~
                                         if (length(.x) > 1) { # if more than one character string (from the above split)...
                                             paste(.x[-length(.x)], # drop the last character string (the ".x[-length(.x)]" part) (which should be the value intended for the OldShortName_QuestionText field), and combine (paste) the remaining character vectors into one
                                                   collapse = ' ')
                                         } else {
                                             .x
                                         })) %>%
    mutate(QuestionResults_rev = unlist(QuestionResults_rev))

## checks
# df_ear_revised$QuestionResults_rev[[1]]
# df_ear_revised$QuestionResults_rev[[10478]]
# df_ear_revised$OldShortName_QuestionText[[10478]]

## add revised data to original columns (where needed) ----
df_ear_revised <- df_ear_revised %>% 
    mutate(QuestionResults = case_when(
        revise == TRUE ~ QuestionResults_rev,
        TRUE ~ QuestionResults)) %>% 
    mutate(OldShortName_QuestionText = case_when(
        revise == TRUE ~ OldShortName_QuestionText_rev,
        TRUE ~ OldShortName_QuestionText)) 

## drop unneeded columns ----
df_ear_revised <- df_ear_revised %>% 
    select(-c(OldShortName_QuestionText_rev, revise, QuestionResults_rev))

## checks
# df_ear_revised$QuestionResults[[10478]]
# df_ear_revised$OldShortName_QuestionText[[10478]]



# filter by section ID ----------------------------------------------------
## get section IDs
# df_ear_revised %>% count(SectionID) %>% View()

## section 17 ----
section_17 <- df_ear_revised %>% 
    filter(SectionID == '17 Conservation')
# write_csv(section_17, 'ear_section_17.csv')

## section 18 ----
section_18 <- df_ear_revised %>% 
    filter(SectionID == '18 Climate Change')
# write_csv(section_18, 'ear_section_18.csv')
