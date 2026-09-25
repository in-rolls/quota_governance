# Estimate the Mumbai (BMC) reserved-seat effect on Praja citizen ratings.
# Output: tabs/bmc_praja_effects.csv, tabs/bmc_praja_effects.tex,
#         tabs/bmc_praja_effects_macros.tex, tabs/bmc_praja_items.csv,
#         tabs/bmc_praja_activity.csv, figs/bmc_praja_effects.pdf,
#         figs/bmc_praja_items.pdf

library(arrow)
library(clubSandwich)
library(dplyr)
library(estimatr)
library(ggplot2)
library(here)
library(readr)
library(tidyr)

source(here("scripts", "00_config.R"))
source(here("scripts", "00_utils.R"))

RI_REPETITIONS_BMC <- 4999L
RI_SEED_BMC <- 20260903L

compile_stratified_simulator()

extract_term <- function(model, term) {
    index <- match(term, model$term)
    if (is.na(index)) {
        stop("Model does not contain term: ", term, call. = FALSE)
    }
    c(
        estimate = model$coefficients[[index]],
        std_error = model$std.error[[index]],
        conf_low = model$conf.low[[index]],
        conf_high = model$conf.high[[index]],
        p_value = model$p.value[[index]]
    )
}

informative_sample <- function(data) {
    informative <- data |>
        group_by(.data$assignment_stratum) |>
        summarise(
            treatment_levels = n_distinct(.data$an_women_reserved),
            .groups = "drop"
        ) |>
        filter(.data$treatment_levels == 2L)
    data |>
        semi_join(informative, by = join_by(assignment_stratum))
}

randomization_p_value <- function(data, outcome, repetitions, seed) {
    blocks <- data$assignment_stratum
    treatment <- data$an_women_reserved
    block_factor <- factor(blocks)
    block_id <- as.integer(block_factor) - 1L
    treatment_counts <- as.integer(tapply(treatment, block_factor, sum))

    outcome_centered <- outcome - ave(outcome, blocks)
    treatment_centered <- treatment - ave(treatment, blocks)
    denominator <- sum(treatment_centered^2)
    observed <- sum(treatment_centered * outcome_centered) / denominator
    simulated <- simulate_stratified_statistics(
        outcome_centered,
        block_id,
        treatment_counts,
        repetitions,
        seed
    ) / denominator

    list(
        estimate = observed,
        p_value = (1 + sum(abs(simulated) >= abs(observed))) /
            (1 + length(simulated)),
        repetitions = length(simulated)
    )
}

# One estimate: stratum fixed effects with HC2, CR2 by block, fixed-count RI.
estimate <- function(data, outcome_name, label, seed) {
    analysis <- data |>
        filter(!is.na(.data[[outcome_name]])) |>
        informative_sample()
    assert_unique(analysis, c("council", "ward_no", "survey_year"), label)
    formula <- as.formula(paste(outcome_name, "~ an_women_reserved"))

    message(label, ": fitting raw and HC2 stratum models")
    raw_model <- lm_robust(formula, data = analysis, se_type = "HC2")
    strata_model <- lm_robust(
        formula,
        data = analysis,
        fixed_effects = ~ assignment_stratum,
        se_type = "HC2"
    )
    block_data <- analysis |>
        group_by(.data$assignment_stratum) |>
        mutate(
            outcome_centered = .data[[outcome_name]] - mean(.data[[outcome_name]]),
            treatment_centered = .data$an_women_reserved - mean(.data$an_women_reserved)
        ) |>
        ungroup()
    block_model <- lm(outcome_centered ~ treatment_centered - 1, data = block_data)
    block_vcov <- vcovCR(block_model, cluster = block_data$assignment_block, type = "CR2")
    block_test <- coef_test(block_model, vcov = block_vcov, test = "Satterthwaite")

    randomization <- randomization_p_value(
        analysis,
        outcome = analysis[[outcome_name]],
        repetitions = RI_REPETITIONS_BMC,
        seed = seed
    )
    raw <- extract_term(raw_model, "an_women_reserved")
    strata <- extract_term(strata_model, "an_women_reserved")
    if (!isTRUE(all.equal(
        unname(strata[["estimate"]]),
        randomization$estimate,
        tolerance = 1e-8
    ))) {
        stop(label, ": regression and randomization statistics disagree", call. = FALSE)
    }
    block_critical <- qt(0.975, df = block_test$df_Satt[[1]])
    control <- analysis[[outcome_name]][analysis$an_women_reserved == 0L]
    control_sd <- sd(control)

    tibble(
        sample = label,
        outcome = outcome_name,
        n = nrow(analysis),
        informative_strata = n_distinct(analysis$assignment_stratum),
        assignment_blocks = n_distinct(analysis$assignment_block),
        control_mean = mean(control),
        control_sd = control_sd,
        raw_difference = raw[["estimate"]],
        strata_adjusted_difference = strata[["estimate"]],
        hc2_std_error = strata[["std_error"]],
        hc2_conf_low = strata[["conf_low"]],
        hc2_conf_high = strata[["conf_high"]],
        hc2_p_value = strata[["p_value"]],
        cr2_std_error = block_test$SE[[1]],
        cr2_conf_low = block_test$beta[[1]] - block_critical * block_test$SE[[1]],
        cr2_conf_high = block_test$beta[[1]] + block_critical * block_test$SE[[1]],
        cr2_p_value = block_test$p_Satt[[1]],
        difference_sd = strata[["estimate"]] / control_sd,
        hc2_conf_low_sd = strata[["conf_low"]] / control_sd,
        hc2_conf_high_sd = strata[["conf_high"]] / control_sd,
        randomization_p_value = randomization$p_value,
        randomization_repetitions = randomization$repetitions
    )
}

