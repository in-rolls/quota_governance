# Quota, Unquote

Do seats reserved for women change how local governments govern? In the linked Uttar
Pradesh and Rajasthan samples, women-reserved seats are associated with essentially no
difference in the Panchayat Advancement Index (PAI) Good Governance score, a 0 to 100 index
of whether the panchayat held its meetings, filed its plan and accounts, and published its
beneficiary and works lists. The UP estimate
is 0.07 points, with a 95% confidence interval from -0.22 to 0.36. The Rajasthan estimate
is -0.05 points, with an interval from -0.59 to 0.49. In Mumbai, where the city council's
women's seats are drawn by lot, residents rate councillors in reserved wards 0.07
control-group standard deviations higher on a 14-item index, with an interval from -0.10
to 0.24 and a randomization p-value of 0.44.

The UP and Rajasthan estimates are conditional associations: the official seat-allocation
mechanisms have not yet been shown to be random within the reconstructed comparison groups.
The Mumbai contrast is causal, because the draw is a lottery, but its outcome is what
residents perceive, not service delivery measured independently. None of these outcomes
measures leakage, bribery, or corruption.

## Research design

The treatment is whether the seat (sarpanch, pradhan, or Mumbai ward councillor) was
reserved for a woman, not the winner's sex. The analysis compares units within the smallest
reconstructed reservation-allocation strata, or, for Mumbai, within the lottery pool:

| State | Reservation cycle | Comparison strata | Status |
|---|---:|---|---|
| Uttar Pradesh | 2021 | District, LGD block, and caste-reservation class | Frozen before the outcome regression |
| Rajasthan | 2020 | Panchayat Samiti and caste-reservation class | Exploratory |
| Mumbai (BMC) | 2007, 2012, 2017 | The lottery pool: the council, and for 2012 the wards not reserved in 2007 | Specified after one exploratory pass elsewhere |

The primary estimator is an unweighted regression with assignment-stratum fixed effects
and HC2 standard errors. Block-clustered CR2 intervals and fixed-count randomization tests
are robustness checks. The [`design record`](docs/design.md) preserves the UP specification,
explains why the Rajasthan analysis is exploratory, and states the Mumbai specification
and what it was blind to. Commit `edd8b42` records the UP freeze.

## Data

The project joins four sources:

