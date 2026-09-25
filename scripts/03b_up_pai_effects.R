# Estimate the frozen UP reservation association with PAI Good Governance.
# Output: tabs/up_pai_effects.csv, tabs/up_pai_effects.tex,
#         figs/up_pai_effects.pdf

library(arrow)
library(clubSandwich)
library(dplyr)
library(estimatr)
library(ggplot2)
library(here)
library(readr)

source(here("scripts", "00_config.R"))
source(here("scripts", "00_utils.R"))

RI_REPETITIONS_UP <- 4999L
RI_SEED_UP <- 20260901L

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

randomization_p_value <- function(data, repetitions, seed) {
    blocks <- data$assignment_stratum
    treatment <- data$an_women_reserved
    outcome <- data$pai_good_governance_score
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

estimate_year <- function(joined, target_year, seed) {
    linked <- joined |>
        filter(.data$pai_year == .env$target_year, .data$pai_available)
    analysis <- informative_sample(linked)
    assert_unique(analysis, "election_gp_key", paste(target_year, "UP linked sample"))

    message(target_year, ": fitting raw and HC2 stratum models")
    raw_model <- lm_robust(
        pai_good_governance_score ~ an_women_reserved,
        data = analysis,
        se_type = "HC2"
    )
    strata_model <- lm_robust(
        pai_good_governance_score ~ an_women_reserved,
        data = analysis,
        fixed_effects = ~ assignment_stratum,
        se_type = "HC2"
    )
    message(target_year, ": fitting CR2 block-clustered model")
    block_data <- analysis |>
        group_by(.data$assignment_stratum) |>
        mutate(
            outcome_centered = .data$pai_good_governance_score -
                mean(.data$pai_good_governance_score),
            treatment_centered = .data$an_women_reserved -
                mean(.data$an_women_reserved)
        ) |>
        ungroup()
    block_model <- lm(outcome_centered ~ treatment_centered - 1, data = block_data)
    block_vcov <- vcovCR(
        block_model,
        cluster = block_data$assignment_block,
        type = "CR2"
    )
    block_test <- coef_test(block_model, vcov = block_vcov, test = "Satterthwaite")
    block_contributions <- block_data |>
        group_by(.data$assignment_block) |>
        summarise(
            numerator = sum(.data$treatment_centered * .data$outcome_centered),
            denominator = sum(.data$treatment_centered^2),
            .groups = "drop"
        )
    leave_one_block_out <- (
        sum(block_contributions$numerator) - block_contributions$numerator
    ) / (
        sum(block_contributions$denominator) - block_contributions$denominator
    )

    message(target_year, ": fitting exact-link robustness")
    exact <- linked |>
        filter(.data$raw_lgd_gp_link_method == "exact_normalized_gp_name") |>
        informative_sample()
    exact_model <- lm_robust(
        pai_good_governance_score ~ an_women_reserved,
        data = exact,
        fixed_effects = ~ assignment_stratum,
        se_type = "HC2"
    )

    raw <- extract_term(raw_model, "an_women_reserved")
    strata <- extract_term(strata_model, "an_women_reserved")
    block_critical <- qt(0.975, df = block_test$df_Satt[[1]])
    block <- c(
        estimate = block_test$beta[[1]],
        std_error = block_test$SE[[1]],
        conf_low = block_test$beta[[1]] - block_critical * block_test$SE[[1]],
        conf_high = block_test$beta[[1]] + block_critical * block_test$SE[[1]],
        p_value = block_test$p_Satt[[1]]
    )
    exact_result <- extract_term(exact_model, "an_women_reserved")
    message(target_year, ": running fixed-count randomization sensitivity")
    randomization <- randomization_p_value(
        analysis,
        repetitions = RI_REPETITIONS_UP,
        seed = seed
    )
    message(target_year, ": estimation complete")
    if (!isTRUE(all.equal(
        unname(strata[["estimate"]]),
        randomization$estimate,
        tolerance = 1e-8
    ))) {
        stop("UP regression and randomization statistics disagree", call. = FALSE)
    }

    control_sd <- sd(
        analysis$pai_good_governance_score[analysis$an_women_reserved == 0L]
    )

    tibble(
        pai_year = target_year,
        sample = if_else(
            target_year == PAI_YEAR_PRIMARY,
            "PAI 2.0 primary",
            "PAI 1.0 replication"
        ),
        n = nrow(analysis),
        informative_strata = n_distinct(analysis$assignment_stratum),
        assignment_blocks = n_distinct(analysis$assignment_block),
        control_mean = mean(
            analysis$pai_good_governance_score[
                analysis$an_women_reserved == 0L
            ]
        ),
        control_sd = control_sd,
        raw_difference = raw[["estimate"]],
        strata_adjusted_difference = strata[["estimate"]],
        hc2_std_error = strata[["std_error"]],
        hc2_conf_low = strata[["conf_low"]],
        hc2_conf_high = strata[["conf_high"]],
        hc2_p_value = strata[["p_value"]],
        cr2_std_error = block[["std_error"]],
        cr2_conf_low = block[["conf_low"]],
        cr2_conf_high = block[["conf_high"]],
        cr2_p_value = block[["p_value"]],
        leave_one_block_out_min = min(leave_one_block_out),
        leave_one_block_out_max = max(leave_one_block_out),
        difference_sd = strata[["estimate"]] / control_sd,
        hc2_conf_low_sd = strata[["conf_low"]] / control_sd,
        hc2_conf_high_sd = strata[["conf_high"]] / control_sd,
        exact_link_n = nrow(exact),
        exact_link_difference = exact_result[["estimate"]],
        exact_link_conf_low = exact_result[["conf_low"]],
        exact_link_conf_high = exact_result[["conf_high"]],
        randomization_p_value = randomization$p_value,
        randomization_repetitions = randomization$repetitions
    )
}

joined <- read_parquet(
    here("data", "quota_governance", "quota_governance_gp_up_2022_2024.parquet")
)

results <- bind_rows(
    estimate_year(joined, PAI_YEAR_PRIMARY, RI_SEED_UP),
    estimate_year(joined, PAI_YEAR_REPLICATION, RI_SEED_UP + 1L)
)

if (
    nrow(results) != 2L ||
        !setequal(results$pai_year, c(PAI_YEAR_PRIMARY, PAI_YEAR_REPLICATION)) ||
        any(results$n > n_distinct(joined$election_gp_key))
) {
    stop("UP result rows violate the analysis contract", call. = FALSE)
}

write_csv_receipt(results, here("tabs", "up_pai_effects.csv"))

format_number <- function(x, digits = 2L) {
    formatC(x, digits = digits, format = "f")
}

primary <- results |> filter(.data$pai_year == PAI_YEAR_PRIMARY)
replication <- results |> filter(.data$pai_year == PAI_YEAR_REPLICATION)
coverage <- joined |>
    group_by(.data$pai_year, .data$an_women_reserved) |>
    summarise(match_rate = mean(.data$pai_available), .groups = "drop")
primary_coverage <- coverage |> filter(.data$pai_year == PAI_YEAR_PRIMARY)
write_tex_macros(
    c(
        UpPaiTwoN = format(primary$n, big.mark = ",", scientific = FALSE),
        UpPaiTwoStrata = format(
            primary$informative_strata,
            big.mark = ",",
            scientific = FALSE
        ),
        UpPaiTwoBlocks = format(
            primary$assignment_blocks,
            big.mark = ",",
            scientific = FALSE
        ),
        UpPaiTwoDifference = format_number(primary$strata_adjusted_difference),
        UpPaiTwoCILow = format_number(primary$hc2_conf_low),
        UpPaiTwoCIHigh = format_number(primary$hc2_conf_high),
        UpPaiTwoDifferenceSD = format_number(primary$difference_sd, 3L),
        UpPaiTwoCILowSD = format_number(primary$hc2_conf_low_sd, 3L),
        UpPaiTwoCIHighSD = format_number(primary$hc2_conf_high_sd, 3L),
        UpPaiTwoRIP = format_number(primary$randomization_p_value, 3L),
        UpPaiTwoCRTwoCILow = format_number(primary$cr2_conf_low),
        UpPaiTwoCRTwoCIHigh = format_number(primary$cr2_conf_high),
        UpPaiTwoExactN = format(
            primary$exact_link_n,
            big.mark = ",",
            scientific = FALSE
        ),
        UpPaiTwoExactDifference = format_number(primary$exact_link_difference),
        UpPaiTwoExactCILow = format_number(primary$exact_link_conf_low),
        UpPaiTwoExactCIHigh = format_number(primary$exact_link_conf_high),
        UpPaiTwoOpenMatchPct = format_number(
            100 * primary_coverage$match_rate[
                primary_coverage$an_women_reserved == 0L
            ],
            1L
        ),
        UpPaiTwoWomenMatchPct = format_number(
            100 * primary_coverage$match_rate[
                primary_coverage$an_women_reserved == 1L
            ],
            1L
        ),
        UpPaiOneN = format(replication$n, big.mark = ",", scientific = FALSE),
        UpPaiOneDifference = format_number(replication$strata_adjusted_difference),
        UpPaiOneCILow = format_number(replication$hc2_conf_low),
        UpPaiOneCIHigh = format_number(replication$hc2_conf_high),
        UpPaiOneDifferenceSD = format_number(replication$difference_sd, 3L),
        UpPaiOneCILowSD = format_number(replication$hc2_conf_low_sd, 3L),
        UpPaiOneCIHighSD = format_number(replication$hc2_conf_high_sd, 3L),
        UpPaiOneRIP = format_number(replication$randomization_p_value, 3L)
    ),
    here("tabs", "up_pai_effects_macros.tex")
)

tex_rows <- results |>
    mutate(
        row = paste0(
            .data$sample,
            " & ", format(.data$n, big.mark = ",", scientific = FALSE),
            " & ", format_number(.data$control_mean),
            " & ", format_number(.data$strata_adjusted_difference),
            " & [", format_number(.data$hc2_conf_low),
            ", ", format_number(.data$hc2_conf_high), "]",
            " & ", format_number(.data$difference_sd, 3L),
            " & ", format_number(.data$randomization_p_value, 3L),
            " \\\\"
        )
    ) |>
    pull(.data$row)

tex <- c(
    "\\begin{tabular}{lrrrrrr}",
    "\\toprule",
    "Outcome & $N$ & Control mean & Difference & 95\\% CI & Diff./SD & RI $p$ \\\\",
    "\\midrule",
    tex_rows,
    "\\bottomrule",
    "\\end{tabular}",
    paste0(
        "\\parbox{\\linewidth}{\\scriptsize \\emph{Notes:} Frozen UP specification. ",
        "The reported conditional difference is from an unweighted regression with ",
        "district by LGD block by caste stratum fixed effects and an HC2 interval. ",
        "CR2 block-clustered intervals and exact-link estimates are in the CSV. RI ",
        "assumes fixed treatment counts within strata; the actual assignment mechanism ",
        "is not established.}"
    )
)
dir.create(here("tabs"), showWarnings = FALSE)
writeLines(tex, here("tabs", "up_pai_effects.tex"))

figure <- results |>
    mutate(sample = factor(.data$sample, levels = rev(.data$sample))) |>
    ggplot(aes(x = .data$difference_sd, y = .data$sample)) +
    geom_vline(
        xintercept = 0,
        linetype = "dashed",
        color = COLORS_PUB[["secondary"]]
    ) +
    geom_errorbar(
        aes(xmin = .data$hc2_conf_low_sd, xmax = .data$hc2_conf_high_sd),
        orientation = "y",
        width = 0.15,
        color = COLORS_PUB[["primary"]]
    ) +
    geom_point(size = 2.5, color = COLORS_PUB[["accent"]]) +
    labs(
        x = "Conditional difference (control-group SDs)",
        y = NULL,
        title = "Women's reservations and UP PAI Good Governance",
        subtitle = "Frozen stratum-adjusted specification with HC2 95% intervals"
    ) +
    coord_cartesian(xlim = c(-0.04, 0.04)) +
    scale_x_continuous(breaks = seq(-0.04, 0.04, by = 0.02)) +
    theme_pub()

dir.create(here("figs"), showWarnings = FALSE)
ggsave(
    here("figs", "up_pai_effects.pdf"),
    figure,
    width = FIG_WIDTH_FULL,
    height = 3.2,
    device = cairo_pdf
)

print(results, width = Inf)
message("Frozen UP PAI analysis completed.")
