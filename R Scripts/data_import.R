library(tidyverse)
library(ggpubr)
library(tidycensus)
library(cowplot)

### nflplotR provides ggpreview() function
### library(nflplotR)

### Used to filter values not within a vector; inverse of %in%
'%!in%' <- function(x,y)!('%in%'(x,y))

### extrafont provides ability to use system fonts in ggplot
library(extrafont)
loadfonts(device = "win")
#font_import()

### Getting states that currently allow corporal punishment
cp_states <- read_csv("CSV Files//corporal_punishment_laws.csv") %>%
  rename(state_name = "state") %>%
  merge(., tigris::fips_codes %>% select(state, state_name) %>% unique(),
        by = "state_name") %>%
  filter(corporal_punishment == "Yes" | corporal_punishment == "Not Mentioned" | year_outlawed > 2020) %>%
  pull(state)

### Importing raw CSV files
cp_raw <- readxl::read_xlsx("CSV Files//corp_76to20_bystate.xlsx") %>%
  filter(YEAR != 2020)

oss_raw <- read_csv("CSV Files//suspensions_data.csv") %>%
  mutate(YEAR = as.numeric(gsub(2021, 2020, YEAR))) %>%
  filter(YEAR != 2020)



### Data frames with states that have always allowed corporal punishment
cp_always <- cp_raw %>%
  filter(STATE_CODE %in% cp_states) %>%
  mutate("race_fixed" = ifelse(race == "HP", "AI", race)) %>%
  group_by(YEAR, race_fixed) %>%
  summarise(cp_sum = sum(CORP_),
            enr_sum = sum(ENR_)) %>%
  mutate(cp_rate = cp_sum / enr_sum) %>% 
  filter(YEAR >= 1975) %>%
  mutate("legend_text" = ifelse(race_fixed == "sumrace", "All Students",
                         ifelse(race_fixed == "AI", "American Indian / Alaskan Native",
                         ifelse(race_fixed == "AS", "Asian / Pacific Islander",
                         ifelse(race_fixed == "BL", "Black / African American",
                         ifelse(race_fixed == "HI", "Hispanic",
                         ifelse(race_fixed == "HP", "Native Hawaiian / Pacific Islander",
                         ifelse(race_fixed == "MR", "Multi-racial",
                         ifelse(race_fixed == "WH", "White", "check")))))))),
         "size" = ifelse(race_fixed == "sumrace", "all", "not_all")) %>%
  filter(race_fixed %in% c("AI", "AS", "BL", "HI", "WH"))

oss_always <- oss_raw %>%
  filter(STATE_CODE %in% cp_states) %>%
  drop_na(STATE_CODE) %>%
  mutate("race_fixed" = ifelse(race == "HP", "AI", race)) %>%
  group_by(YEAR, race_fixed) %>%
  summarise("oss_sum" = sum(OSS_),
            "oss_mem" = sum(MEM_)) %>%
  mutate(oss_rate = oss_sum / oss_mem) %>% 
  #filter(YEAR >= 1975) %>%
  mutate("legend_text" = ifelse(race_fixed == "total", "All Students",
                         ifelse(race_fixed == "AI", "American Indian / Alaskan Native",
                         ifelse(race_fixed == "AS", "Asian / Pacific Islander",
                         ifelse(race_fixed == "BL", "Black / African American",
                         ifelse(race_fixed == "HI", "Hispanic",
                         ifelse(race_fixed == "HP", "Native Hawaiian / Pacific Islander",
                         ifelse(race_fixed == "MR", "Multi-racial",
                         ifelse(race_fixed == "WH", "White", "check"))))))))) %>%
  filter(race_fixed %in% c("AI", "AS", "BL", "HI", "WH"))