frame <- read_parquet(here("data", "bmc", "quota_governance_bmc_2007_2017.parquet"))
primary <- frame |> filter(.data$survey_year %in% BMC_PRIMARY_WAVES)

results <- bind_rows(
    estimate(
        primary,
        "an_rating_index14",
        "14-item index (primary)",
        RI_SEED_BMC
    ),
    estimate(
        primary |> filter(.data$survey_year != "2011"),
        "an_rating_index18",
        "18-item index, 2012 and 2017",
        RI_SEED_BMC + 1L
    ),
    estimate(
        primary |> filter(.data$an_women_reserved == .data$deposit_women_reserved),
        "an_rating_index14",
        "14-item index, disputed ward dropped",
        RI_SEED_BMC + 2L
    )
)

if (nrow(results) != 3L || any(results$n > nrow(primary))) {
    stop("BMC result rows violate the analysis contract", call. = FALSE)
}
write_csv_receipt(results, here("tabs", "bmc_praja_effects.csv"))

# Exploratory: item by item, and the two activity measures, same specification
# without randomization inference. Labeled exploratory in the design record.
item_estimate <- function(data, column, label) {
    analysis <- data |>
        filter(!is.na(.data[[column]])) |>
        group_by(.data$survey_year) |>
        mutate(z = (.data[[column]] - mean(.data[[column]])) / sd(.data[[column]])) |>
        ungroup() |>
        informative_sample()
    model <- lm_robust(
        z ~ an_women_reserved,
        data = analysis,
        fixed_effects = ~ assignment_stratum,
        se_type = "HC2"
    )
    term <- extract_term(model, "an_women_reserved")
    tibble(
        item = label,
        n = nrow(analysis),
        difference_sd = term[["estimate"]],
        hc2_conf_low_sd = term[["conf_low"]],
        hc2_conf_high_sd = term[["conf_high"]],
        hc2_p_value = term[["p_value"]]
    )
}
items <- bind_rows(
    lapply(BMC_INDEX18_ITEMS, function(item) {
        item_estimate(primary, paste0("raw_rating_", item), item)
    }),
    item_estimate(
        primary |> filter(.data$survey_year != "2018"),
        "an_rating_satisfaction",
        "satisfaction (2016 only; 2018 inverted, 2011 not asked)"
    )
) |>
    arrange(.data$difference_sd)
write_csv_receipt(items, here("tabs", "bmc_praja_items.csv"))

activity <- bind_rows(
    item_estimate(primary, "attendance_ward_committee", "ward-committee attendance share"),
    item_estimate(primary, "attendance_general_body", "general-body attendance share"),
    item_estimate(primary, "questions_total", "questions asked in council")
)
write_csv_receipt(activity, here("tabs", "bmc_praja_activity.csv"))

