# Data dictionary

One row in each analysis-ready file is one election GP observed against one PAI version. The left table always remains the election panel, so each file has two rows per election GP even when no PAI record links. Rajasthan contains the 2015 to 2020 panel. UP contains the canonical 2021 winners imported from `local_elections_up`.

| name | source file | type | unit | universe | values | missing codes | missing kind | transformation | provenance |
|---|---|---|---|---|---|---|---|---|---|
| `election_gp_key` | `local_elections_rajasthan/data/fin/elections/raj_15_20.parquet` | character | election GP | all 2015 to 2020 linked election-panel rows | normalized district, block, GP composite | none observed | none | renamed from `match_key_2020` | `local_elections_rajasthan` |
| `raw_district_2020` | same | character | election GP | all panel rows | Rajasthan 2020 district name | none observed | none | none | `district_std_2020` |
| `raw_block_2020` | same | character | election GP | all panel rows | Panchayat Samiti name | none observed | none | none | `samiti_std_2020` |
| `raw_gp_name_2020` | same | character | election GP | all panel rows | election GP name | none observed | none | none | `gp_std_2020` |
| `raw_women_reserved_2015` | same | integer | election GP | all panel rows | 0, 1 | none observed | none | none | `female_reserved_2015` |
| `raw_women_reserved_2020` | same | integer | election GP | all panel rows | 0, 1 | none observed | none | none | `female_reserved_2020` |
| `raw_caste_reservation_2020` | same | character | election GP | all panel rows | GEN, OBC, SC, ST | none observed | none | none | `caste_category_2020` |
| `raw_lgd_gp_code` | `local_elections_rajasthan/data/fin/elections/gp_lgd_crosswalk.parquet`, joined by `match_key` | character | election GP | panel rows linked to an LGD GP | LGD identifier | blank or source `NA` | linkage missingness | coerced to character | `lgd_gp_code` |
| `raw_lgd_gp_name` | same | character | election GP | panel rows linked to an LGD GP | official GP name | source `NA` | linkage missingness | none | `lgd_gp_name` |
| `raw_lgd_block_code` | same | character | election GP | panel rows linked to an LGD block | LGD identifier | source `NA` | linkage missingness | coerced to character | `lgd_block_code` |
| `raw_lgd_block_name` | same | character | election GP | panel rows linked to an LGD block | official block name | source `NA` | linkage missingness | none | `lgd_block_name` |
| `raw_lgd_district` | same | character | election GP | panel rows linked to LGD | official district name | source `NA` | linkage missingness | none | `lgd_district` |
| `raw_lgd_match_type` | same | character | election GP | panel rows attempted in upstream LGD linkage | exact, fuzzy | source `NA` | linkage missingness | none | `match_type` |
| `raw_lgd_match_distance` | same | double | election GP | upstream fuzzy LGD matches | 0 to 1 | source `NA` | linkage missingness | none | `match_distance` |
| `an_women_reserved` | same | integer | election GP | all panel rows | 0, 1 | none allowed | none | integer copy of 2020 reservation | `01b_raj_treatment_prepare.R` |
| `assignment_stratum` | same | character | election GP | all panel rows | district, block, caste composite | none allowed | none | concatenated with explicit separators | `01b_raj_treatment_prepare.R` |
| `*_std` | both sources | character | source record | rows with the corresponding raw name | lowercase ASCII alphanumeric words | source `NA` remains `NA` | inherits source | Unicode transliteration, punctuation removal, whitespace collapse | `normalize_name()` |
| `pai_year` | PAI | character | election GP and PAI version | two rows per election GP | 2022-2023, 2023-2024 | none | none | source fiscal year | `01a_pai_prepare.R` |
| `pai_row_key` | PAI | character | PAI GP and version | PAI rows linked to the election panel | year, portal district, portal block, GP composite | missing on unmatched election GPs | linkage missingness | concatenated with explicit separators | `01a_pai_prepare.R` |
| `theme_slug` | PAI | character | election GP and version | all joined rows | `t8_panchayat_with_good_governance` | none | none | selected by stable slug | PAI portal |
| `pai_good_governance_score` | PAI | double | PAI GP | PAI GPs with a published Theme 8 score | 0 to 100; indicators in `pai_theme8_indicators.csv` | missing on unmatched election GPs | linkage missingness | none | PAI portal |
| `pai_link_method` | derived | character | election GP and version | matched rows | direct code, exact name, reviewed fuzzy | missing on unmatched rows | linkage missingness | records the accepted pass | `02a_raj_pai_join.R` |
| `pai_available` | derived | logical | election GP and version | all joined rows | TRUE, FALSE | none | none | score is nonmissing | `02a_raj_pai_join.R` |

