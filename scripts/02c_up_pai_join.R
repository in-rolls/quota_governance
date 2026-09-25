# Link the UP 2021 reservation table to both PAI waves.
# Output: data/quota_governance/quota_governance_gp_up_2022_2024.parquet and linkage audits.

library(arrow)
library(dplyr)
library(here)
library(readr)

source(here("scripts", "00_config.R"))
source(here("scripts", "00_utils.R"))

panel <- read_parquet(here("data", "up", "up_gp_2021.parquet"))
pai <- read_parquet(here("data", "pai", "pai_gp_up_2022_2024.parquet")) |>
    filter(.data$theme_slug == PAI_T8_SLUG) |>
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

assert_unique(pai, "pai_row_key", "UP PAI Good Governance rows")

normalized_collisions <- pai |>
    count(
        .data$pai_year, .data$pai_district_std, .data$pai_block_std,
        .data$pai_gp_name_std, name = "normalized_key_n"
    ) |>
    filter(.data$normalized_key_n > 1L)

pai_unique_names <- pai |>
    anti_join(
        normalized_collisions,
        by = c(
            "pai_year", "pai_district_std", "pai_block_std", "pai_gp_name_std"
        )
    )

link_one_year <- function(year) {
    pai_all <- pai |> filter(.data$pai_year == year)
    pai_year <- pai_unique_names |> filter(.data$pai_year == year)

    # Both PAI vintages carry LGD GP codes, so the reviewed election-to-LGD
    # link joins directly. Name passes only serve rows without an LGD link.
    code_rows <- pai_all |> filter(!is.na(.data$pai_gp_code))
    assert_unique(code_rows, "pai_gp_code", paste(year, "PAI GP codes"))
    code_candidates <- panel |>
        filter(!is.na(.data$raw_lgd_gp_code)) |>
        inner_join(
            code_rows |> select("pai_row_key", "pai_gp_code", "pai_gp_name_std"),
            by = join_by(raw_lgd_gp_code == pai_gp_code),
            relationship = "one-to-one"
        ) |>
        mutate(
            official_gp_name_std = normalize_name(.data$raw_lgd_gp_name),
            name_agrees = .data$official_gp_name_std == .data$pai_gp_name_std
        )
    # A code whose PAI name is not the LGD name is doubtful (a portal code
    # swap or a rename); such links are dropped, not adjudicated.
    code_name_conflicts <- code_candidates |>
        filter(!.data$name_agrees) |>
        transmute(
            pai_year = year,
            election_gp_key = .data$election_gp_key,
            raw_lgd_gp_code = .data$raw_lgd_gp_code,
            raw_lgd_gp_name = .data$raw_lgd_gp_name,
            raw_gp_name_2021 = .data$raw_gp_name_2021,
            pai_row_key = .data$pai_row_key
        )
    direct_code_links <- code_candidates |>
        filter(.data$name_agrees) |>
        transmute(
            election_gp_key = .data$election_gp_key,
            pai_row_key = .data$pai_row_key,
            pai_link_method = "direct_lgd_gp_code"
        )

    official_name_links <- panel |>
        filter(
            !.data$election_gp_key %in% direct_code_links$election_gp_key,
            !is.na(.data$raw_lgd_gp_name)
        ) |>
        mutate(official_gp_name_std = normalize_name(.data$raw_lgd_gp_name)) |>
        inner_join(
            pai_year |>
                select(
                    "pai_row_key", "pai_district_std", "pai_block_std",
                    "pai_gp_name_std"
                ),
            by = join_by(
                election_district_std == pai_district_std,
                election_block_std == pai_block_std,
                official_gp_name_std == pai_gp_name_std
            ),
            relationship = "one-to-one"
        ) |>
        filter(!.data$pai_row_key %in% direct_code_links$pai_row_key) |>
        transmute(
            election_gp_key = .data$election_gp_key,
            pai_row_key = .data$pai_row_key,
            pai_link_method = "exact_official_gp_name"
        )

    prior_links <- bind_rows(direct_code_links, official_name_links)
    election_name_links <- panel |>
        filter(
            .data$link_eligible,
            !.data$election_gp_key %in% prior_links$election_gp_key
        ) |>
        inner_join(
            pai_year |>
                select(
                    "pai_row_key", "pai_district_std", "pai_block_std",
                    "pai_gp_name_std"
                ),
            by = join_by(
                election_district_std == pai_district_std,
                election_block_std == pai_block_std,
                election_gp_name_std == pai_gp_name_std
            ),
            relationship = "one-to-one"
        ) |>
        filter(!.data$pai_row_key %in% prior_links$pai_row_key) |>
        transmute(
            election_gp_key = .data$election_gp_key,
            pai_row_key = .data$pai_row_key,
            pai_link_method = "exact_election_gp_name"
        )

    links <- bind_rows(prior_links, election_name_links)
    assert_unique(links, "election_gp_key", paste(year, "UP election links"))
    assert_unique(links, "pai_row_key", paste(year, "UP PAI targets"))

    joined <- panel |>
        left_join(links, by = "election_gp_key", relationship = "one-to-one") |>
        left_join(pai_all, by = "pai_row_key", relationship = "many-to-one") |>
        mutate(
            pai_year = year,
            theme_slug = PAI_T8_SLUG,
            pai_available = !is.na(.data$pai_good_governance_score)
        )
    if (nrow(joined) != nrow(panel)) {
        stop(year, " PAI join did not conserve UP election rows", call. = FALSE)
    }
    assert_unique(joined, "election_gp_key", paste(year, "joined UP rows"))
    list(joined = joined, conflicts = code_name_conflicts)
}