cp_rr_rd_always <- cp_raw %>%
  filter(STATE_CODE %in% cp_states) %>%
  filter(race != "sumrace") %>%
  mutate("race_adjusted" = ifelse(race %!in% c("BL", "HI", "WH", "AI", "AS"), "OTHER", race)) %>%
  filter(YEAR > 1974) %>%
  group_by(race_adjusted, YEAR) %>%
  summarise(ENR = sum(ENR_),
            CORP = sum(CORP_)) %>%
  pivot_wider(names_from = "race_adjusted", values_from = c("ENR", "CORP")) %>%
  mutate("bl_rate" = CORP_BL / ENR_BL,
         "wh_rate" = CORP_WH / ENR_WH) %>%
  mutate("bl_wh_rr" = bl_rate / wh_rate,
         "bl_wh_rd" = (CORP_BL / ENR_BL) - (CORP_WH / ENR_WH),
         "bl_hi_rr" = (CORP_BL / ENR_BL) / (CORP_HI / ENR_HI),
         "bl_hi_rd" = (CORP_BL / ENR_BL) - (CORP_HI / ENR_HI),
         "hi_wh_rr" = (CORP_HI / ENR_HI) / (CORP_WH / ENR_WH),
         "hi_wh_rd" = (CORP_HI / ENR_HI) - (CORP_WH / ENR_WH),
         "ot_wh_rr" = (CORP_OTHER / ENR_OTHER) / (CORP_WH / ENR_WH),
         "ot_wh_rd" = (CORP_OTHER / ENR_OTHER) - (CORP_WH / ENR_WH),
         "ai_wh_rr" = (CORP_AI / ENR_AI) / (CORP_WH / ENR_WH),
         "ai_wh_rd" = (CORP_AI / ENR_AI) - (CORP_WH / ENR_WH),
         "as_wh_rr" = (CORP_AS / ENR_AS) / (CORP_WH / ENR_WH),
         "as_wh_rd" = (CORP_AS / ENR_AS) - (CORP_WH / ENR_WH)) %>%
  pivot_longer(cols = c(bl_wh_rr, bl_hi_rr, hi_wh_rr, ot_wh_rr, ai_wh_rr, as_wh_rr,
                        bl_wh_rd, bl_hi_rd, hi_wh_rd, ot_wh_rd, ai_wh_rd, as_wh_rd), 
               names_to = "type", values_to = "value") %>%
  mutate("legend_text" = ifelse(type == "bl_wh_rr", "Black / White Risk Ratio",
                         ifelse(type == "hi_wh_rr", "Hispanic / White Risk Ratio",
                         ifelse(type == "bl_wh_rd", "Black / White Risk Difference",
                         ifelse(type == "hi_wh_rd", "Hispanic / White Risk Difference",
                         ifelse(type == "ai_wh_rr", "American Indian or Alaskan Native / White Risk Ratio",
                         ifelse(type == "ai_wh_rd", "American Indian or Alaskan Native / White Risk Difference",
                         ifelse(type == "as_wh_rr", "Asian or Pacific Islander / White Risk Ratio",
                         ifelse(type == "as_wh_rd", "Asian or Pacific Islander / White Risk Difference",
                                "other"))))))))) %>%
  distinct()

