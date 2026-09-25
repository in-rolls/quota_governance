# 03a_raj_pai_effects.R
# Estimate exploratory Rajasthan reservation effects on PAI Good Governance.
# Output: tabs/raj_pai_effects.csv, tabs/raj_pai_effects.tex,
#         figs/raj_pai_effects.pdf

library(here)
library(dplyr)
library(readr)
library(arrow)
library(estimatr)
library(randomizr)
library(ggplot2)

source(here("scripts", "00_config.R"))
source(here("scripts", "00_utils.R"))

RI_REPETITIONS <- 4999L
RI_SEED <- 20260831L

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

randomization_p_value <- function(data, repetitions, seed) {
    blocks <- data$assignment_stratum
    treatment <- data$an_women_reserved
    outcome <- data$pai_good_governance_score
    treatment_counts <- ave(treatment, blocks, FUN = sum)

    declaration <- declare_ra(
        blocks = blocks,
        m_unit = treatment_counts
    )

    set.seed(seed)
    permutations <- obtain_permutation_matrix(
        declaration,
        maximum_permutations = repetitions
    )
    if (nrow(permutations) != nrow(data)) {
        stop("Randomization matrix has the wrong number of rows", call. = FALSE)
    }

    outcome_centered <- outcome - ave(outcome, blocks)
    treatment_centered <- treatment - ave(treatment, blocks)
    denominator <- sum(treatment_centered^2)
    observed <- sum(treatment_centered * outcome_centered) / denominator
    simulated <- as.numeric(crossprod(outcome_centered, permutations)) / denominator

    list(
        estimate = observed,
        p_value = (1 + sum(abs(simulated) >= abs(observed))) /
            (1 + length(simulated)),
        repetitions = length(simulated)
    )
}

CODE_LINK_METHODS <- c("direct_lgd_code", "direct_lgd_gp_code")
PRIMARY_LINK_METHODS <- c(
    CODE_LINK_METHODS, "exact_official_gp_name", "exact_election_gp_name"
)

informative_sample <- function(data) {
    informative <- data |>
        group_by(.data$assignment_stratum) |>
        summarise(
            treatment_levels = n_distinct(.data$an_women_reserved),
            .groups = "drop"
        ) |>
        filter(.data$treatment_levels == 2L)
    list(
        data = data |> semi_join(informative, by = join_by(assignment_stratum)),
        strata = nrow(informative)
    )
}

