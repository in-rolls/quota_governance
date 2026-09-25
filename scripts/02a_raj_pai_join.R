# 02a_raj_pai_join.R
# Link the Rajasthan reservation panel to PAI and prepare blinded fuzzy queues.
# Output: data/quota_governance/quota_governance_gp_raj_2022_2024.parquet,
#         data/crosswalks/audit/pai_coverage_by_treatment.csv,
#         data/crosswalks/audit/pai2_unmatched_left.parquet,
#         data/crosswalks/audit/pai2_unmatched_right.parquet

library(here)
library(dplyr)
library(readr)
library(arrow)

source(here("scripts", "00_config.R"))
source(here("scripts", "00_utils.R"))

panel <- read_parquet(here("data", "quota_representation", "quota_representation_gp_raj_2015_2020.parquet"))
pai <- read_parquet(here("data", "pai", "pai_gp_raj_2022_2024.parquet")) |>
    filter(.data$theme_slug == PAI_T8_SLUG)

# =============================================================================
# PAI 1.0: direct LGD GP code
# =============================================================================

pai_1 <- pai |>
    filter(.data$year == PAI_YEAR_REPLICATION) |>
    transmute(
        pai_year = .data$year,
        pai_row_key = .data$pai_row_key,
        pai_gp_code = .data$gp_code,
        pai_district = .data$district,
        pai_block = .data$block,
        pai_gp_name = .data$gp_name,
        pai_good_governance_score = .data$score,
        theme_slug = .data$theme_slug
    )

assert_unique(pai_1, "pai_gp_code", "PAI 1.0 Good Governance rows")

joined_1 <- panel |>
    left_join(
        pai_1,
        by = join_by(raw_lgd_gp_code == pai_gp_code),
        relationship = "many-to-one"
    ) |>
    mutate(
        pai_year = PAI_YEAR_REPLICATION,
        theme_slug = PAI_T8_SLUG,
        pai_link_method = if_else(
            !is.na(.data$pai_good_governance_score), "direct_lgd_code", NA_character_
        )
    )

# =============================================================================
# PAI 2.0: direct LGD GP code, then approved groups and exact GP names
# =============================================================================

pai_2 <- pai |>
    filter(.data$year == PAI_YEAR_PRIMARY) |>
    transmute(
        pai_year = .data$year,
        pai_row_key = .data$pai_row_key,
        pai_gp_code = .data$gp_code,
        pai_district = .data$district,
        pai_block = .data$block,
        pai_gp_name = .data$gp_name,
        pai_district_std = .data$district_std,
        pai_block_std = .data$block_std,
        pai_gp_name_std = .data$gp_name_std,
        pai_good_governance_score = .data$score,
        theme_slug = .data$theme_slug
    )

assert_unique(pai_2, "pai_row_key", "PAI 2.0 Good Governance rows")
assert_unique(
    pai_2,
    c("pai_district_std", "pai_block_std", "pai_gp_name_std"),
    "PAI 2.0 normalized name keys"
)

pai_groups <- pai_2 |>
    distinct(.data$pai_district_std, .data$pai_block_std) |>
    mutate(exact_group = TRUE)

group_overrides <- read_csv(
    here("data", "crosswalks", "active", "pai2_group_overrides.csv"),
    col_types = cols(.default = col_character()),
    na = character(),
    show_col_types = FALSE
)

assert_unique(
    group_overrides,
    c("left_district_std", "left_block_std"),
    "PAI 2.0 group review list"
)

bad_targets <- group_overrides |>
    anti_join(
        pai_groups,
        by = c(
            "pai_district_std" = "pai_district_std",
            "pai_block_std" = "pai_block_std"
        )
    )
if (nrow(bad_targets) > 0L) {
    stop("A proposed group override targets a group absent from PAI 2.0", call. = FALSE)
}

approved_groups <- group_overrides |>
    filter(.data$status == "approved") |>
    select(
        left_district_std,
        left_block_std,
        override_district_std = pai_district_std,
        override_block_std = pai_block_std
    )