format_number <- function(x, digits = 2L) {
    formatC(x, digits = digits, format = "f")
}
main <- results[1, ]
write_tex_macros(
    c(
        BmcN = format(main$n, big.mark = ",", scientific = FALSE),
        BmcStrata = format(main$informative_strata),
        BmcDifferenceSD = format_number(main$difference_sd, 3L),
        BmcCILowSD = format_number(main$hc2_conf_low_sd, 3L),
        BmcCIHighSD = format_number(main$hc2_conf_high_sd, 3L),
        BmcRIP = format_number(main$randomization_p_value, 3L),
        BmcCRTwoCILowSD = format_number(main$cr2_conf_low / main$control_sd, 3L),
        BmcCRTwoCIHighSD = format_number(main$cr2_conf_high / main$control_sd, 3L),
        BmcEighteenDifferenceSD = format_number(results$difference_sd[2], 3L),
        BmcEighteenCILowSD = format_number(results$hc2_conf_low_sd[2], 3L),
        BmcEighteenCIHighSD = format_number(results$hc2_conf_high_sd[2], 3L)
    ),
    here("tabs", "bmc_praja_effects_macros.tex")
)

tex_rows <- results |>
    mutate(
        row = paste0(
            .data$sample,
            " & ", format(.data$n, big.mark = ",", scientific = FALSE),
            " & ", format_number(.data$difference_sd, 3L),
            " & [", format_number(.data$hc2_conf_low_sd, 3L),
            ", ", format_number(.data$hc2_conf_high_sd, 3L), "]",
            " & ", format_number(.data$randomization_p_value, 3L),
            " \\\\"
        )
    ) |>
    pull(.data$row)
tex <- c(
    "\\begin{tabular}{lrrrr}",
    "\\toprule",
    "Sample & $N$ & Diff./SD & 95\\% CI & RI $p$ \\\\",
    "\\midrule",
    tex_rows,
    "\\bottomrule",
    "\\end{tabular}",
    paste0(
        "\\parbox{\\linewidth}{\\scriptsize \\emph{Notes:} Mumbai (BMC) wards, one Praja ",
        "survey wave per council (2011, 2016, 2018). The outcome is the mean of the ",
        "within-wave standardised citizen ratings; differences are in control-group ",
        "standard deviations from an unweighted regression with lottery-pool fixed ",
        "effects and HC2 intervals. RI uses fixed treatment counts within pools.}"
    )
)
dir.create(here("tabs"), showWarnings = FALSE)
writeLines(tex, here("tabs", "bmc_praja_effects.tex"))

figure <- results |>
    mutate(sample = factor(.data$sample, levels = rev(.data$sample))) |>
    ggplot(aes(x = .data$difference_sd, y = .data$sample)) +
    geom_vline(xintercept = 0, linetype = "dashed", color = COLORS_PUB[["secondary"]]) +
    geom_errorbar(
        aes(xmin = .data$hc2_conf_low_sd, xmax = .data$hc2_conf_high_sd),
        orientation = "y",
        width = 0.15,
        color = COLORS_PUB[["primary"]]
    ) +
    geom_point(size = 2.5, color = COLORS_PUB[["accent"]]) +
    labs(
        x = "Reserved-seat difference (control-group SDs)",
        y = NULL,
        title = "Reserved seats and citizen ratings, Mumbai",
        subtitle = "One wave per council; lottery-pool FE, HC2 95% intervals"
    ) +
    theme_pub()
dir.create(here("figs"), showWarnings = FALSE)
ggsave(
    here("figs", "bmc_praja_effects.pdf"),
    figure,
    width = FIG_WIDTH_FULL,
    height = 2.8,
    device = cairo_pdf
)

item_figure <- items |>
    mutate(item = factor(.data$item, levels = .data$item)) |>
    ggplot(aes(x = .data$difference_sd, y = .data$item)) +
    geom_vline(xintercept = 0, linetype = "dashed", color = COLORS_PUB[["secondary"]]) +
    geom_errorbar(
        aes(xmin = .data$hc2_conf_low_sd, xmax = .data$hc2_conf_high_sd),
        orientation = "y",
        width = 0,
        color = COLORS_PUB[["primary"]]
    ) +
    geom_point(size = 2, color = COLORS_PUB[["accent"]]) +
    labs(
        x = "Reserved-seat difference (within-wave SDs of the item)",
        y = NULL,
        title = "By Praja item (exploratory)",
        subtitle = "Same specification, no multiplicity adjustment"
    ) +
    theme_pub()
ggsave(
    here("figs", "bmc_praja_items.pdf"),
    item_figure,
    width = FIG_WIDTH_FULL,
    height = 5.5,
    device = cairo_pdf
)

print(results, width = Inf)
print(items, n = Inf, width = Inf)
print(activity, width = Inf)
message("BMC Praja analysis completed.")
