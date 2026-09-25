# 01c_pai2_group_audit.R
# Audit every proposed election-to-PAI district-block mapping without outcomes.
# Output: data/crosswalks/audit/pai2_group_mapping_audit.csv

library(here)
library(dplyr)
library(readr)
library(arrow)

source(here("scripts", "00_config.R"))
source(here("scripts", "00_utils.R"))

panel <- read_parquet(
    here("data", "quota_representation", "quota_representation_gp_raj_2015_2020.parquet")
) |>
    select(
        left_district_std = election_district_std,
        left_block_std = election_block_std,
        left_gp_name_std = election_gp_name_std
    )

pai <- read_parquet(here("data", "pai", "pai_gp_raj_2022_2024.parquet")) |>
    filter(
        .data$year == PAI_YEAR_PRIMARY,
        .data$theme_slug == PAI_T8_SLUG
    ) |>
    select(
        pai_district_std = district_std,
        pai_block_std = block_std,
        pai_gp_name_std = gp_name_std
    )

groups <- read_csv(
    here("data", "crosswalks", "active", "pai2_group_overrides.csv"),
    col_types = cols(.default = col_character()),
    na = character(),
    show_col_types = FALSE
)

left_counts <- panel |>
    count(.data$left_district_std, .data$left_block_std, name = "left_gp_count")

right_counts <- pai |>
    count(.data$pai_district_std, .data$pai_block_std, name = "pai_gp_count")

same_block_candidates <- pai |>
    distinct(.data$pai_district_std, .data$pai_block_std) |>
    count(.data$pai_block_std, name = "same_block_candidates_statewide")

overlaps <- groups |>
    select(
        left_district_std,
        left_block_std,
        pai_district_std,
        pai_block_std
    ) |>
    left_join(panel, by = join_by(left_district_std, left_block_std)) |>
    inner_join(
        pai,
        by = join_by(
            pai_district_std,
            pai_block_std,
            left_gp_name_std == pai_gp_name_std
        )
    ) |>
    count(
        .data$left_district_std,
        .data$left_block_std,
        .data$pai_district_std,
        .data$pai_block_std,
        name = "exact_gp_name_overlap"
    )

audit <- groups |>
    left_join(left_counts, by = join_by(left_district_std, left_block_std)) |>
    left_join(right_counts, by = join_by(pai_district_std, pai_block_std)) |>
    left_join(overlaps, by = join_by(
        left_district_std,
        left_block_std,
        pai_district_std,
        pai_block_std
    )) |>
    left_join(
        same_block_candidates,
        by = join_by(left_block_std == pai_block_std)
    ) |>
    mutate(
        exact_gp_name_overlap = coalesce(.data$exact_gp_name_overlap, 0L),
        overlap_share_left = .data$exact_gp_name_overlap / .data$left_gp_count,
        overlap_share_pai = .data$exact_gp_name_overlap / .data$pai_gp_count,
        target_exists = !is.na(.data$pai_gp_count)
    ) |>
    relocate(
        left_gp_count,
        pai_gp_count,
        exact_gp_name_overlap,
        overlap_share_left,
        overlap_share_pai,
        same_block_candidates_statewide,
        target_exists,
        .after = pai_block_std
    )

if (!all(audit$target_exists)) {
    stop("At least one reviewed group targets a group absent from PAI", call. = FALSE)
}

write_csv_receipt(
    audit,
    here("data", "crosswalks", "audit", "pai2_group_mapping_audit.csv")
)