panel_groups <- panel |>
    mutate(
        link_name_source = if_else(!is.na(.data$lgd_gp_name_std), "lgd", "election"),
        left_district_std = coalesce(.data$lgd_district_std, .data$election_district_std),
        left_block_std = coalesce(.data$lgd_block_std, .data$election_block_std),
        left_gp_name_std = coalesce(.data$lgd_gp_name_std, .data$election_gp_name_std)
    ) |>
    left_join(
        pai_groups,
        by = join_by(
            left_district_std == pai_district_std,
            left_block_std == pai_block_std
        ),
        relationship = "many-to-one"
    ) |>
    left_join(
        approved_groups,
        by = join_by(left_district_std, left_block_std),
        relationship = "many-to-one"
    ) |>
    mutate(
        canonical_district_std = if_else(
            coalesce(.data$exact_group, FALSE),
            .data$left_district_std,
            .data$override_district_std
        ),
        canonical_block_std = if_else(
            coalesce(.data$exact_group, FALSE),
            .data$left_block_std,
            .data$override_block_std
        ),
        group_link_method = case_when(
            .data$exact_group ~ "exact_normalized_group",
            !is.na(.data$override_block_std) ~ "reviewed_group_override",
            TRUE ~ NA_character_
        )
    ) |>
    select(-"exact_group", -"override_district_std", -"override_block_std")

assert_unique(pai_2, "pai_gp_code", "PAI 2.0 GP codes")
# A code whose PAI name is not the LGD name is doubtful (a portal code swap or
# a rename); such links are dropped, not adjudicated.
code_candidates <- panel_groups |>
    filter(!is.na(.data$raw_lgd_gp_code)) |>
    inner_join(
        pai_2 |> select("pai_row_key", "pai_gp_code", "pai_gp_name", "pai_gp_name_std"),
        by = join_by(raw_lgd_gp_code == pai_gp_code),
        relationship = "many-to-one"
    ) |>
    mutate(name_agrees = .data$lgd_gp_name_std == .data$pai_gp_name_std)
code_name_conflicts <- bind_rows(
    joined_1 |>
        filter(
            !is.na(.data$pai_good_governance_score),
            normalize_name(.data$pai_gp_name) != .data$lgd_gp_name_std
        ) |>
        transmute(
            pai_year = PAI_YEAR_REPLICATION,
            election_gp_key = .data$election_gp_key,
            raw_lgd_gp_code = .data$raw_lgd_gp_code,
            raw_lgd_gp_name = .data$raw_lgd_gp_name,
            pai_gp_name = .data$pai_gp_name,
            pai_row_key = .data$pai_row_key
        ),
    code_candidates |>
        filter(!.data$name_agrees) |>
        transmute(
            pai_year = PAI_YEAR_PRIMARY,
            election_gp_key = .data$election_gp_key,
            raw_lgd_gp_code = .data$raw_lgd_gp_code,
            raw_lgd_gp_name = .data$raw_lgd_gp_name,
            pai_gp_name = .data$pai_gp_name,
            pai_row_key = .data$pai_row_key
        )
)
joined_1 <- joined_1 |>
    mutate(
        drop_link = .data$election_gp_key %in%
            code_name_conflicts$election_gp_key[
                code_name_conflicts$pai_year == PAI_YEAR_REPLICATION
            ],
        across(starts_with("pai_") & !all_of("pai_year"), \(x) if_else(drop_link, NA, x))
    ) |>
    select(-"drop_link")
code_links <- code_candidates |>
    filter(.data$name_agrees) |>
    add_count(.data$pai_row_key, name = "right_candidates") |>
    filter(.data$right_candidates == 1L) |>
    transmute(
        election_gp_key = .data$election_gp_key,
        pai_row_key = .data$pai_row_key,
        pai_link_method = "direct_lgd_gp_code"
    )