oss_rr_rd_always <- oss_raw %>%
  filter(STATE_CODE %in% cp_states) %>%
  filter(race != "total") %>%
  mutate("race_adjusted" = ifelse(race %!in% c("BL", "HI", "WH", "AI", "AS"), "OTHER", race)) %>%
  #filter(YEAR > 1974) %>%
  group_by(race_adjusted, YEAR) %>%
  summarise(ENR = sum(MEM_),
            CORP = sum(OSS_)) %>%
  pivot_wider(names_from = "race_adjusted", values_from = c("ENR", "CORP")) %>%
  mutate("bl_rate" = CORP_BL / ENR_BL,
         "wh_rate" = CORP_WH / ENR_WH) %>%
  mutate("bl_wh_rr" = bl_rate / wh_rate,
         "bl_wh_rd" = (CORP_BL / ENR_BL) - (CORP_WH / ENR_WH),
         "bl_hi_rr" = (CORP_BL / ENR_BL) / (CORP_HI / ENR_HI),
         "bl_hi_rd" = (CORP_BL / ENR_BL) - (CORP_HI / ENR_HI),
         "hi_wh_rr" = (CORP_HI / ENR_HI) / (CORP_WH / ENR_WH),
         "hi_wh_rd" = (CORP_HI / ENR_HI) - (CORP_WH / ENR_WH),
         "ot_wh_rr" = (CORP_OTHER / ENR_OTHER) / (CORP_WH / ENR_WH),
         "ot_wh_rd" = (CORP_OTHER / ENR_OTHER) - (CORP_WH / ENR_WH),
         "ai_wh_rr" = (CORP_AI / ENR_AI) / (CORP_WH / ENR_WH),
         "ai_wh_rd" = (CORP_AI / ENR_AI) - (CORP_WH / ENR_WH),
         "as_wh_rr" = (CORP_AS / ENR_AS) / (CORP_WH / ENR_WH),
         "as_wh_rd" = (CORP_AS / ENR_AS) - (CORP_WH / ENR_WH)) %>%
  pivot_longer(cols = c(bl_wh_rr, bl_hi_rr, hi_wh_rr, ot_wh_rr, ai_wh_rr, as_wh_rr,
                        bl_wh_rd, bl_hi_rd, hi_wh_rd, ot_wh_rd, ai_wh_rd, as_wh_rd), 
               names_to = "type", values_to = "value") %>%
  mutate("legend_text" = ifelse(type == "bl_wh_rr", "Black / White Risk Ratio",
                         ifelse(type == "hi_wh_rr", "Hispanic / White Risk Ratio",
                         ifelse(type == "bl_wh_rd", "Black / White Risk Difference",
                         ifelse(type == "hi_wh_rd", "Hispanic / White Risk Difference",
                         ifelse(type == "ai_wh_rr", "American Indian or Alaskan Native / White Risk Ratio",
                         ifelse(type == "ai_wh_rd", "American Indian or Alaskan Native / White Risk Difference",
                         ifelse(type == "as_wh_rr", "Asian or Pacific Islander / White Risk Ratio",
                         ifelse(type == "as_wh_rd", "Asian or Pacific Islander / White Risk Difference",
                                "other"))))))))) %>%
  distinct()



### Data frames with states that had corporal punishment legal at some point between 1973 and 2020
cp_sometime <- cp_raw %>%
  filter(STATE_CODE %!in% cp_states & STATE_CODE %!in% c("NJ", "MA")) %>%
  mutate("race_fixed" = ifelse(race == "HP", "AI", race)) %>%
  group_by(YEAR, race_fixed) %>%
  summarise(cp_sum = sum(CORP_),
            enr_sum = sum(ENR_)) %>%
  mutate(cp_rate = cp_sum / enr_sum) %>% 
  filter(YEAR >= 1975) %>%
  mutate("legend_text" = ifelse(race_fixed == "sumrace", "All Students",
                         ifelse(race_fixed == "AI", "American Indian / Alaskan Native",
                         ifelse(race_fixed == "AS", "Asian / Pacific Islander",
                         ifelse(race_fixed == "BL", "Black / African American",
                         ifelse(race_fixed == "HI", "Hispanic",
                         ifelse(race_fixed == "HP", "Native Hawaiian / Pacific Islander",
                         ifelse(race_fixed == "MR", "Multi-racial",
                         ifelse(race_fixed == "WH", "White", "check"))))))))) %>%
  filter(race_fixed %in% c("AI", "AS", "BL", "HI", "WH"))

oss_sometime <- oss_raw %>%
  filter(STATE_CODE %!in% cp_states & STATE_CODE %!in% c("NJ", "MA")) %>%
  drop_na(STATE_CODE) %>%
  mutate("race_fixed" = ifelse(race == "HP", "AI", race)) %>%
  group_by(YEAR, race_fixed) %>%
  summarise("oss_sum" = sum(OSS_),
            "oss_mem" = sum(MEM_)) %>%
  mutate(oss_rate = oss_sum / oss_mem) %>% 
  filter(YEAR >= 1975) %>%
  mutate("legend_text" = ifelse(race_fixed == "total", "All Students",
                         ifelse(race_fixed == "AI", "American Indian / Alaskan Native",
                         ifelse(race_fixed == "AS", "Asian / Pacific Islander",
                         ifelse(race_fixed == "BL", "Black / African American",
                         ifelse(race_fixed == "HI", "Hispanic",
                         ifelse(race_fixed == "HP", "Native Hawaiian / Pacific Islander",
                         ifelse(race_fixed == "MR", "Multi-racial",
                         ifelse(race_fixed == "WH", "White", "check"))))))))) %>%
  filter(race_fixed %in% c("AI", "AS", "BL", "HI", "WH"))