## UP fields

| name | source file | type | unit | universe | values | missing codes | missing kind | transformation | provenance |
|---|---|---|---|---|---|---|---|---|---|
| `election_gp_key` | `local_elections_up/...standardized.parquet` | character | 2021 election GP | all 2021 winner rows | stable source key | none | none | imported unchanged | `01d_up_treatment_prepare.R` |
| `raw_district_2021` | same | character | election GP | all 2021 rows | source district name | none | none | imported raw field | `local_elections_up` |
| `raw_block_2021` | same | character | election GP | all 2021 rows | source block name | none | none | imported raw field | `local_elections_up` |
| `raw_gp_name_2021` | same | character | election GP | 2021 rows with a published GP name | source GP name | blank | source missingness | imported raw field | `local_elections_up` |
| `raw_reservation_2021` | same | character | election GP | all 2021 rows | published reservation category | none | none | imported raw field | `local_elections_up` |
| `raw_lgd_block_code` | same | character | election GP | all 2021 rows | LGD block code | none | none | reviewed block crosswalk | `local_elections_up` |
| `raw_lgd_gp_code` | same | character | election GP | accepted election-to-LGD GP links | LGD GP code | missing when unlinked | linkage missingness | exact or reviewed preclink link | `local_elections_up` |
| `raw_lgd_gp_link_method` | same | character | election GP | accepted election-to-LGD GP links | exact normalized name, preclink | missing when unlinked | linkage missingness | imported unchanged | `local_elections_up` |
| `an_women_reserved` | same | integer | election GP | all 2021 rows | 0, 1 | none allowed | none | 1 only for an explicitly women-reserved seat | `01d_up_treatment_prepare.R` |
| `assignment_stratum` | same | character | election GP | all 2021 rows | district, LGD block, caste composite | none | none | concatenated with explicit separators | `01d_up_treatment_prepare.R` |
| `pai_link_method` | derived | character | election GP and version | matched UP rows | direct LGD code, exact official name, exact election name | missing when unmatched | linkage missingness | records the accepted join pass | `02c_up_pai_join.R` |
| `pai_available` | derived | logical | election GP and version | all joined UP rows | TRUE, FALSE | none | none | score is nonmissing | `02c_up_pai_join.R` |

## PAI theme 8 indicators

`docs/pai_theme8_indicators.csv` lists every indicator behind the Good Governance theme for
both PAI versions, as fetched from the portal's indicator browser by
`scripts/00c_pai_theme8_indicators.py`. The script and `tests/test_pai_indicators.py`
assert the contract below on every run: one row per (`pai_version`, `indicator_id`), no
missing values, 62 PAI 1.0 and 26 PAI 2.0 rows, exactly 10 indicator ids shared.

| name | type | unit | values | uniqueness | provenance |
|---|---|---|---|---|---|
| `pai_version` | string | indicator | `PAI 1.0`, `PAI 2.0` | part of the key | portal query `s=1` or `s=2` |
| `fiscal_year` | string | indicator | `2022-2023`, `2023-2024` | constant within version | PAI release year |
| `indicator_id` | int64 | indicator | portal indicator id | key with `pai_version`; the portal repeats an id under alias wordings and only the first is kept | bracketed suffix of the indicator label |
| `mandatory` | string | indicator | `Mandatory`, `Optional` | none | portal column |
| `kind` | string | indicator | `ratio` (denominator distinct from numerator), `number` (a single reported quantity), `binary` (yes/no check); theme 8 has no `number` rows | none | derived by `classify()` from the portal's columns, not the label |
| `indicator` | string | indicator | indicator label without its id | non-empty | portal column |
| `numerator` | string | indicator | data point label | non-empty | portal column |
| `denominator` | string | indicator | data point label; empty for yes/no checks | non-empty when `kind` is `ratio` | portal column |
| `source_url` | string | indicator | portal page fetched | constant within version | script |
| `retrieved_utc` | string | indicator | ISO 8601 UTC timestamp | non-empty | script |

## Open questions

