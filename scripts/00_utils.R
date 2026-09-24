# 00_utils.R
# Source resolution, integrity checks, and reusable transformations.
# Output: none

manifest <- function() {
    yaml::read_yaml(here::here("data", "manifest.yaml"))
}

verify_sha256 <- function(path, expected) {
    if (!file.exists(path)) {
        stop("Missing source file: ", path, call. = FALSE)
    }
    actual <- digest::digest(path, algo = "sha256", file = TRUE)
    if (!identical(actual, expected)) {
        stop(
            "Source hash mismatch for ", path, "\n",
            "expected: ", expected, "\n",
            "actual:   ", actual,
            call. = FALSE
        )
    }
    invisible(path)
}

PAI_RELEASE_FILE <- "data/release/pai_gp.parquet"

resolve_pai_release <- function() {
    spec <- manifest()$upstream$pai
    explicit <- Sys.getenv("PAI_RELEASE_FILE", unset = "")
    path <- if (nzchar(explicit)) {
        path.expand(explicit)
    } else {
        file.path(spec$sibling, PAI_RELEASE_FILE)
    }
    if (!file.exists(path)) {
        stop(
            "Cannot find ", path, ". Set PAI_RELEASE_FILE to the pai_gp.parquet from ",
            "PAI release ", spec$tag, " (", spec$release, ").",
            call. = FALSE
        )
    }
    path <- normalizePath(path, mustWork = TRUE)
    verify_sha256(path, spec$files[[PAI_RELEASE_FILE]])
    path
}

# One row per scored GP and theme for one state. The release table is
# universe-left (every LGD GP of the vintage), so rows without a published
# scorecard are dropped here: downstream, "linked" must mean "has a score".
read_pai_state_long <- function(state) {
    wide <- arrow::read_parquet(resolve_pai_release()) |>
        dplyr::filter(.data$state == .env$state, .data$score_available)
    score_columns <- grep("_score$", names(wide), value = TRUE)
    if (length(score_columns) != 10L) {
        stop("Expected ten PAI score columns, found ", length(score_columns), call. = FALSE)
    }
    wide |>
        dplyr::select(
            "year", "state", "district", "district_value", "block", "block_value",
            "gp_name", "gp_code", dplyr::all_of(score_columns)
        ) |>
        tidyr::pivot_longer(
            dplyr::all_of(score_columns),
            names_to = "theme_slug",
            names_pattern = "^(.*)_score$",
            values_to = "score"
        ) |>
        dplyr::mutate(
            district_std = normalize_name(.data$district),
            block_std = normalize_name(.data$block),
            gp_name_std = normalize_name(.data$gp_name),
            pai_row_key = paste(
                .data$year, .data$district_value, .data$block_value,
                .data$gp_name_std, sep = "__"
            )
        )
}

resolve_election_file <- function(provider, rel) {
    spec <- manifest()$upstream[[provider]]
    expected <- spec$files[[rel]]
    if (is.null(expected)) stop("Unpinned election source: ", provider, "/", rel)
    cache <- path.expand(Sys.getenv("INDIA_DATA_HOME", unset = "~/data"))
    path <- file.path(cache, provider, spec$ref, rel)
    if (!file.exists(path)) {
        dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
        temporary <- tempfile(tmpdir = dirname(path))
        on.exit(unlink(temporary), add = TRUE)
        sibling <- file.path(spec$sibling, rel)
        if (file.exists(sibling) && identical(
            digest::digest(sibling, algo = "sha256", file = TRUE), expected
        )) {
            if (!file.copy(sibling, temporary)) stop("Cannot cache ", sibling)
        } else {
            url <- paste("https://raw.githubusercontent.com", spec$repo, spec$ref, rel, sep = "/")
            utils::download.file(url, temporary, mode = "wb", quiet = TRUE)
        }
        verify_sha256(temporary, expected)
        if (!file.rename(temporary, path)) stop("Cannot save verified source: ", path)
    }
    verify_sha256(path, expected)
    normalizePath(path, mustWork = TRUE)
}

