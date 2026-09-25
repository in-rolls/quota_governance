# Validate the frozen UP source, join, and analysis contracts.
# Output: none

library(arrow)
library(dplyr)
library(here)

source(here("scripts", "00_config.R"))
source(here("scripts", "00_utils.R"))

panel <- read_parquet(here("data", "up", "up_gp_2021.parquet"))
joined <- read_parquet(
    here("data", "quota_governance", "quota_governance_gp_up_2022_2024.parquet")
)

stopifnot(nrow(panel) == 49773L)
stopifnot(nrow(joined) == 2L * nrow(panel))
stopifnot(setequal(unique(joined$pai_year), c(PAI_YEAR_REPLICATION, PAI_YEAR_PRIMARY)))
stopifnot(all(joined$theme_slug == PAI_T8_SLUG))
stopifnot(!anyDuplicated(joined[c("election_gp_key", "pai_year")]))
stopifnot(all(joined$pai_available == !is.na(joined$pai_good_governance_score)))
stopifnot(sum(panel$an_women_reserved) == 16774L)
stopifnot(sum(!is.na(panel$raw_lgd_gp_code)) == 38397L)

coverage <- joined |>
    group_by(.data$pai_year, .data$an_women_reserved) |>
    summarise(rate = mean(.data$pai_available), .groups = "drop") |>
    group_by(.data$pai_year) |>
    summarise(max_gap = max(.data$rate) - min(.data$rate), .groups = "drop")
stopifnot(all(coverage$max_gap < 0.02))

plan <- paste(readLines(here("docs", "design.md"), warn = FALSE), collapse = "\n")
required <- c(
    "before any UP outcome-on-treatment",
    "conditional association",
    "women pradhans reduce corruption",
    "HC2",
    "4,999"
)
stopifnot(all(vapply(
    required,
    function(pattern) grepl(pattern, plan, fixed = TRUE),
    logical(1)
)))

message("Frozen UP design and disclosure gates passed.")