cp_rr_rd_sometime <- cp_raw %>%
  filter(STATE_CODE %!in% cp_states & STATE_CODE %!in% c("NJ", "MA")) %>%
  filter(race != "sumrace") %>%
  mutate("race_adjusted" = ifelse(race %!in% c("BL", "HI", "WH", "AI", "AS"), "OTHER", race)) %>%
  filter(YEAR > 1974) %>%
  group_by(race_adjusted, YEAR) %>%
  summarise(ENR = sum(ENR_),
            CORP = sum(CORP_)) %>%
  pivot_wider(names_from = "race_adjusted", values_from = c("ENR", "CORP")) %>%
  mutate("bl_rate" = CORP_BL / ENR_BL,
         "wh_rate" = CORP_WH / ENR_WH) %>%
  mutate("bl_wh_rr" = bl_rate / wh_rate,
         "bl_wh_rd" = (CORP_BL / ENR_BL) - (CORP_WH / ENR_WH),
         "bl_hi_rr" = (CORP_BL / ENR_BL) / (CORP_HI / ENR_HI),
         "bl_hi_rd" = (CORP_BL / ENR_BL) - (CORP_HI / ENR_HI),
         "hi_wh_rr" = (CORP_HI / ENR_HI) / (CORP_WH / ENR_WH),
         "hi_wh_rd" = (CORP_HI / ENR_HI) - (CORP_WH / ENR_WH),
         "ot_wh_rr" = (CORP_OTHER / ENR_OTHER) / (CORP_WH / ENR_WH),
         "ot_wh_rd" = (CORP_OTHER / ENR_OTHER) - (CORP_WH / ENR_WH),
         "ai_wh_rr" = (CORP_AI / ENR_AI) / (CORP_WH / ENR_WH),
         "ai_wh_rd" = (CORP_AI / ENR_AI) - (CORP_WH / ENR_WH),
         "as_wh_rr" = (CORP_AS / ENR_AS) / (CORP_WH / ENR_WH),
         "as_wh_rd" = (CORP_AS / ENR_AS) - (CORP_WH / ENR_WH)) %>%
  pivot_longer(cols = c(bl_wh_rr, bl_hi_rr, hi_wh_rr, ot_wh_rr, ai_wh_rr, as_wh_rr,
                        bl_wh_rd, bl_hi_rd, hi_wh_rd, ot_wh_rd, ai_wh_rd, as_wh_rd), 
               names_to = "type", values_to = "value") %>%
  mutate("legend_text" = ifelse(type == "bl_wh_rr", "Black / White Risk Ratio",
                         ifelse(type == "hi_wh_rr", "Hispanic / White Risk Ratio",
                         ifelse(type == "bl_wh_rd", "Black / White Risk Difference",
                         ifelse(type == "hi_wh_rd", "Hispanic / White Risk Difference",
                         ifelse(type == "ai_wh_rr", "American Indian or Alaskan Native / White Risk Ratio",
                         ifelse(type == "ai_wh_rd", "American Indian or Alaskan Native / White Risk Difference",
                         ifelse(type == "as_wh_rr", "Asian or Pacific Islander / White Risk Ratio",
                         ifelse(type == "as_wh_rd", "Asian or Pacific Islander / White Risk Difference",
                                "other"))))))))) %>%
  distinct()

