# Build the Mumbai (BMC) ward-by-survey-wave analysis frame from local_elections.
# Output: data/bmc/quota_governance_bmc_2007_2017.parquet,
#         data/bmc/bmc_profile.csv

library(arrow)
library(dplyr)
library(here)
library(readr)
library(tidyr)

source(here("scripts", "00_config.R"))
source(here("scripts", "00_utils.R"))

read_pinned <- function(rel) {
    read_csv(
        resolve_reservations_file(rel),
        col_types = cols(.default = col_character()),
        show_col_types = FALSE
    )
}

message("Reading the seat reservation for each council")
# The 2007 council has only a women's flag (from the deposit's 2011 wave); the
# 2012 and 2017 councils carry the full category from the schema slices.
seats_2007 <- read_pinned("data/maharashtra/mumbai/bmc_seats_2007.csv") |>
    transmute(
        council = 2007L,
        ward_no = .data$ward_no,
        raw_reservation = .data$reservation_raw,
        raw_caste_reservation = NA_character_,
        an_women_reserved = as.integer(.data$woman_reserved),
        reservation_source = .data$reservation_source_path
    )
seats_later <- bind_rows(
    read_pinned("data/maharashtra/ulb_ward_2012.csv"),
    read_pinned("data/maharashtra/ulb_ward_2017.csv")
) |>
    transmute(
        council = as.integer(.data$year),
        ward_no = .data$ward_no,
        raw_reservation = .data$reservation,
        raw_caste_reservation = .data$caste_reservation,
        an_women_reserved = as.integer(.data$woman_reserved),
        reservation_source = .data$source_path
    )
seats <- bind_rows(seats_2007, seats_later)
assert_unique(seats, c("council", "ward_no"), "BMC seats")
assert_binary(seats$an_women_reserved, "an_women_reserved")
if (nrow(seats) != 3L * 227L) {
    stop("BMC seats do not cover three councils of 227 wards", call. = FALSE)
}

# The 2012 draw excluded wards reserved in 2007, so that is the pool it was
# drawn within. Wards were redrawn before 2017, so no prior status exists there.
prior <- seats |>
    filter(.data$council == 2007L) |>
    transmute(ward_no = .data$ward_no, prior_women_reserved = .data$an_women_reserved)
seats <- seats |>
    left_join(prior, by = join_by(ward_no)) |>
    mutate(
        prior_women_reserved = if_else(
            .data$council == 2012L, .data$prior_women_reserved, NA_integer_
        ),
        assignment_stratum = case_when(
            .data$council == 2012L ~ paste0("2012__prior", .data$prior_women_reserved),
            TRUE ~ as.character(.data$council)
        ),
        # ward geography is stable across 2007 and 2012 and redrawn for 2017
        assignment_block = if_else(
            .data$council == 2017L,
            paste0("2017__w", .data$ward_no),
            paste0("w", .data$ward_no)
        )
    )

message("Reading the Praja ward-by-wave ratings")
ratings <- read_pinned("data/maharashtra/mumbai/praja_ward_ratings_2011_2018.csv")
if (nrow(ratings) != 1361L) {
    stop("The pinned Praja ratings table should hold 1,361 ward-waves", call. = FALSE)
}
rating_columns <- grep("^rating_", names(ratings), value = TRUE)
rating_columns <- setdiff(rating_columns, "rating_flags")

frame <- ratings |>
    transmute(
        council = as.integer(.data$council),
        ward_no = .data$ward_no,
        survey_year = .data$survey_year,
        admin_ward = .data$adminward,
        deposit_women_reserved = as.integer(.data$woman_reserved),
        councillor = .data$councillor,
        councillor_woman = as.integer(.data$councillor_woman),
        councillor_party = .data$councillor_party,
        councillor_age = as.numeric(.data$councillor_age),
        councillor_education = .data$councillor_education,
        councillor_criminal_cases = as.numeric(.data$councillor_criminal_cases),
        attendance_general_body = as.numeric(.data$gbm_attended) / as.numeric(.data$total_gbms),
        attendance_ward_committee = as.numeric(.data$ward_attendance) /
            as.numeric(.data$total_ward_meetings),
        questions_total = as.numeric(.data$total_questions),
        slum_share = as.numeric(.data$slum),
        rating_flags = .data$rating_flags,
        across(all_of(rating_columns), as.numeric)
    ) |>
    rename_with(~ paste0("raw_", .x), all_of(rating_columns))

# The satisfaction item is inverted in the 2018 wave (see docs/design.md); it is
# kept raw and blanked in the analysis copy rather than flipped.
frame <- frame |>
    mutate(
        an_rating_satisfaction = if_else(
            grepl("satisfaction_inverted", .data$rating_flags, fixed = TRUE),
            NA_real_,
            .data$raw_rating_satisfaction
        )
    )

zscore <- function(x) (x - mean(x, na.rm = TRUE)) / sd(x, na.rm = TRUE)
index_over <- function(data, items) {
    columns <- paste0("raw_rating_", items)
    z <- data |>
        group_by(.data$survey_year) |>
        mutate(across(all_of(columns), zscore)) |>
        ungroup() |>
        select(all_of(columns))
    complete <- rowSums(is.na(z)) == 0L
    if_else(complete, rowMeans(as.matrix(z)), NA_real_)
}
frame <- frame |>
    mutate(
        an_rating_index14 = index_over(frame, BMC_INDEX14_ITEMS),
        an_rating_index18 = index_over(frame, BMC_INDEX18_ITEMS)
    )

joined <- frame |>
    inner_join(seats, by = join_by(council, ward_no))
if (nrow(joined) != nrow(frame)) {
    stop("Every Praja ward-wave should match one seat reservation", call. = FALSE)
}
assert_unique(joined, c("council", "ward_no", "survey_year"), "BMC ward-waves")
assert_binary(joined$an_women_reserved, "an_women_reserved")

waves <- joined |> count(.data$survey_year)
if (!setequal(waves$survey_year, c("2011", "2013", "2014", "2015", "2016", "2018")) ||
        any(waves$n < 226L | waves$n > 227L)) {
    stop("BMC ward-waves violate the six-wave contract", call. = FALSE)
}
if (any(is.na(joined$an_rating_index14))) {
    stop("The 14-item index should be complete in every wave", call. = FALSE)
}

dir.create(here("data", "bmc"), showWarnings = FALSE)
write_parquet_receipt(joined, here("data", "bmc", "quota_governance_bmc_2007_2017.parquet"))

profile <- joined |>
    group_by(.data$council, .data$survey_year) |>
    summarise(
        wards = n(),
        women_reserved = sum(.data$an_women_reserved),
        deposit_disagreements = sum(.data$an_women_reserved != .data$deposit_women_reserved),
        women_councillors = sum(.data$councillor_woman),
        index14_mean_open = mean(.data$an_rating_index14[.data$an_women_reserved == 0L]),
        index14_mean_reserved = mean(.data$an_rating_index14[.data$an_women_reserved == 1L]),
        index18_available = sum(!is.na(.data$an_rating_index18)),
        satisfaction_available = sum(!is.na(.data$an_rating_satisfaction)),
        .groups = "drop"
    )
write_csv_receipt(profile, here("data", "bmc", "bmc_profile.csv"))
print(profile, width = Inf)
message("BMC analysis frame prepared.")
