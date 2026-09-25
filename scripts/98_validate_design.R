# 98_validate_design.R
# Validate source counts, join conservation, and analysis-status disclosure.
# Output: none

library(here)
library(dplyr)
library(readr)
library(arrow)

source(here("scripts", "00_config.R"))
source(here("scripts", "00_utils.R"))

panel <- read_parquet(here("data", "quota_representation", "quota_representation_gp_raj_2015_2020.parquet"))
joined <- read_parquet(here("data", "quota_governance", "quota_governance_gp_raj_2022_2024.parquet"))
groups <- read_csv(
    here("data", "crosswalks", "active", "pai2_group_overrides.csv"),
    col_types = cols(.default = col_character()),
    na = character(),
    show_col_types = FALSE
)
review_queue <- read_csv(
    here("data", "crosswalks", "audit", "pai2_gp_review_queue.csv"),
    col_types = cols(.default = col_character()),
    na = character(),
    show_col_types = FALSE
)

stopifnot(nrow(panel) == 7882L)
stopifnot(nrow(joined) == 2L * nrow(panel))
stopifnot(setequal(unique(joined$pai_year), c(PAI_YEAR_REPLICATION, PAI_YEAR_PRIMARY)))
stopifnot(all(joined$theme_slug == PAI_T8_SLUG))
stopifnot(!anyDuplicated(joined[c("election_gp_key", "pai_year")]))
stopifnot(all(joined$pai_available == !is.na(joined$pai_good_governance_score)))
stopifnot(all(groups$status %in% c("pending", "approved", "rejected")))
stopifnot(!anyDuplicated(groups[c("left_district_std", "left_block_std")]))
stopifnot(!any(c("an_women_reserved", "pai_good_governance_score") %in% names(review_queue)))

approved_groups <- groups |>
    filter(.data$status == "approved")
if (nrow(approved_groups) > 0L) {
    stopifnot(all(nzchar(approved_groups$reviewer)))
    stopifnot(all(nzchar(approved_groups$reviewed_at)))
}

analysis_scripts <- list.files(
    here("scripts"), pattern = "(main|effect|model)", full.names = FALSE
)
if (length(analysis_scripts) > 0L) {
    pap_text <- paste(readLines(here("docs", "design.md"), warn = FALSE), collapse = "\n")
    if (!grepl("exploratory Rajasthan outcome analysis began", pap_text, fixed = TRUE)) {
        stop("Outcome analysis exists without an unblinding disclosure", call. = FALSE)
    }
}

message("Design and disclosure gates passed.")
