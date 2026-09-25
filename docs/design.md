# Analysis design and status

## Uttar Pradesh: frozen analysis plan

Status: frozen on September 1, 2026, before any UP outcome-on-treatment
regression was run. Source outcomes, marginal distributions, overall linkage,
and treatment-specific linkage rates had already been examined. This is an
analysis freeze, not a prospective registration.

## Question and estimand

The directional hypothesis is that reserving the 2021 pradhan seat for a woman
increases the subsequent PAI Good Governance score. The estimand is the
unweighted conditional difference associated with a women-reserved rather than
a known non-women-reserved seat among linked UP GPs in informative
district--block--caste reservation strata.

The primary outcome is the 2023/24 PAI 2.0 Good Governance score. The 2022/23
PAI 1.0 Good Governance score is a separate replication because the indicator
systems differ.

## Identification and claim

The UP Panchayat Raj Act establishes rotation and a minimum women-reservation
share but does not, by itself, establish random allocation within the
reconstructed strata. Unless the 2021 roster algorithm is independently shown
to be as-if random conditional on district, block, and caste reservation class,
the coefficient is a conditional association. Randomization inference is a
sensitivity calculation under the stated fixed-count assignment model, not
evidence that the model governed the actual roster.

PAI measures reported governance procedure and performance. It is not a direct
measure of leakage, bribery, or corruption, so this analysis cannot by itself
support the claim that women pradhans reduce corruption.

## Primary specification

- Unit: one 2021 GP winner/seat.
- Treatment: `women_reserved`, coded 1 only when the source reservation label
  explicitly contains `Female`, 0 for known non-women categories, and never
  imputed from the winner's sex.
- Sample: linked PAI 2.0 rows in strata containing both treatment levels.
- Strata: canonical 2021 district, current LGD block, and caste reservation
  class (`general`, `obc`, `sc`, or `st`).
- Estimator: unweighted OLS with assignment-stratum fixed effects.
- Primary uncertainty: HC2 standard errors and 95% confidence interval.
- Companion uncertainty: CR2 standard errors clustered by canonical
  district--block.
- Scale: PAI points and control-group standard deviations.
- Randomization sensitivity: 4,999 fixed-count permutations within informative
  strata, seed 20260901.

## Prespecified diagnostics and robustness

1. Report linkage rates by treatment for both PAI waves.
2. Report the raw linked-sample difference without stratum adjustment.
3. Repeat the specification for PAI 1.0.
4. Repeat using only exact election-to-LGD GP links.
5. Report informative strata, blocks, control mean, and control SD.
6. Preserve all unmatched rows and never code failed linkage as a zero score.

No subgroup, alternative PAI theme, covariate search, population weighting, or
functional-form search is primary. Any such result must be labeled exploratory.

## Frozen inputs

- `local_elections_up` commit `3e19684df019be328664f2f98362d789874855d9`
- Standardized election SHA-256
  `986893d620e3d1d0d46e3d306909cc7acf3ccbae383346e4f47b39de9f62fe76`
- PAI consolidated files were pinned in `data/manifest.yaml` at the freeze (an incomplete
  portal extract; see the re-estimation section below).
- UP joined-file row contract: 49,773 election rows per PAI wave.

The shared-pipeline migration pins UP commit `9f051cd607b9a42aa3afc498e57737200ef22024`
with the same standardized-election SHA-256 shown above. Rajasthan now consumes the
state repository's election panel and geographic bridge directly. The updated bridge
removes one prior link (`tonk_newai_khandevat` to LGD 42097), leaving 4,728 of 7,882
election rows with LGD codes; reservation assignments are unchanged. The two Newai
election GPs `khandevat` and `khandwa` both proposed LGD 42097 (`Khandewat`) at the
same Jaro-Winkler distance, 0.07407407407407415. The old producer kept the first
claim; the current producer rejects the tied claims. Both PAI estimation samples
lose one observation. The PAI 2.0 estimate changes from -0.05047 to -0.05040 points;
the PAI 1.0 estimate changes from 0.25087 to 0.25219 points.

On September 25, 2026 the inputs were re-pinned to the current state releases:
UP `3ef1d56f278a2ca98a2b9a61027c130781fb236f` `data/release/gp/gp_head_election_records.parquet`
(which replaced the deleted `data/fin/up_gp_elections_standardized.parquet`),
Rajasthan `8773067fefe9c0ff549d0c9d12688018f19a156a` and `local_elections`
`8c977fbdbbff2cbb18a32767116e014cfb876788`. The Rajasthan and Mumbai files are
byte-identical at the new commits. The UP release has the same 212,525 rows and
treatment; it adds `winner_markers_conflict` and blanks the winner of the two
Sonai (Mainpuri) 2021 rows whose markers disagree. No table changes.