- [PAI](https://github.com/in-rolls/pai) Good Governance scores for fiscal years 2022-23
  and 2023-24.
- [Uttar Pradesh local elections](https://github.com/in-rolls/local_elections_up), including
  the 2021 reservation category and reviewed LGD links.
- [Rajasthan local elections](https://github.com/in-rolls/local_elections_rajasthan), with
  the 2015–2020 reservation panel and reviewed election-to-LGD bridge.
- [local_reservations](https://github.com/in-rolls/local_reservations) for Mumbai: the seat
  reservation of the 2007, 2012 and 2017 councils and the Praja Foundation's ward-level
  citizen ratings of councillors, six survey waves from 2011 to 2018, mirrored there from
  the CC0 replication deposit of Karekurve-Ramachandra and Lee (2025),
  [doi:10.7910/DVN/IO9SLQ](https://doi.org/10.7910/DVN/IO9SLQ).

PAI 2.0 Good Governance for 2023-24 is the primary outcome. The Ministry of Panchayati Raj
scores each Gram Panchayat on nine themes; Good Governance (theme 8) is built from equally
weighted indicators that the panchayat reports on the [PAI portal](https://pai.gov.in) and
the Gram Sabha and district validate. In PAI 2.0, 23 of its 26 indicators are yes/no
checks: was a Gram Sabha, a Mahila Sabha and a Bal Sabha held; do standing committees meet;
was the development plan uploaded to eGramSwaraj by 31 March; were provisional accounts
closed within 15 days of year end and read out in the Gram Sabha; are beneficiary and works
lists displayed and approved; is there a grievance system, online payment, online services,
a co-located common service centre, GeM procurement, a disaster plan; is the office open.
The other three are ratios: growth in own-source revenue, and the shares of planned
activities initiated and completed. So the primary outcome mostly records whether required
procedures were carried out and documented, and a null means women-reserved panchayats are
no more or less likely to hold the meetings, file the plan, close the books, publish the
lists, and grow their own revenue.

| Version | Fiscal year | Indicators | Ratios | Yes/no checks | Shared with the other version |
|---|---|---:|---:|---:|---:|
| PAI 1.0 | 2022-23 | 62 | 27 | 35 | 10 |
| PAI 2.0 | 2023-24 | 26 | 3 | 23 | 10 |

PAI 1.0's theme 8 was closer to performance: a share of grievances redressed, of services
delivered within the Citizens' Charter time, of works completed and geo-tagged, of issues
raised by SC/ST, women, elderly and disabled residents acted on, and whether the social
audit report was uploaded. A ratio has a denominator distinct from its numerator on the
portal, whatever the label says; a check is a yes/no question. PAI 2.0 dropped most of these
ratios for compliance checks, and
only 10 indicators appear in both, so the 2022-23 score is a separate replication rather
than a second observation of the same outcome. The full lists, fetched from the portal's
indicator browser, are in [`docs/pai_theme8_indicators.csv`](docs/pai_theme8_indicators.csv).

Both PAI vintages carry LGD Gram Panchayat codes in [PAI release v0.2.0](https://github.com/in-rolls/pai/releases/tag/v0.2.0),
so each wave joins directly on the reviewed election-to-LGD link. Rajasthan's election
panel has an LGD code for 4,728 of its 7,882 GPs; the rest use exact normalized names within
manually reviewed crosswalks for reorganized districts and blocks. Fuzzy name proposals
never enter the primary link; a reviewed fuzzy link could only feed a robustness variant.
Failed links remain missing and are never coded as zero.

| State | Election GPs | PAI 2.0 linked | Link rate | Estimation sample |
|---|---:|---:|---:|---:|
| Uttar Pradesh | 49,773 | 38,388 | 77.1% | 38,277 |
| Rajasthan | 7,882 | 5,722 | 72.6% | 5,421 |
| Mumbai (BMC) | 681 ward seats | 681 rated | 100% | 681 |

UP link rates are 76.8% for women-reserved seats and 77.3% for other seats. Rajasthan rates
are 72.9% and 72.3%, respectively. Similar rates reduce concern about differential linkage,
but they do not recover unlinked Gram Panchayats. In UP the ceiling is the election release,
not PAI: 38,397 of the 49,773 winners carry a reviewed LGD code, and PAI 2.0 scores all
57,678 UP Gram Panchayats, as the
[official release](https://www.pib.gov.in/PressReleasePage.aspx?PRID=2256616&lang=1&reg=3)
reports.

## Key results

| State | Outcome | Estimate | 95% CI | Control SDs | Sample |
|---|---|---:|---:|---:|---:|
| Uttar Pradesh | PAI 2.0 | 0.07 | [-0.22, 0.36] | 0.004 | 38,277 |
| Rajasthan | PAI 2.0 | -0.05 | [-0.59, 0.49] | -0.004 | 5,421 |
| Mumbai (BMC) | Praja 14-item rating index | 0.05 | [-0.08, 0.18] | 0.067 | 681 |

The UP confidence interval excludes improvements larger than 0.020 control-group standard
deviations in the linked, informative-strata sample. Its PAI 1.0 estimate is -0.05 points
(95% CI: -0.34, 0.24). Restricting PAI 2.0 to exact election-to-LGD links, clustering by
block, and using fixed-count randomization inference all yield the same near-zero pattern.
The frozen specification was first estimated on a 48% linked sample drawn from an
incomplete PAI extract, giving -0.04 points (95% CI: -0.40, 0.31); the
[design record](docs/design.md) keeps that result beside the re-estimation.

The exploratory Rajasthan PAI 1.0 estimate is 0.25 points (95% CI: -0.26, 0.76). The
underlying values are generated by the analysis scripts and stored in
[`tabs/up_pai_effects.csv`](tabs/up_pai_effects.csv) and
[`tabs/raj_pai_effects.csv`](tabs/raj_pai_effects.csv).

Mumbai's index is the mean of fourteen within-wave standardised ratings (roads, water,
schools, sanitation, corruption, and so on), one survey wave per council. The interval in
control-group standard deviations runs from -0.10 to 0.24, so it neither shows an
improvement nor rules out the 0.16 to 0.18 that Desai, Karekurve-Ramachandra and Montero
(2024) report from the same surveys plus a non-public 2019 wave and Praja's own aggregate
grade. The 18-item index and dropping the one ward whose reservation the two sources
dispute give the same picture. Item by item, exploratory and unadjusted, residents in
reserved wards rate schools, law and order, power and water somewhat higher and the
councillor's personal accessibility no differently. Councillors in reserved seats attend
ward-committee meetings more (0.18 SD, 95% CI 0.01 to 0.34) and ask fewer questions in
council (-0.21 SD, -0.38 to -0.04). Values are in
[`tabs/bmc_praja_effects.csv`](tabs/bmc_praja_effects.csv),
[`tabs/bmc_praja_items.csv`](tabs/bmc_praja_items.csv) and
[`tabs/bmc_praja_activity.csv`](tabs/bmc_praja_activity.csv).

## Limits of the evidence

The UP and Rajasthan comparisons are not yet causal. Reservation laws establish rotation
and minimum shares, but they do not by themselves prove random allocation within the
reconstructed strata. Mumbai's draw is a lottery, so its contrast is causal for the seat.

PAI cannot answer whether women leaders reduce corruption. Its Good Governance theme does
ask about procurement through GeM, closing the accounts, and Gram Sabha approval of
beneficiary lists, but as checks that a procedure exists, not as measures of leakage,
audit findings, procurement anomalies, or beneficiary fraud. Those outcomes are required for
a corruption claim.

Linkage restricts the result to the three quarters of UP Gram Panchayats with a reviewed
LGD code, and to linked Rajasthan GPs. Similar coverage
by treatment is useful evidence against one selection mechanism, not evidence for the
missing population.

Mumbai's outcome is a perception survey of about 100 residents per ward, and one of its
items, satisfaction with the councillor, is inverted in the 2018 wave and excluded. The
public data lack the 2019 wave. Three councils give 681 seats, so the interval is wide:
the design can tell a 0.3 SD effect from zero, not a 0.1 SD one.

## Reproduce the analysis

Requirements:

- R 4.6 or newer
- Python 3.12 or newer and `uv`
- XeLaTeX and `latexmk`

```bash
git clone https://github.com/in-rolls/quota_unquote.git
cd quota_unquote
R -e "renv::restore()"
uv sync --all-groups
PAI_RELEASE_FILE=/path/to/pai_gp.parquet Rscript scripts/99_run_all.R
make paper
```

`PAI_RELEASE_FILE` must be the pinned `pai_gp.parquet` from
[PAI release v0.2.0](https://github.com/in-rolls/pai/releases/tag/v0.2.0), also on
[Hugging Face](https://huggingface.co/datasets/soodoku/pai/tree/v0.2.0). The pipeline reads the
Rajasthan and UP election files from `INDIA_DATA_HOME/{provider}/{ref}/{relative_path}`
(default `~/data`). Missing files are copied from a matching sibling source or fetched from the pinned GitHub commit; every read verifies SHA256. For example,
the Rajasthan panel is `local_elections_rajasthan/{ref}/data/fin/elections/raj_15_20.parquet`
within that shared data directory. Every source is verified against its pinned SHA-256.
`LOCAL_RESERVATIONS_DIR` selects another copy of the Mumbai inputs. Expected paths,
source commits, and hashes are recorded in [`data/manifest.yaml`](data/manifest.yaml).

Run the project checks separately:

```bash
make sync
PAI_DATA_DIR=/path/to/pai/consolidated make data
make check
```

`make data` rebuilds the joined data, linkage audits, estimates, tables, and figures.
`make check` runs the R and Python tests, lint checks, design gates, and manuscript build.

## Repository guide

- `scripts/01*` prepare and profile source data.
- `scripts/02*` perform audited, row-preserving joins.
- `scripts/03*` estimate the state results and build the comparison figure; `03d` is Mumbai.
- `scripts/98*` enforce design and disclosure contracts.
- `tabs/` and `figs/` contain generated results.
- [`docs/design.md`](docs/design.md) records analysis status and specifications.
- [`docs/data.md`](docs/data.md) defines variables, recodes, and linkage contracts.

The manuscript source is [`ms/main.tex`](ms/main.tex); `make paper` builds `ms/main.pdf`.