linked <- list(
    link_one_year(PAI_YEAR_REPLICATION),
    link_one_year(PAI_YEAR_PRIMARY)
)
joined <- bind_rows(lapply(linked, `[[`, "joined"))
code_name_conflicts <- bind_rows(lapply(linked, `[[`, "conflicts"))

coverage <- joined |>
    group_by(.data$pai_year, .data$an_women_reserved) |>
    summarise(
        election_gps = n(),
        pai_matched = sum(.data$pai_available),
        match_rate = mean(.data$pai_available),
        .groups = "drop"
    )

method_profile <- joined |>
    count(.data$pai_year, .data$pai_link_method, name = "rows") |>
    mutate(pai_link_method = coalesce(.data$pai_link_method, "unmatched"))

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

unmatched_left <- joined |>
    filter(!.data$pai_available) |>
    select(
        "pai_year", "election_gp_key", "raw_district_2021", "raw_block_2021",
        "raw_gp_name_2021", "election_district_std", "election_block_std",
        "election_gp_name_std", "raw_lgd_gp_code", "raw_lgd_gp_name"
    )

matched_targets <- joined$pai_row_key[!is.na(joined$pai_row_key)]
unmatched_right <- pai |>
    filter(!.data$pai_row_key %in% matched_targets)

write_parquet_receipt(
    joined,
    here("data", "quota_governance", "quota_governance_gp_up_2022_2024.parquet")
)
write_csv_receipt(
    coverage,
    here("data", "crosswalks", "audit", "up_pai_coverage_by_treatment.csv")
)
write_csv_receipt(
    method_profile,
    here("data", "crosswalks", "audit", "up_pai_link_methods.csv")
)
write_csv_receipt(
    assignment_support,
    here("data", "crosswalks", "audit", "up_pai_assignment_support.csv")
)
write_csv_receipt(
    normalized_collisions,
    here("data", "crosswalks", "audit", "up_pai_normalized_collisions.csv")
)
write_csv_receipt(
    code_name_conflicts,
    here("data", "crosswalks", "audit", "up_pai_code_name_conflicts.csv")
)
write_parquet_receipt(
    unmatched_left,
    here("data", "crosswalks", "audit", "up_pai_unmatched_left.parquet")
)
write_parquet_receipt(
    unmatched_right,
    here("data", "crosswalks", "audit", "up_pai_unmatched_right.parquet")
)
