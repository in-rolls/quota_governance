# Validate the Mumbai (BMC) frame and design contracts before estimation.
# Output: none

library(arrow)
library(dplyr)
library(here)

source(here("scripts", "00_config.R"))
source(here("scripts", "00_utils.R"))

frame <- read_parquet(here("data", "bmc", "quota_governance_bmc_2007_2017.parquet"))

stopifnot(nrow(frame) == 1361L)
stopifnot(!anyDuplicated(frame[c("council", "ward_no", "survey_year")]))
stopifnot(setequal(unique(frame$council), BMC_COUNCILS))

# The statutory women's share: one third of 227 for the 2007 council, one half
# after. The 2012 source sheet lists one seat more than the statute (ward 172,
# which the deposit and the sitting male councillor say was open); it is kept
# as printed and dropped in a prespecified robustness row.
per_council <- frame |>
    filter(.data$survey_year %in% BMC_PRIMARY_WAVES) |>
    group_by(.data$council) |>
    summarise(
        women = sum(.data$an_women_reserved),
        disagree = sum(.data$an_women_reserved != .data$deposit_women_reserved),
        .groups = "drop"
    )
stopifnot(all(abs(per_council$women - BMC_WOMEN_SEATS[as.character(per_council$council)]) <= 1L))
stopifnot(all(per_council$disagree <= 1L))

# Treatment is the seat's reservation, never the councillor's sex: women hold
# some open seats in every council.
open_women <- frame |>
    filter(.data$an_women_reserved == 0L, .data$councillor_woman == 1L) |>
    distinct(.data$council)
stopifnot(nrow(open_women) == 3L)
# Every reserved seat the deposit also calls reserved is held by a woman, up to
# the deposit's own coding of the councillor's sex (blank names are coded 0;
# two 2017 councillors with women's names are coded 0). The one seat both
# sources call reserved and the deposit fills with a man is ward 172 in 2012.
men_in_reserved <- frame |>
    filter(
        .data$an_women_reserved == 1L,
        .data$councillor_woman == 0L,
        !is.na(.data$councillor)
    ) |>
    distinct(.data$council, .data$ward_no, .data$deposit_women_reserved)
stopifnot(sum(men_in_reserved$deposit_women_reserved == 0L) == 1L)
stopifnot(nrow(men_in_reserved) <= 3L)

# The 2018 satisfaction item is inverted and must be blank in the analysis copy.
in_2018 <- frame |> filter(.data$survey_year == "2018")
stopifnot(all(is.na(in_2018$an_rating_satisfaction)))
service_2018 <- rowMeans(as.matrix(in_2018[paste0("raw_rating_", BMC_SERVICE_ITEMS)]))
stopifnot(cor(in_2018$raw_rating_satisfaction, service_2018) < 0)
in_2016 <- frame |> filter(.data$survey_year == "2016")
service_2016 <- rowMeans(as.matrix(in_2016[paste0("raw_rating_", BMC_SERVICE_ITEMS)]))
stopifnot(cor(in_2016$an_rating_satisfaction, service_2016) > 0)

# Strata: the 2012 draw is compared within prior-reservation status; 2007 and
# 2017 are single pools.
strata <- frame |> distinct(.data$council, .data$assignment_stratum) |> count(.data$council)
stopifnot(all(strata$n[strata$council == 2012L] == 2L))
stopifnot(all(strata$n[strata$council != 2012L] == 1L))

plan <- paste(readLines(here("docs", "design.md"), warn = FALSE), collapse = "\n")
required <- c(
    "Mumbai",
    "drawn by lot",
    "satisfaction item is excluded",
    "one survey wave per council",
    "HC2",
    "4,999",
    "seed 20260903"
)
stopifnot(all(vapply(
    required,
    function(pattern) grepl(pattern, plan, fixed = TRUE),
    logical(1)
)))

message("BMC design and disclosure gates passed.")