# Reviewed fuzzy name links, if any are ever approved, are excluded from the
# primary sample; they could only feed a separate robustness variant.
estimate_year <- function(joined, target_year, seed) {
    analysis <- joined |>
        filter(
            .data$pai_year == .env$target_year,
            .data$pai_available,
            .data$pai_link_method %in% PRIMARY_LINK_METHODS
        ) |>
        mutate(
            assignment_block = paste(
                .data$raw_district_2020,
                .data$raw_block_2020,
                sep = "__"
            )
        )

    assert_unique(analysis, "election_gp_key", paste(target_year, "linked sample"))
    if (nrow(analysis) > n_distinct(joined$election_gp_key)) {
        stop("A PAI-year sample exceeds the election-panel row count", call. = FALSE)
    }

    informative <- informative_sample(analysis)
    analysis <- informative$data

    code_only <- informative_sample(
        analysis |> filter(.data$pai_link_method %in% CODE_LINK_METHODS)
    )$data
    code_model <- lm_robust(
        pai_good_governance_score ~ an_women_reserved,
        data = code_only,
        fixed_effects = ~ assignment_stratum,
        se_type = "HC2"
    )

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
    block_model <- lm_robust(
        pai_good_governance_score ~ an_women_reserved,
        data = analysis,
        fixed_effects = ~ assignment_stratum,
        clusters = assignment_block,
        se_type = "CR2"
    )
    precision_model <- lm_robust(
        pai_good_governance_score ~
            an_women_reserved + raw_women_reserved_2015,
        data = analysis,
        fixed_effects = ~ assignment_stratum,
        se_type = "HC2"
    )

    raw <- extract_term(raw_model, "an_women_reserved")
    strata <- extract_term(strata_model, "an_women_reserved")
    block <- extract_term(block_model, "an_women_reserved")
    precision <- extract_term(precision_model, "an_women_reserved")
    code <- extract_term(code_model, "an_women_reserved")
    randomization <- randomization_p_value(
        analysis,
        repetitions = RI_REPETITIONS,
        seed = seed
    )

    if (!isTRUE(all.equal(
        unname(strata[["estimate"]]),
        randomization$estimate,
        tolerance = 1e-8
    ))) {
        stop("Regression and randomization statistics disagree", call. = FALSE)
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
        informative_strata = informative$strata,
        assignment_blocks = n_distinct(analysis$assignment_block),
        control_mean = mean(
            analysis$pai_good_governance_score[
                analysis$an_women_reserved == 0L
            ]
        ),
        control_sd = control_sd,
        raw_difference = raw[["estimate"]],
        effect_points = strata[["estimate"]],
        hc2_std_error = strata[["std_error"]],
        hc2_conf_low = strata[["conf_low"]],
        hc2_conf_high = strata[["conf_high"]],
        hc2_p_value = strata[["p_value"]],
        cr2_std_error = block[["std_error"]],
        cr2_conf_low = block[["conf_low"]],
        cr2_conf_high = block[["conf_high"]],
        cr2_p_value = block[["p_value"]],
        prior_adjusted_effect = precision[["estimate"]],
        effect_sd = strata[["estimate"]] / control_sd,
        hc2_conf_low_sd = strata[["conf_low"]] / control_sd,
        hc2_conf_high_sd = strata[["conf_high"]] / control_sd,
        code_link_n = nrow(code_only),
        code_link_effect = code[["estimate"]],
        code_link_conf_low = code[["conf_low"]],
        code_link_conf_high = code[["conf_high"]],
        randomization_p_value = randomization$p_value,
        randomization_repetitions = randomization$repetitions
    )
}

joined <- read_parquet(
    here("data", "quota_governance", "quota_governance_gp_raj_2022_2024.parquet")
)

results <- bind_rows(
    estimate_year(joined, PAI_YEAR_PRIMARY, RI_SEED),
    estimate_year(joined, PAI_YEAR_REPLICATION, RI_SEED + 1L)
)

if (
    nrow(results) != 2L ||
        !setequal(results$pai_year, c(PAI_YEAR_PRIMARY, PAI_YEAR_REPLICATION)) ||
        any(results$n > n_distinct(joined$election_gp_key))
) {
    stop("Exploratory result rows violate the analysis contract", call. = FALSE)
}

write_csv_receipt(results, here("tabs", "raj_pai_effects.csv"))

format_number <- function(x, digits = 2L) {
    formatC(x, digits = digits, format = "f")
}