oss_rr_rd_sometime <- oss_raw %>%
  filter(STATE_CODE %!in% cp_states & STATE_CODE %!in% c("NJ", "MA")) %>%
  filter(race != "total") %>%
  mutate("race_adjusted" = ifelse(race %!in% c("BL", "HI", "WH", "AI", "AS"), "OTHER", race)) %>%
  #filter(YEAR > 1974) %>%
  group_by(race_adjusted, YEAR) %>%
  summarise(ENR = sum(MEM_),
            CORP = sum(OSS_)) %>%
  pivot_wider(names_from = "race_adjusted", values_from = c("ENR", "CORP")) %>%
  mutate("bl_rate" = CORP_BL / ENR_BL,
         "wh_rate" = CORP_WH / ENR_WH) %>%
  mutate("bl_wh_rr" = bl_rate / wh_rate,
         "bl_wh_rd" = (CORP_BL / ENR_BL) - (CORP_WH / ENR_WH),
         "bl_hi_rr" = (CORP_BL / ENR_BL) / (CORP_HI / ENR_HI),
         "bl_hi_rd" = (CORP_BL / ENR_BL) - (CORP_HI / ENR_HI),
         "hi_wh_rr" = (CORP_HI / ENR_HI) / (CORP_WH / ENR_WH),
         "hi_wh_rd" = (CORP_HI / ENR_HI) - (CORP_WH / ENR_WH),
         "ot_wh_rr" = (CORP_OTHER / ENR_OTHER) / (CORP_WH / ENR_WH),
         "ot_wh_rd" = (CORP_OTHER / ENR_OTHER) - (CORP_WH / ENR_WH),
         "ai_wh_rr" = (CORP_AI / ENR_AI) / (CORP_WH / ENR_WH),
         "ai_wh_rd" = (CORP_AI / ENR_AI) - (CORP_WH / ENR_WH),
         "as_wh_rr" = (CORP_AS / ENR_AS) / (CORP_WH / ENR_WH),
         "as_wh_rd" = (CORP_AS / ENR_AS) - (CORP_WH / ENR_WH)) %>%
  pivot_longer(cols = c(bl_wh_rr, bl_hi_rr, hi_wh_rr, ot_wh_rr, ai_wh_rr, as_wh_rr,
                        bl_wh_rd, bl_hi_rd, hi_wh_rd, ot_wh_rd, ai_wh_rd, as_wh_rd), 
               names_to = "type", values_to = "value") %>%
  mutate("legend_text" = ifelse(type == "bl_wh_rr", "Black / White Risk Ratio",
                         ifelse(type == "hi_wh_rr", "Hispanic / White Risk Ratio",
                         ifelse(type == "bl_wh_rd", "Black / White Risk Difference",
                         ifelse(type == "hi_wh_rd", "Hispanic / White Risk Difference",
                         ifelse(type == "ai_wh_rr", "American Indian or Alaskan Native / White Risk Ratio",
                         ifelse(type == "ai_wh_rd", "American Indian or Alaskan Native / White Risk Difference",
                         ifelse(type == "as_wh_rr", "Asian or Pacific Islander / White Risk Ratio",
                         ifelse(type == "as_wh_rd", "Asian or Pacific Islander / White Risk Difference",
                                "other"))))))))) %>%
  distinct()



### Data frames with all states
cp_all <- cp_raw %>%
  #filter(CORP_ != 0) %>%
  mutate("race_fixed" = ifelse(race == "HP", "AI", race)) %>%
  group_by(YEAR, race_fixed) %>%
  summarise(cp_sum = sum(CORP_),
            enr_sum = sum(ENR_)) %>%
  mutate(cp_rate = cp_sum / enr_sum) %>% 
  filter(YEAR >= 1975) %>%
  mutate("legend_text" = ifelse(race_fixed == "sumrace", "All Students",
                         ifelse(race_fixed == "AI", "American Indian / Alaskan Native",
                         ifelse(race_fixed == "AS", "Asian / Pacific Islander",
                         ifelse(race_fixed == "BL", "Black / African American",
                         ifelse(race_fixed == "HI", "Hispanic",
                         ifelse(race_fixed == "HP", "Native Hawaiian / Pacific Islander",
                         ifelse(race_fixed == "MR", "Multi-racial",
                         ifelse(race_fixed == "WH", "White", "check")))))))),
         "size" = ifelse(race_fixed == "sumrace", "all", "not_all")) %>%
  filter(race_fixed %in% c("AI", "AS", "BL", "HI", "WH"))
  