official_candidates <- panel_groups |>
    anti_join(code_links, by = "election_gp_key") |>
    left_join(
        pai_2 |> select("pai_row_key", "pai_district_std", "pai_block_std", "pai_gp_name_std"),
        by = join_by(
            canonical_district_std == pai_district_std,
            canonical_block_std == pai_block_std,
            lgd_gp_name_std == pai_gp_name_std
        ),
        relationship = "many-to-one"
    )

official_links <- official_candidates |>
    filter(
        !is.na(.data$pai_row_key),
        !.data$pai_row_key %in% code_links$pai_row_key
    ) |>
    add_count(.data$pai_row_key, name = "right_candidates") |>
    filter(.data$right_candidates == 1L) |>
    transmute(
        election_gp_key = .data$election_gp_key,
        pai_row_key = .data$pai_row_key,
        pai_link_method = "exact_official_gp_name"
    )

election_candidates <- panel_groups |>
    anti_join(code_links, by = "election_gp_key") |>
    anti_join(official_links, by = "election_gp_key") |>
    left_join(
        pai_2 |> select("pai_row_key", "pai_district_std", "pai_block_std", "pai_gp_name_std"),
        by = join_by(
            canonical_district_std == pai_district_std,
            canonical_block_std == pai_block_std,
            election_gp_name_std == pai_gp_name_std
        ),
        relationship = "many-to-one"
    )

election_links <- election_candidates |>
    filter(
        !is.na(.data$pai_row_key),
        !.data$pai_row_key %in% c(code_links$pai_row_key, official_links$pai_row_key)
    ) |>
    add_count(.data$pai_row_key, name = "right_candidates") |>
    filter(.data$right_candidates == 1L) |>
    transmute(
        election_gp_key = .data$election_gp_key,
        pai_row_key = .data$pai_row_key,
        pai_link_method = "exact_election_gp_name"
    )

exact_links <- bind_rows(code_links, official_links, election_links)
assert_unique(exact_links, "election_gp_key", "Accepted exact PAI 2.0 links")
assert_unique(exact_links, "pai_row_key", "Accepted exact PAI 2.0 targets")

joined_2 <- panel_groups |>
    left_join(exact_links, by = join_by(election_gp_key), relationship = "one-to-one") |>
    left_join(pai_2, by = join_by(pai_row_key), relationship = "many-to-one") |>
    mutate(
        pai_year = PAI_YEAR_PRIMARY,
        theme_slug = PAI_T8_SLUG
    ) |>
    arrange(.data$election_gp_key)

# Reviewed GP-level links are the only fuzzy links allowed into the joined file.
gp_overrides <- read_csv(
    here("data", "crosswalks", "active", "pai2_gp_overrides.csv"),
    col_types = cols(.default = col_character()),
    na = character(),
    show_col_types = FALSE
) |>
    filter(.data$decision == "approved")

if (nrow(gp_overrides) > 0L) {
    assert_unique(gp_overrides, "election_gp_key", "Reviewed PAI 2.0 GP links")
    assert_unique(gp_overrides, "pai_row_key", "Reviewed PAI 2.0 GP targets")
    if (any(gp_overrides$election_gp_key %in% code_links$election_gp_key)) {
        stop("A reviewed GP link would override a direct LGD code link", call. = FALSE)
    }
    override_values <- gp_overrides |>
        select(.data$election_gp_key, .data$pai_row_key) |>
        left_join(pai_2, by = join_by(pai_row_key), relationship = "many-to-one")
    if (any(is.na(override_values$pai_good_governance_score))) {
        stop("A reviewed GP link targets a missing PAI row", call. = FALSE)
    }
    replace_keys <- override_values$election_gp_key
    joined_2 <- bind_rows(
        joined_2 |> filter(!.data$election_gp_key %in% replace_keys),
        panel_groups |>
            filter(.data$election_gp_key %in% replace_keys) |>
            left_join(
                override_values,
                by = join_by(election_gp_key),
                relationship = "one-to-one"
            ) |>
            mutate(
                pai_link_method = "reviewed_fuzzy_gp_name",
                pai_year = PAI_YEAR_PRIMARY,
                theme_slug = PAI_T8_SLUG
            )
    ) |>
        arrange(.data$election_gp_key)
}