- The 2020 reservation allocation frame and fixed treatment counts within each district, Panchayat Samiti, and caste category still require an official source.
- PAI release v0.2.0 carries LGD GP codes for both vintages. The 77 reviewed nonexact district-block mappings now serve only Rajasthan rows without an LGD code; `pai2_group_mapping_audit.csv` records the supporting counts and GP-name overlaps.
- Rajasthan GP fuzzy-link precision and recall remain unknown until a stratified clerical sample is labeled.
- The UP election-to-LGD accepted threshold has 75 accepted-band links checked by hand, all judged matches. Lower-scoring proposals remain outside the active crosswalk.
- PAI score missingness in the joined file currently means failed record linkage, not a portal score of zero.

## Join contract

Linkage follows the precision-first rules of [`preclink`](https://github.com/finite-sample/preclink)
and the `quota` replication: exact normalized composite keys within a geographic block, one
election row to at most one PAI row, keys that are ambiguous on either side dropped rather
than adjudicated, doubtful links (a code whose PAI name is not the LGD name) dropped rather
than kept, and fuzzy proposals confined to a robustness variant. Every dropped or unmatched
row is written to an audit file, and a failed link is missing, never zero.

### Rajasthan PAI 1.0

The left table is the 7,882-row Rajasthan election panel, keyed uniquely by
`election_gp_key`. PAI Theme 8 is unique by `gp_code`. The many-to-one direct LGD-code
join must preserve all 7,882 election rows; missing LGD codes remain unmatched.

### Rajasthan PAI 2.0 geography

Panel rows with an LGD GP code join PAI 2.0 directly on that code (4,704 of 7,882). For the
rest, the pipeline first joins normalized district-block groups exactly. Nonexact groups require
an approved row in `pai2_group_overrides.csv`. The active list contains 77 source groups
affected by spelling or Rajasthan's district reorganization. Review excluded treatment and
outcome fields. Each target must exist in PAI, each left group must be unique, and ambiguous
statewide block names require explicit evidence.

Within approved groups, exact normalized official GP names are tried first, followed by exact
normalized election names. Preclink Jaro-Winkler scores, a 0.85 threshold, a 0.05 margin, and
Hungarian assignment produce proposals only. Since PAI carries LGD codes, a reviewed fuzzy
link is excluded from the primary sample and could only feed a robustness variant; the
analysis also reports a variant restricted to direct-code links. Accepted links are one to
one and unmatched outcomes remain missing.

### Uttar Pradesh election and PAI joins

The canonical `local_elections_up` release supplies exactly 49,773 2021 GP winner rows.
This repository imports its names, reservation recodes, LGD links, and collision flags rather
than maintaining parallel overrides.

Both waves join accepted election-to-LGD GP codes directly, keeping a code link only when
the PAI GP name equals the LGD GP name after normalization; the 3 UP conflicts are listed in
`up_pai_code_name_conflicts.csv` and left unmatched. Rows without a code then try
exact normalized official GP names within district and LGD block, then exact normalized
election GP names among unused rows; on PAI release v0.2.0 these passes add no links.
Accepted links must be one to one. Each wave preserves all 49,773 election rows,
and the stacked file must contain exactly 99,546 rows.

### Required diagnostics

- Row counts before and after every join.
- Key uniqueness on the required side.
- Match rates overall and by reservation status.
- Linked GPs and informative assignment strata by PAI version.
- No reuse of accepted PAI 2.0 rows.
- Unmatched examples from both sides.
- Precision and recall from a hand-labeled sample stratified by score and margin.

## Recode contract

| variable | definition | required check |
|---|---|---|
| `an_women_reserved` (Rajasthan) | 1 for a women-reserved 2020 sarpanch seat; 0 for an open-gender category | observed values are exactly 0 and 1 |
| `assignment_stratum` (Rajasthan) | district, Panchayat Samiti, and caste category joined with explicit separators | no component may be missing |
| `*_std` | ASCII transliteration, lowercase, punctuation replaced by spaces, and collapsed whitespace | unit tests cover punctuation, accents, whitespace, and missing values |
| `canonical_district_std`, `canonical_block_std` | exact PAI group or approved override | target exists in PAI and each left group is unique |
| `pai_available` | true exactly when a linked PAI Good Governance score is present | equality asserted by the design validators |
| `an_women_reserved` (UP) | 1 only when the 2021 reservation label explicitly identifies a women's category | values are exactly 0 and 1; winner sex is never used |
| `assignment_stratum` (UP) | canonical district, LGD block, and caste-reservation class | no component may be missing |
| `raw_lgd_gp_code` (UP) | exact-name or reviewed preclink link from the canonical election release | accepted links are one to one |

No missing value is replaced with zero. The pipeline stops when source row counts, key
cardinality, treatment levels, or crosswalk targets differ from these contracts.

## Mumbai (BMC) fields

One row in `data/bmc/quota_unquote_bmc_2007_2017.parquet` is one ward observed in one Praja survey wave: 1,361 rows, 227 wards in each of six waves (226 in 2014). Seat reservation is joined from `local_elections` on council and ward number; every ward-wave matches exactly one seat.

| name | source file | type | unit | universe | values | missing codes | missing kind | transformation | provenance |
|---|---|---|---|---|---|---|---|---|---|
| `council` | `local_elections/.../praja_ward_ratings_2011_2018.csv` | integer | ward-wave | all rows | 2007, 2012, 2017 | none | none | the council whose term the wave falls in | deposit `term` |
| `ward_no` | same | character | ward | all rows | 1 to 227 | none | none | none; 2017 numbers are a different geography | deposit `ward` |
| `survey_year` | same | character | wave | all rows | 2011, 2013, 2014, 2015, 2016, 2018 | none | none | none | deposit `year` |
| `an_women_reserved` | `ulb_ward_2012.csv`, `ulb_ward_2017.csv`, `bmc_seats_2007.csv` | integer | seat | all rows | 0, 1 | none allowed | none | the seat's reservation; never the councillor's sex | `01f_bmc_prepare.R` |
| `raw_reservation` | same | character | seat | all rows | schema label (2012, 2017) or `W`/blank (2007) | blank means open in 2007 | none | none | `local_elections` |
| `raw_caste_reservation` | same | character | seat | 2012 and 2017 rows | NONE, SC, ST, BC | `NA` for 2007 | source has no caste roster for 2007 | none | `local_elections` |
| `deposit_women_reserved` | ratings | integer | seat | all rows | 0, 1 | none | none | the deposit's own flag, kept to test agreement with the treatment | deposit `genderquota` |
| `prior_women_reserved` | derived | integer | ward | 2012 rows | 0, 1 | `NA` outside 2012 | not defined | the ward's 2007 reservation | `01f_bmc_prepare.R` |
| `assignment_stratum` | derived | character | seat | all rows | `2007`, `2012__prior0`, `2012__prior1`, `2017` | none | none | the pool the lot was drawn within | `01f_bmc_prepare.R` |
| `assignment_block` | derived | character | ward | all rows | `w<ward>` or `2017__w<ward>` | none | none | cluster for CR2; 2017 wards are new geographies | `01f_bmc_prepare.R` |
| `councillor`, `councillor_woman`, `councillor_party`, `councillor_age`, `councillor_education`, `councillor_criminal_cases` | ratings | mixed | councillor | rows where the deposit names one | source values | blank name; affidavit fields absent in 2011 | source missingness | none | deposit |
| `attendance_general_body`, `attendance_ward_committee`, `questions_total` | ratings | double | councillor-year | rows with BMC activity data | shares in 0 to 1; counts | `NA` where the deposit is blank | source missingness | attended / total meetings | deposit RTI fields |
| `raw_rating_<item>` | ratings | double | ward-wave | items asked in the wave | 0 to 100, higher better | `NA` when not asked | not asked | none | Praja via the deposit |
| `an_rating_satisfaction` | derived | double | ward-wave | 2013 to 2016 | 0 to 100 | `NA` in 2011 (not asked) and 2018 (inverted) | excluded by design | blanked where `rating_flags` says inverted | `01f_bmc_prepare.R` |
| `an_rating_index14` | derived | double | ward-wave | all rows | mean of 14 within-wave z-scores | none | none | 13 service items plus corruption | `01f_bmc_prepare.R` |
| `an_rating_index18` | derived | double | ward-wave | 2013 to 2018 | mean of 18 within-wave z-scores | `NA` in 2011 | items not asked | adds recall of party and name, accessibility, quality of life | `01f_bmc_prepare.R` |
| `rating_flags` | ratings | character | ward-wave | all rows | blank or `satisfaction_inverted` | none | none | none | `local_elections` parser |

### Join contract, Mumbai

- Left table: the Praja ward-wave table (1,361 rows). Right table: 681 seat rows, one per council and ward. The join must return every left row exactly once.
- Treatment counts per council: 76 (2007), 115 (2012, one more than the statute; ward 172 is disputed with the deposit), 114 (2017).
- The primary sample takes one wave per council (2011, 2016, 2018): 681 rows.
