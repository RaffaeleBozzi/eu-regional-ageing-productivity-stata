version 19.0

* Region-year keys of the LF and EMP panels.
tempfile emp_keys all_keys
use "${STATA_ROOT}/data/REG_emp_reg.dta", clear
keep geo year
generate byte panel = 2
save `emp_keys'
use "${STATA_ROOT}/data/REG_lf_reg.dta", clear
keep geo year
generate byte panel = 1
append using `emp_keys'
isid panel geo year
save `all_keys'

* Main sample (Estimation.m): years with at least 220 regions in both panels,
* then regions with at least 10 of those years.
bysort year: egen long n_lf = total(panel == 1)
bysort year: egen long n_emp = total(panel == 2)
keep if n_lf >= 220 & n_emp >= 220
drop n_lf n_emp
bysort geo: egen long n_lf = total(panel == 1)
bysort geo: egen long n_emp = total(panel == 2)
keep if n_lf >= 10 & n_emp >= 10

foreach measure in lf emp {
    preserve
    local panel_id = cond("`measure'" == "lf", 1, 2)
    keep if panel == `panel_id'
    keep geo year
    isid geo year
    sort geo year
    save "${STATA_ROOT}/data/sample_main_`measure'.dta", replace
    restore
}

* Robustness samples (Estimation_Robustness.m): from the start year, drop regions
* and years below the thresholds until nothing changes.
foreach rule in baseline_2011_220_10 stricter_2011_230_10 later_2013_220_10 {
    local start_year = cond("`rule'" == "later_2013_220_10", 2013, 2011)
    local min_regions = cond("`rule'" == "stricter_2011_230_10", 230, 220)
    local min_years = 10

    use `all_keys', clear
    keep if year >= `start_year'
    bysort year: egen long year_lf = total(panel == 1)
    bysort year: egen long year_emp = total(panel == 2)
    bysort geo: egen long region_lf = total(panel == 1)
    bysort geo: egen long region_emp = total(panel == 2)
    keep if year_lf > 0 & year_emp > 0 & region_lf > 0 & region_emp > 0
    drop year_lf year_emp region_lf region_emp

    local converged = 0
    forvalues iteration = 1/20 {
        local rows_before = _N
        bysort geo: egen long region_lf = total(panel == 1)
        bysort geo: egen long region_emp = total(panel == 2)
        keep if region_lf >= `min_years' & region_emp >= `min_years'
        drop region_lf region_emp

        bysort year: egen long year_lf = total(panel == 1)
        bysort year: egen long year_emp = total(panel == 2)
        keep if year_lf >= `min_regions' & year_emp >= `min_regions'
        drop year_lf year_emp

        * Stop when an iteration drops nothing.
        if _N == `rows_before' {
            local converged = 1
            continue, break
        }
    }
    assert `converged' == 1
    assert _N > 0

    foreach measure in lf emp {
        preserve
        local panel_id = cond("`measure'" == "lf", 1, 2)
        keep if panel == `panel_id'
        keep geo year
        isid geo year
        sort geo year
        save "${STATA_ROOT}/data/sample_`rule'_`measure'.dta", replace
        restore
    }
}
