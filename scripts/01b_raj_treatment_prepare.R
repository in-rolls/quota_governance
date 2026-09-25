# 01b_raj_treatment_prepare.R
# Prepare the 2015-2020 Rajasthan reservation panel and linkage fields.
# Output: data/quota_representation/quota_representation_gp_raj_2015_2020.parquet,
#         data/quota_representation/quota_representation_profile.csv

library(here)
library(dplyr)
library(arrow)

source(here("scripts", "00_config.R"))
source(here("scripts", "00_utils.R"))

message("Reading the Rajasthan reservation panel")
panel <- read_parquet(resolve_election_file(
    "local_elections_rajasthan", "data/fin/elections/raj_15_20.parquet"
)) |>
    left_join(
        read_parquet(resolve_election_file(
            "local_elections_rajasthan", "data/fin/elections/gp_lgd_crosswalk.parquet"
        )),
        by = "match_key", relationship = "many-to-one"
    ) |>
    transmute(
        election_gp_key = .data$match_key_2020,
        raw_district_2020 = .data$district_std_2020,
        raw_block_2020 = .data$samiti_std_2020,
        raw_gp_name_2020 = .data$gp_std_2020,
        raw_women_reserved_2015 = .data$female_reserved_2015,
        raw_women_reserved_2020 = .data$female_reserved_2020,
        raw_caste_reservation_2020 = .data$caste_category_2020,
        raw_lgd_gp_code = as.character(.data$lgd_gp_code),
        raw_lgd_gp_name = .data$lgd_gp_name,
        raw_lgd_block_code = as.character(.data$lgd_block_code),
        raw_lgd_block_name = .data$lgd_block_name,
        raw_lgd_district = .data$lgd_district,
        raw_lgd_match_type = .data$match_type,
        raw_lgd_match_distance = .data$match_distance,
        an_women_reserved = as.integer(.data$female_reserved_2020),
        assignment_stratum = paste(
            .data$district_std_2020,
            .data$samiti_std_2020,
            .data$caste_category_2020,
            sep = "__"
        ),
        election_district_std = normalize_name(.data$district_std_2020),
        election_block_std = normalize_name(.data$samiti_std_2020),
        election_gp_name_std = normalize_name(.data$gp_std_2020),
        lgd_district_std = normalize_name(.data$lgd_district),
        lgd_block_std = normalize_name(.data$lgd_block_name),
        lgd_gp_name_std = normalize_name(.data$lgd_gp_name)
    )

assert_unique(panel, "election_gp_key", "Rajasthan election panel")
assert_binary(panel$an_women_reserved, "an_women_reserved")

profile <- panel |>
    summarise(
        rows = n(),
        unique_election_gps = n_distinct(.data$election_gp_key),
        lgd_gp_codes_nonmissing = sum(!is.na(.data$raw_lgd_gp_code)),
        unique_lgd_gp_codes = n_distinct(.data$raw_lgd_gp_code, na.rm = TRUE),
        women_reserved = sum(.data$an_women_reserved == 1L),
        open = sum(.data$an_women_reserved == 0L),
        assignment_strata = n_distinct(.data$assignment_stratum)
    )

if (profile$rows != 7882L || profile$unique_lgd_gp_codes != 4728L) {
    stop("Rajasthan panel counts differ from the profiled source", call. = FALSE)
}

write_parquet_receipt(
    panel,
    here("data", "quota_representation", "quota_representation_gp_raj_2015_2020.parquet")
)
write_csv_receipt(profile, here("data", "quota_representation", "quota_representation_profile.csv"))