## Post-freeze results

The design was frozen in commit `edd8b42cd4997fc0a01e516031cd886f3e66f099` before the first UP outcome-on-treatment regression. `tabs/up_pai_effects.csv` is the numerical source of truth.

The primary PAI 2.0 conditional difference is -0.0419 points with an HC2 95% confidence interval from -0.3963 to 0.3125. This is -0.0024 control-group standard deviations with an interval from -0.0224 to 0.0176. The fixed-count randomization sensitivity yields 0.8182. PAI 1.0, CR2 block clustering, and the exact election-to-LGD subset agree with the near-zero primary result.

The analysis supports a precise null conditional association in the linked informative-strata sample. It does not establish a causal effect or an effect on corruption.

## Re-estimation on the complete PAI extract

Status: run on September 5, 2026, after the frozen-sample results above were known. It is a re-estimation of the unchanged frozen specification on new outcome data, not a blind replication.

The PAI extract pinned at the freeze covered 35,979 of 57,678 UP Gram Panchayats for 2023/24 and carried no LGD codes for PAI 2.0, so PAI 2.0 was linked by exact names and 48.1% of the 2021 winners were linked. PAI release v0.2.0 (`in-rolls/pai` `af7db25`, pinned in `data/manifest.yaml`) scores every UP GP in both vintages, state totals match the Ministry's published counts, and every row carries an LGD code. Both waves now join on the reviewed election-to-LGD code; the exact-name passes remain in the code and add no links.

What changed: the outcome file and the join key. What did not: the estimand, treatment coding, strata, sample rule, estimator, interval methods, exact-link restriction, seed, and randomization count.

| | Frozen sample | Complete extract |
|---|---:|---:|
| Linked UP GPs (PAI 2.0) | 23,921 (48.1%) | 38,388 (77.1%) |
| Link rate, women-reserved vs other | 48.0% vs 48.1% | 76.8% vs 77.3% |
| Informative-strata sample | 23,763 | 38,277 |
| Informative strata | 1,511 | 2,224 |
| PAI 2.0 difference, points (HC2 95% CI) | -0.042 (-0.396, 0.313) | 0.067 (-0.223, 0.358) |
| In control-group SDs | -0.002 (-0.022, 0.018) | 0.004 (-0.013, 0.020) |
| Fixed-count randomization p | 0.818 | 0.648 |
| PAI 1.0 difference, points (HC2 95% CI) | -0.097 (-0.404, 0.210) | -0.051 (-0.345, 0.242) |

The unlinked 11,385 winners are the rows the election release could not link to an LGD GP, not rows missing from PAI. A code link is accepted only when the PAI GP name equals the LGD GP name after normalization. Of the 53,771 UP rows linkable by code across both waves, 3 fail this test (two in Mankapur, Gonda, whose PAI names are swapped relative to LGD, and one in Chahniya, Chandauli); they are dropped as doubtful and listed in `up_pai_code_name_conflicts.csv`. No Rajasthan code link fails it.

## Deviations and implementation notes

- No frozen estimand, outcome, sample rule, weighting rule, fixed effect, interval method, exact-link restriction, or randomization count changed after unblinding. The outcome source file changed once, to the complete PAI extract, as recorded above.
- The CR2 companion uses the Frisch-Waugh-Lovell within-stratum transformation followed by `clubSandwich::vcovCR(type = "CR2")`. This is algebraically equivalent to the frozen fixed-effect regression and reproduces the Rajasthan `estimatr::lm_robust` coefficient and CR2 standard error.
- The fixed-count randomization sampler was implemented in Rcpp because materializing the full assignment matrix would require roughly one gigabyte. The statistic, number of draws, seed, strata, treatment counts, and finite-sample p-value correction remain as frozen.

## Rajasthan: exploratory analysis

The Rajasthan analysis was not preregistered or frozen before estimation. Source rows,
outcome distributions, linkage coverage, and treatment-specific availability had already
been examined when exploratory outcome analysis began on September 1, 2026. Its estimates
must remain labeled exploratory.

The analysis uses an unweighted comparison of women-reserved and open-gender sarpanch seats
within reconstructed Panchayat Samiti and caste-reservation strata. Its causal interpretation
would require the official 2020 allocation to be random within those strata. Rotation order,
population rules, boundary changes, or administrative discretion could violate that condition.