if (nrow(joined_1) != nrow(panel) || nrow(joined_2) != nrow(panel)) {
    stop("The PAI join did not conserve election-panel rows", call. = FALSE)
}
assert_unique(joined_1, "election_gp_key", "PAI 1.0 joined panel")
assert_unique(joined_2, "election_gp_key", "PAI 2.0 joined panel")

matched_pai2 <- joined_2$pai_row_key[!is.na(joined_2$pai_row_key)]
if (anyDuplicated(matched_pai2)) {
    stop("More than one election GP links to the same PAI 2.0 GP", call. = FALSE)
}

joined <- bind_rows(joined_1, joined_2) |>
    mutate(pai_available = !is.na(.data$pai_good_governance_score))

coverage <- joined |>
    group_by(.data$pai_year, .data$an_women_reserved) |>
    summarise(
        election_gps = n(),
        pai_matched = sum(.data$pai_available),
        match_rate = mean(.data$pai_available),
        .groups = "drop"
    )

assignment_support <- joined |>
    filter(.data$pai_available) |>
    group_by(.data$pai_year, .data$assignment_stratum) |>
    summarise(
        gps = n(),
        women_reserved = sum(.data$an_women_reserved == 1L),
        open = sum(.data$an_women_reserved == 0L),
        informative = .data$women_reserved > 0L & .data$open > 0L,
        .groups = "drop"
    ) |>
    group_by(.data$pai_year) |>
    summarise(
        linked_gps = sum(.data$gps),
        observed_strata = n(),
        informative_strata = sum(.data$informative),
        gps_in_informative_strata = sum(.data$gps[.data$informative]),
        .groups = "drop"
    )

unmatched_left <- joined_2 |>
    filter(
        is.na(.data$pai_good_governance_score),
        !is.na(.data$canonical_district_std),
        !is.na(.data$canonical_block_std),
        !is.na(.data$left_gp_name_std)
    ) |>
    transmute(
        election_gp_key = .data$election_gp_key,
        canonical_group = paste(
            .data$canonical_district_std, .data$canonical_block_std, sep = "__"
        ),
        gp_name = .data$left_gp_name_std,
        election_gp_name = .data$election_gp_name_std,
        official_gp_name = .data$lgd_gp_name_std,
        raw_district = .data$raw_district_2020,
        raw_block = .data$raw_block_2020,
        raw_gp_name = .data$raw_gp_name_2020
    )

unmatched_right <- pai_2 |>
    filter(!.data$pai_row_key %in% matched_pai2) |>
    transmute(
        pai_row_key = .data$pai_row_key,
        canonical_group = paste(.data$pai_district_std, .data$pai_block_std, sep = "__"),
        gp_name = .data$pai_gp_name_std,
        pai_district = .data$pai_district,
        pai_block = .data$pai_block,
        pai_gp_name = .data$pai_gp_name
    )

group_status <- group_overrides |>
    count(.data$status, name = "groups")

write_parquet_receipt(
    joined,
    here("data", "quota_governance", "quota_governance_gp_raj_2022_2024.parquet")
)
write_parquet_receipt(
    unmatched_left,
    here("data", "crosswalks", "audit", "pai2_unmatched_left.parquet")
)
write_parquet_receipt(
    unmatched_right,
    here("data", "crosswalks", "audit", "pai2_unmatched_right.parquet")
)
write_csv_receipt(
    code_name_conflicts,
    here("data", "crosswalks", "audit", "pai_code_name_conflicts.csv")
)
write_csv_receipt(
    coverage,
    here("data", "crosswalks", "audit", "pai_coverage_by_treatment.csv")
)
write_csv_receipt(
    assignment_support,
    here("data", "crosswalks", "audit", "pai_assignment_support.csv")
)
write_csv_receipt(
    group_status,
    here("data", "crosswalks", "audit", "pai2_group_review_status.csv")
)