oss_all <- oss_raw %>%
  drop_na(STATE_CODE) %>%
  mutate("race_fixed" = ifelse(race == "HP", "AI", race)) %>%
  group_by(YEAR, race_fixed) %>%
  summarise("oss_sum" = sum(OSS_),
            "oss_mem" = sum(MEM_)) %>%
  mutate(oss_rate = oss_sum / oss_mem) %>% 
  #filter(YEAR >= 1975) %>%
  mutate("legend_text" = ifelse(race_fixed == "total", "All Students",
                         ifelse(race_fixed == "AI", "American Indian / Alaskan Native",
                         ifelse(race_fixed == "AS", "Asian / Pacific Islander",
                         ifelse(race_fixed == "BL", "Black / African American",
                         ifelse(race_fixed == "HI", "Hispanic",
                         ifelse(race_fixed == "HP", "Native Hawaiian / Pacific Islander",
                         ifelse(race_fixed == "MR", "Multi-racial",
                         ifelse(race_fixed == "WH", "White", "check"))))))))) %>%
  filter(race_fixed %in% c("AI", "AS", "BL", "HI", "WH"))



cp_rr_rd_all <- cp_raw %>%
  filter(race != "sumrace") %>%
  mutate("race_adjusted" = ifelse(race %!in% c("BL", "HI", "WH", "AI", "AS"), "OTHER", race)) %>%
  filter(YEAR > 1974) %>%
  group_by(race_adjusted, YEAR) %>%
  summarise(ENR = sum(ENR_),
            CORP = sum(CORP_)) %>%
  pivot_wider(names_from = "race_adjusted", values_from = c("ENR", "CORP")) %>%
  mutate("bl_rate" = CORP_BL / ENR_BL,
         "wh_rate" = CORP_WH / ENR_WH) %>%
  mutate("bl_wh_rr" = bl_rate / wh_rate,
         "bl_wh_rd" = (CORP_BL / ENR_BL) - (CORP_WH / ENR_WH),
         "bl_hi_rr" = (CORP_BL / ENR_BL) / (CORP_HI / ENR_HI),
         "bl_hi_rd" = (CORP_BL / ENR_BL) - (CORP_HI / ENR_HI),
         "hi_wh_rr" = (CORP_HI / ENR_HI) / (CORP_WH / ENR_WH),
         "hi_wh_rd" = (CORP_HI / ENR_HI) - (CORP_WH / ENR_WH),
         "ot_wh_rr" = (CORP_OTHER / ENR_OTHER) / (CORP_WH / ENR_WH),
         "ot_wh_rd" = (CORP_OTHER / ENR_OTHER) - (CORP_WH / ENR_WH),
         "ai_wh_rr" = (CORP_AI / ENR_AI) / (CORP_WH / ENR_WH),
         "ai_wh_rd" = (CORP_AI / ENR_AI) - (CORP_WH / ENR_WH),
         "as_wh_rr" = (CORP_AS / ENR_AS) / (CORP_WH / ENR_WH),
         "as_wh_rd" = (CORP_AS / ENR_AS) - (CORP_WH / ENR_WH)) %>%
  pivot_longer(cols = c(bl_wh_rr, bl_hi_rr, hi_wh_rr, ot_wh_rr, ai_wh_rr, as_wh_rr,
                        bl_wh_rd, bl_hi_rd, hi_wh_rd, ot_wh_rd, ai_wh_rd, as_wh_rd), 
               names_to = "type", values_to = "value") %>%
  mutate("legend_text" = ifelse(type == "bl_wh_rr", "Black / White Risk Ratio",
                         ifelse(type == "hi_wh_rr", "Hispanic / White Risk Ratio",
                         ifelse(type == "bl_wh_rd", "Black / White Risk Difference",
                         ifelse(type == "hi_wh_rd", "Hispanic / White Risk Difference",
                         ifelse(type == "ai_wh_rr", "American Indian or Alaskan Native / White Risk Ratio",
                         ifelse(type == "ai_wh_rd", "American Indian or Alaskan Native / White Risk Difference",
                         ifelse(type == "as_wh_rr", "Asian or Pacific Islander / White Risk Ratio",
                         ifelse(type == "as_wh_rd", "Asian or Pacific Islander / White Risk Difference",
                                "other"))))))))) %>%
  distinct()