primary <- results |> filter(.data$pai_year == PAI_YEAR_PRIMARY)
replication <- results |> filter(.data$pai_year == PAI_YEAR_REPLICATION)
write_tex_macros(
    c(
        RajPaiTwoN = format(primary$n, big.mark = ",", scientific = FALSE),
        RajPaiTwoStrata = format(
            primary$informative_strata,
            big.mark = ",",
            scientific = FALSE
        ),
        RajPaiTwoDifference = format_number(primary$effect_points),
        RajPaiTwoCILow = format_number(primary$hc2_conf_low),
        RajPaiTwoCIHigh = format_number(primary$hc2_conf_high),
        RajPaiTwoDifferenceSD = format_number(primary$effect_sd, 3L),
        RajPaiTwoCILowSD = format_number(primary$hc2_conf_low_sd, 3L),
        RajPaiTwoCIHighSD = format_number(primary$hc2_conf_high_sd, 3L),
        RajPaiTwoRIP = format_number(primary$randomization_p_value, 3L),
        RajPaiTwoCodeLinkN = format(
            primary$code_link_n,
            big.mark = ",",
            scientific = FALSE
        ),
        RajPaiTwoCodeLinkDifference = format_number(primary$code_link_effect),
        RajPaiTwoCodeLinkCILow = format_number(primary$code_link_conf_low),
        RajPaiTwoCodeLinkCIHigh = format_number(primary$code_link_conf_high),
        RajPaiOneDifference = format_number(replication$effect_points),
        RajPaiOneCILow = format_number(replication$hc2_conf_low),
        RajPaiOneCIHigh = format_number(replication$hc2_conf_high),
        RajPaiOneDifferenceSD = format_number(replication$effect_sd, 3L),
        RajPaiOneCILowSD = format_number(replication$hc2_conf_low_sd, 3L),
        RajPaiOneCIHighSD = format_number(replication$hc2_conf_high_sd, 3L),
        RajPaiOneRIP = format_number(replication$randomization_p_value, 3L)
    ),
    here("tabs", "raj_pai_effects_macros.tex")
)

tex_rows <- results |>
    mutate(
        row = paste0(
            .data$sample,
            " & ", format(.data$n, big.mark = ",", scientific = FALSE),
            " & ", format_number(.data$control_mean),
            " & ", format_number(.data$effect_points),
            " & [", format_number(.data$hc2_conf_low),
            ", ", format_number(.data$hc2_conf_high), "]",
            " & ", format_number(.data$effect_sd, 3L),
            " & ", format_number(.data$randomization_p_value, 3L),
            " \\\\"
        )
    ) |>
    pull(.data$row)

tex <- c(
    "\\begin{tabular}{lrrrrrr}",
    "\\toprule",
    "Outcome & $N$ & Control mean & Effect & 95\\% CI & Effect/SD & RI $p$ \\\\",
    "\\midrule",
    tex_rows,
    "\\bottomrule",
    "\\end{tabular}",
    paste0(
        "\\parbox{\\linewidth}{\\scriptsize \\emph{Notes:} Exploratory estimates. ",
        "The effect is from an unweighted regression with assignment-stratum fixed ",
        "effects and HC2 confidence intervals. RI permutes the observed number of ",
        "women-reserved seats within each informative district by Panchayat Samiti ",
        "by caste stratum. PAI 1.0 and PAI 2.0 are separate outcomes. Estimates ",
        "restricted to direct LGD-code links are in the CSV.}"
    )
)
dir.create(here("tabs"), showWarnings = FALSE)
writeLines(tex, here("tabs", "raj_pai_effects.tex"))

figure <- results |>
    mutate(sample = factor(.data$sample, levels = rev(.data$sample))) |>
    ggplot(aes(x = .data$effect_sd, y = .data$sample)) +
    geom_vline(xintercept = 0, linetype = "dashed", color = COLORS_PUB[["secondary"]]) +
    geom_errorbar(
        aes(xmin = .data$hc2_conf_low_sd, xmax = .data$hc2_conf_high_sd),
        orientation = "y",
        width = 0.15,
        color = COLORS_PUB[["primary"]]
    ) +
    geom_point(size = 2.5, color = COLORS_PUB[["accent"]]) +
    labs(
        x = "Effect of a women-reserved seat (control-group SDs)",
        y = NULL,
        title = "Women's reservations and PAI Good Governance",
        subtitle = "Exploratory stratum-adjusted estimates with HC2 95% intervals"
    ) +
    theme_pub()

dir.create(here("figs"), showWarnings = FALSE)
ggsave(
    here("figs", "raj_pai_effects.pdf"),
    figure,
    width = FIG_WIDTH_FULL,
    height = 3.2,
    device = cairo_pdf
)

print(results, width = Inf)
message("Exploratory Rajasthan PAI analysis completed.")
