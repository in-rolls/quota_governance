# Import the pinned UP 2021 election treatment table.
# Output: data/up/up_gp_2021.parquet,
#         data/up/up_source_profile.csv,
#         data/crosswalks/audit/up_2021_duplicate_name_keys.csv

library(arrow)
library(dplyr)
library(here)
library(readr)

source(here("scripts", "00_config.R"))
source(here("scripts", "00_utils.R"))

message("Reading the standardized UP election release")
release <- read_parquet(resolve_up_election_file())

# 43 columns: the UP release adds winner_markers_conflict (two Sonai, Mainpuri 2021
# rows whose winner markers disagree); it is not used here.
if (nrow(release) != 212525L || ncol(release) != 43L) {
    stop("The pinned UP election release differs from its published schema", call. = FALSE)
}

panel <- release |>
    filter(.data$election_year == ELECTION_YEAR_UP) |>
    transmute(
        election_gp_key = .data$election_gp_key,
        source_id = .data$source_record_id,
        election_year = .data$election_year,
        raw_district_2021 = .data$district_name_eng_raw,
        raw_block_2021 = .data$block_name_eng_raw,
        raw_gp_name_2021 = .data$gp_name_eng_raw,
        raw_gp_name_hindi_2021 = .data$gp_name_hindi,
        raw_gp_number_2021 = .data$gp_number_raw,
        raw_lgd_block_code = .data$lgd_block_code,
        raw_lgd_gp_code = .data$lgd_gp_code,
        raw_lgd_gp_name = .data$lgd_gp_name,
        raw_lgd_gp_link_method = .data$lgd_gp_link_method,
        raw_lgd_gp_link_score = .data$lgd_gp_link_score,
        raw_reservation_2021 = .data$reservation_status_eng,
        raw_pradhan_name_2021 = .data$pradhan_name_eng_raw,
        election_district_std = .data$district_name_std,
        election_block_std = .data$block_name_std,
        election_gp_name_std = .data$gp_name_std,
        name_override_used = .data$name_override_used,
        normalized_name_key = .data$normalized_name_key,
        normalized_name_key_n = .data$normalized_name_key_n,
        link_eligible = .data$link_eligible,
        reservation_class = .data$reservation_class,
        an_women_reserved = .data$women_reserved,
        assignment_block = paste(
            .data$district_name_std, .data$block_name_std, sep = "__"
        ),
        assignment_stratum = paste(
            .data$assignment_block, .data$reservation_class, sep = "__"
        )
    )

if (nrow(panel) != 49773L) {
    stop("The standardized release does not contain 49,773 UP 2021 winners", call. = FALSE)
}
assert_unique(panel, "election_gp_key", "UP 2021 election rows")
assert_unique(panel, "source_id", "UP 2021 source IDs")
assert_binary(panel$an_women_reserved, "UP women-reservation treatment")
if (any(panel$reservation_class == "unknown")) {
    stop("A 2021 reservation label has an unknown class", call. = FALSE)
}

duplicate_names <- panel |>
    filter(.data$normalized_name_key_n > 1L) |>
    arrange(.data$normalized_name_key, .data$source_id)

profile <- tibble(
    metric = c(
        "standardized_release_rows", "winner_rows", "winner_districts",
        "winner_district_blocks", "women_reserved_rows", "women_reserved_share",
        "manual_gp_name_overrides", "normalized_name_collision_rows",
        "link_eligible_rows"
    ),
    value = c(
        nrow(release), nrow(panel), n_distinct(panel$raw_district_2021),
        n_distinct(panel$raw_district_2021, panel$raw_block_2021),
        sum(panel$an_women_reserved), mean(panel$an_women_reserved),
        sum(panel$name_override_used), nrow(duplicate_names), sum(panel$link_eligible)
    )
)

write_parquet_receipt(panel, here("data", "up", "up_gp_2021.parquet"))
write_csv_receipt(profile, here("data", "up", "up_source_profile.csv"))
write_csv_receipt(
    duplicate_names,
    here("data", "crosswalks", "audit", "up_2021_duplicate_name_keys.csv")
)
