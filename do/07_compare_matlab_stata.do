* Comparison with the MATLAB estimates and coefficient figure.
version 19.0

use "${STATA_ROOT}/output/stata_results.dta", clear
isid analysis ageing_definition model variant
sort analysis ageing_definition model variant
format stata_beta stata_se stata_t stata_p first_stage_F %21.15g
export delimited using "${STATA_ROOT}/output/stata_results.csv", replace
preserve
    keep analysis ageing_definition model variant
    tempfile variants
    save `variants'
restore

* Compare the samples region-year by region-year.
import delimited using "${STATA_ROOT}/benchmarks/matlab_sample_keys.csv", ///
    clear varnames(1) case(preserve) encoding("utf-8")
isid analysis ageing_definition model geo year
joinby analysis ageing_definition model using `variants'
merge 1:1 analysis ageing_definition model variant geo year ///
    using "${STATA_ROOT}/output/stata_sample_keys.dta"
generate long matched_keys = (_merge == 3)
generate long matlab_only = (_merge == 1)
generate long stata_only = (_merge == 2)
collapse (sum) matched_keys matlab_only stata_only, ///
    by(analysis ageing_definition model variant)
generate byte sample_keys_match = (matlab_only == 0 & stata_only == 0)
sort analysis ageing_definition model variant
save "${STATA_ROOT}/output/sample_comparison.dta", replace
export delimited using "${STATA_ROOT}/output/sample_comparison.csv", replace

import delimited using "${STATA_ROOT}/benchmarks/matlab_reference.csv", ///
    clear varnames(1) case(preserve) encoding("utf-8") asdouble
isid analysis ageing_definition model
assert _N == 24
tempfile matlab
save `matlab'
use "${STATA_ROOT}/output/stata_results.dta", clear
merge m:1 analysis ageing_definition model using `matlab', assert(match) nogen
merge 1:1 analysis ageing_definition model variant ///
    using "${STATA_ROOT}/output/sample_comparison.dta", assert(match) nogen

generate double beta_difference = stata_beta - matlab_beta
generate double se_difference = stata_se - matlab_se
generate double p_difference = stata_p - matlab_p
generate double F_difference = first_stage_F - matlab_F
generate byte sample_match = sample_keys_match & stata_n == matlab_n ///
    & stata_regions == matlab_regions & stata_years == matlab_years

* Tolerances for rounding differences.
generate byte beta_match = abs(beta_difference) <= 1e-7 + 1e-6*abs(matlab_beta)
generate byte se_match = abs(se_difference) <= 1e-7 + 1e-6*abs(matlab_se)
generate byte p_match = abs(p_difference) <= 1e-7 + 1e-6*abs(matlab_p)
generate byte F_match = missing(matlab_F) | ///
    abs(F_difference) <= 1e-5 + 1e-6*abs(matlab_F)
generate str40 classification = "unresolved discrepancy"
replace classification = "exact / numerical rounding" ///
    if sample_match & beta_match & se_match & p_match & F_match
replace classification = "expected estimator difference" ///
    if analysis == "baseline" & inlist(variant,"rreg","ols_hc1") & sample_match

* Expected default ivregress SE: the MATLAB SE without the finite-sample correction.
generate double expected_default_se = matlab_se / sqrt(cluster_multiplier)
replace expected_default_se = matlab_se / ///
    sqrt((stata_regions/(stata_regions-1))*((stata_n-1)/(stata_n-model_rank))) ///
    if variant == "stata_default"
replace classification = "expected SE correction difference" ///
    if variant == "stata_default" & sample_match & beta_match ///
    & abs(stata_se-expected_default_se) <= 1e-7+1e-6*abs(expected_default_se)

order analysis ageing_definition model variant matlab_beta stata_beta beta_difference ///
    matlab_se stata_se se_difference matlab_n stata_n sample_match ///
    matlab_regions stata_regions matlab_years stata_years classification notes
sort analysis ageing_definition model variant
format *beta* *se* *difference *p matlab_F first_stage_F %21.15g
save "${STATA_ROOT}/output/stata_matlab_comparison.dta", replace
export delimited using "${STATA_ROOT}/output/stata_matlab_comparison.csv", replace

preserve
    contract classification, freq(models)
    export delimited using "${STATA_ROOT}/output/comparison_summary.csv", replace
    list, noobs abbreviate(40)
restore
count if classification == "unresolved discrepancy"
local unresolved = r(N)
display "Unresolved comparisons: `unresolved'"
assert `unresolved' == 0

* Figure: coefficients with 95% intervals, as in the paper.
preserve
    keep if (analysis == "robustness" & model == "baseline_2011_220_10") ///
        | analysis == "identification"
    generate byte specification = 1 if model == "baseline_2011_220_10"
    replace specification = 2 if model == "country_year"
    replace specification = 3 if model == "region_trends"
    generate double position = specification + cond(ageing_definition=="LF",-.12,.12)
    generate double lower = stata_beta - 1.96*stata_se
    generate double upper = stata_beta + 1.96*stata_se
    twoway (rcap lower upper position if ageing_definition=="LF", horizontal lcolor(navy)) ///
        (scatter position stata_beta if ageing_definition=="LF", mcolor(navy) msymbol(O)) ///
        (rcap lower upper position if ageing_definition=="EMP", horizontal lcolor(maroon)) ///
        (scatter position stata_beta if ageing_definition=="EMP", mcolor(maroon) msymbol(D)), ///
        ylabel(1 "Region + year FE" 2 "Region + country-year FE" 3 "Region + year FE + trends", ///
            angle(horizontal) labsize(small)) yscale(reverse) ytitle("") ///
        xtitle("Ageing coefficient") xline(0, lcolor(gs10) lpattern(dash)) ///
        legend(order(2 "Labour force" 4 "Employment") rows(1) position(6) ///
            ring(1) size(small) region(lstyle(none))) xsize(8) ysize(4.8) ///
        graphregion(color(white)) plotregion(color(white)) ///
        title("Ageing under alternative fixed effects", size(medium)) ///
        note("Intervals: +/- 1.96 region-clustered SE. Common sample: 2,993 observations, 233 regions.", size(vsmall)) ///
        name(stronger_fe, replace)
    graph export "${STATA_ROOT}/output/stronger_fe_coefficients.png", width(2000) replace
    graph export "${STATA_ROOT}/output/stronger_fe_coefficients.pdf", replace
restore