oss_rr_rd_all <- oss_raw %>%
  filter(race != "total") %>%
  mutate("race_adjusted" = ifelse(race %!in% c("BL", "HI", "WH", "AI", "AS"), "OTHER", race)) %>%
  #filter(YEAR > 1974) %>%
  group_by(race_adjusted, YEAR) %>%
  summarise(ENR = sum(MEM_),
            CORP = sum(OSS_)) %>%
  pivot_wider(names_from = "race_adjusted", values_from = c("ENR", "CORP")) %>%
  mutate("bl_rate" = CORP_BL / ENR_BL,
         "wh_rate" = CORP_WH / ENR_WH) %>%
  mutate("bl_wh_rr" = bl_rate / wh_rate,
         "bl_wh_rd" = (CORP_BL / ENR_BL) - (CORP_WH / ENR_WH),
         "bl_hi_rr" = (CORP_BL / ENR_BL) / (CORP_HI / ENR_HI),
         "bl_hi_rd" = (CORP_BL / ENR_BL) - (CORP_HI / ENR_HI),
         "hi_wh_rr" = (CORP_HI / ENR_HI) / (CORP_WH / ENR_WH),
         "hi_wh_rd" = (CORP_HI / ENR_HI) - (CORP_WH / ENR_WH),
         "ot_wh_rr" = (CORP_OTHER / ENR_OTHER) / (CORP_WH / ENR_WH),
         "ot_wh_rd" = (CORP_OTHER / ENR_OTHER) - (CORP_WH / ENR_WH),
         "ai_wh_rr" = (CORP_AI / ENR_AI) / (CORP_WH / ENR_WH),
         "ai_wh_rd" = (CORP_AI / ENR_AI) - (CORP_WH / ENR_WH),
         "as_wh_rr" = (CORP_AS / ENR_AS) / (CORP_WH / ENR_WH),
         "as_wh_rd" = (CORP_AS / ENR_AS) - (CORP_WH / ENR_WH)) %>%
  pivot_longer(cols = c(bl_wh_rr, bl_hi_rr, hi_wh_rr, ot_wh_rr, ai_wh_rr, as_wh_rr,
                        bl_wh_rd, bl_hi_rd, hi_wh_rd, ot_wh_rd, ai_wh_rd, as_wh_rd), 
               names_to = "type", values_to = "value") %>%
  mutate("legend_text" = ifelse(type == "bl_wh_rr", "Black / White Risk Ratio",
                         ifelse(type == "hi_wh_rr", "Hispanic / White Risk Ratio",
                         ifelse(type == "bl_wh_rd", "Black / White Risk Difference",
                         ifelse(type == "hi_wh_rd", "Hispanic / White Risk Difference",
                         ifelse(type == "ai_wh_rr", "American Indian or Alaskan Native / White Risk Ratio",
                         ifelse(type == "ai_wh_rd", "American Indian or Alaskan Native / White Risk Difference",
                         ifelse(type == "as_wh_rr", "Asian or Pacific Islander / White Risk Ratio",
                         ifelse(type == "as_wh_rd", "Asian or Pacific Islander / White Risk Difference",
                                "other"))))))))) %>%
  distinct()

### Creating data frames where only years where a universe was collected are included
years <- c(1976, 2000, 2011, 2013, 2015, 2017, 2020)

cp_all_universe <- cp_all %>%
  filter(YEAR %in% years)

cp_rr_rd_all_universe <- cp_rr_rd_all %>%
  filter(YEAR %in% years)

cp_always_universe <- cp_always %>%
  filter(YEAR %in% years)

cp_rr_rd_always_universe <- cp_rr_rd_always %>%
  filter(YEAR %in% years)

oss_all_universe <- oss_all %>%
  filter(YEAR %in% years)

oss_rr_rd_all_universe <- oss_rr_rd_all %>%
  filter(YEAR %in% years)