resolve_up_election_file <- function() {
    resolve_election_file("local_elections_up", "data/fin/up_gp_elections_standardized.parquet")
}

resolve_reservations_file <- function(rel) {
    spec <- manifest()$upstream$local_elections
    explicit <- Sys.getenv("LOCAL_ELECTIONS_DIR", unset = "")
    base <- if (nzchar(explicit)) path.expand(explicit) else spec$sibling
    path <- normalizePath(file.path(base, rel), mustWork = TRUE)
    verify_sha256(path, spec$files[[rel]])
    path
}

normalize_name <- function(x) {
    x <- stringi::stri_trans_general(x, "Latin-ASCII")
    x <- stringi::stri_trans_tolower(x)
    x <- gsub("[^[:alnum:]]+", " ", x)
    x <- trimws(x)
    gsub("[[:space:]]+", " ", x)
}

assert_unique <- function(data, columns, label) {
    duplicates <- data |>
        dplyr::count(dplyr::across(dplyr::all_of(columns)), name = "n") |>
        dplyr::filter(.data$n > 1L)
    if (nrow(duplicates) > 0L) {
        stop(label, " is not unique on ", paste(columns, collapse = " + "), call. = FALSE)
    }
    invisible(data)
}

assert_binary <- function(x, label) {
    values <- sort(unique(stats::na.omit(x)))
    if (!identical(values, c(0L, 1L)) && !identical(values, c(0, 1))) {
        stop(label, " must contain exactly 0 and 1", call. = FALSE)
    }
    invisible(x)
}

write_csv_receipt <- function(data, path) {
    dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
    readr::write_csv(data, path, na = "")
    message("Created: ", path)
    invisible(path)
}

write_parquet_receipt <- function(data, path) {
    dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
    arrow::write_parquet(data, path)
    roundtrip <- arrow::read_parquet(path)
    if (nrow(roundtrip) != nrow(data) || !identical(names(roundtrip), names(data))) {
        stop("Parquet round-trip failed for ", path, call. = FALSE)
    }
    message("Created: ", path)
    invisible(path)
}

write_tex_macros <- function(values, path) {
    if (is.null(names(values)) || any(!nzchar(names(values)))) {
        stop("Every TeX macro value must have a name", call. = FALSE)
    }
    if (any(!grepl("^[A-Za-z]+$", names(values)))) {
        stop("TeX macro names may contain letters only", call. = FALSE)
    }
    lines <- paste0("\\newcommand{\\", names(values), "}{", values, "}")
    dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
    writeLines(lines, path)
    message("Created: ", path)
    invisible(path)
}

compile_stratified_simulator <- function(env = parent.frame()) {
    Rcpp::cppFunction(
        includes = c(
            "#include <algorithm>",
            "#include <random>",
            "#include <vector>"
        ),
        code = r"(
        Rcpp::NumericVector simulate_stratified_statistics(
            Rcpp::NumericVector outcome,
            Rcpp::IntegerVector block_id,
            Rcpp::IntegerVector treated_counts,
            int repetitions,
            int seed
        ) {
            int block_count = treated_counts.size();
            std::vector<std::vector<int>> rows(block_count);
            for (int i = 0; i < block_id.size(); ++i) {
                rows[block_id[i]].push_back(i);
            }
            std::mt19937 generator(seed);
            Rcpp::NumericVector statistics(repetitions);
            for (int draw = 0; draw < repetitions; ++draw) {
                double statistic = 0.0;
                for (int block = 0; block < block_count; ++block) {
                    std::shuffle(rows[block].begin(), rows[block].end(), generator);
                    for (int j = 0; j < treated_counts[block]; ++j) {
                        statistic += outcome[rows[block][j]];
                    }
                }
                statistics[draw] = statistic;
            }
            return statistics;
        }
        )",
        env = env
    )
}