PAI 2.0 Good Governance is the principal Rajasthan outcome, with PAI 1.0 treated as a
separate replication because the indicator systems differ. Failed links remain missing and
are never recoded as zero. The primary sample uses direct LGD-code and exact-name links;
reviewed fuzzy links, if any are approved, are a robustness variant only, and
`tabs/raj_pai_effects.csv` also reports the estimate restricted to direct-code links. Because
exploratory Rajasthan outcome analysis began before the
design was frozen, neither the estimates nor later robustness checks are confirmatory.

## Mumbai (BMC): lottery-assigned women's seats

Status: specified on September 3, 2026, after the same data had been examined
in an exploratory pass (in `quota_elite_quality`) that produced a reserved-seat
difference of about +0.05 SD on a 14-item index. The specification below was
fixed before the pipeline in this repository was run, but it is not blind to
that pass, so the Mumbai result is confirmatory only of the pipeline, not of a
hypothesis formed in ignorance of the data.

### Setting and data

The Brihanmumbai Municipal Corporation has 227 single-member wards. Before each
election the seats reserved for women are drawn by lot: one third of the seats
in 2007, one half from 2012. The Praja Foundation surveys about 100 residents in
every ward in each non-election year and publishes ward-level mean ratings of
the sitting councillor on roads, water, schools, sanitation, corruption, and so
on, each on a 0 to 100 scale with higher better.

Seat reservation and ratings come from `local_elections` (pinned in
`data/manifest.yaml`): the 2012 and 2017 councils as schema slices, the 2007
council as a supplemental file with a women's flag only, and the ratings as the
CC0 replication deposit of Karekurve-Ramachandra and Lee (2025), Harvard
Dataverse doi:10.7910/DVN/IO9SLQ. The deposit has six waves (2011, 2013 to 2016,
2018); the 2019 wave used by Desai, Karekurve-Ramachandra and Montero (2024) is
not public.

### Identification and claim

Because the reservation is drawn by lot, the comparison of reserved and open
wards within the pool the draw was made from is a causal contrast, not a
conditional association. The pool is the whole council in 2007 and 2017. The
2012 draw excluded the 76 wards reserved in 2007 (none of them was reserved
again), so its pool is the set of wards not reserved in 2007 and the stratum is
council by prior status. Wards were redrawn before 2017, so no prior status is
defined for that council.

The outcome is residents' perception of the councillor's performance, not
service delivery measured independently. It does not support claims about
corruption or about the councillor's objective output.

### Primary specification

- Unit: one ward in one survey wave, one survey wave per council (2011 for the
  2007 council, 2016 for 2012, 2018 for 2017), the last non-election year of
  the term.
- Treatment: `an_women_reserved`, 1 only when the seat's reservation names a
  woman, from the `local_elections` file, never from the councillor's sex.
- Outcome: `an_rating_index14`, the mean of the 14 items present in every wave
  (13 service items and corruption), each standardised within wave. The
  satisfaction item is excluded from every index because it is inverted in the
  2018 wave (its correlation with the 13 service items is +0.44 in 2016 and
  -0.33 in 2018); the analysis copy of that item is blank in 2018 and the raw
  value is kept.
- Sample: wards in informative strata (all three councils are informative).
- Estimator: unweighted OLS with assignment-stratum fixed effects.
- Primary uncertainty: HC2 standard errors and 95% confidence interval.
- Companion uncertainty: CR2 standard errors clustered by ward (ward numbers
  before and after the 2017 redistricting are different geographies and are
  different clusters).
- Scale: control-group standard deviations of the index.
- Randomization sensitivity: 4,999 fixed-count permutations within strata,
  seed 20260903. Because the draw is a lottery, this is a test of the sharp null
  rather than a sensitivity calculation.

### Prespecified robustness

1. The 18-item index (adding recall of party and name, accessibility, and
   quality-of-life improvement) on the 2012 and 2017 councils, where those
   items exist.
2. Dropping the one ward (172 in 2012) where the source sheet and the deposit
   disagree on the reservation.
3. The raw difference without stratum fixed effects.

Exploratory, reported without multiplicity adjustment and so labeled: the
reserved-seat difference item by item, and on ward-committee attendance,
general-body attendance, and questions asked in council.

### Frozen inputs

- `local_elections` commit `4b14ed10dea82e498121bbfe0ddf64455ceb8c71`.
- Four file hashes pinned in `data/manifest.yaml`.
- Row contract: 1,361 ward-waves; 227 wards per wave except 226 in 2014; 76
  women's seats in the 2007 council, 114 in 2017, and 115 in the 2012 source
  sheet against 114 by statute (ward 172).
