* Import and check the four regression panels.
version 19.0
clear all
set more off

* The root folder is set by master.do; otherwise the current directory is used.
if "${STATA_ROOT}" == "" global STATA_ROOT `"`c(pwd)'"'
tempname audit
postfile `audit' str20 dataset double(nobs regions years first_year last_year ///
    missing_model_vars available_iv) using "${STATA_ROOT}/output/data_audit.dta", replace

foreach measure in lf emp {
    foreach suffix in "" "_iv" {
        local dataset REG_`measure'_reg`suffix'
        import delimited using "${STATA_ROOT}/data/`dataset'.csv", ///
            clear varnames(1) case(preserve) encoding("utf-8") asdouble
        * Missing values are stored as NaN in the CSVs.
        local required ln_prod_real_gva_per_hour aging_`measure'_55_64 ///
            share_agri share_industry tertiary_education log_capital_labor_ratio_lag
        local numeric `required' year
        if "`suffix'" == "_iv" local numeric `numeric' ///
            iv_ageing_pred_lag10 iv_share_45_49_lag10 iv_share_50_54_lag10
        foreach var of local numeric {
            capture confirm numeric variable `var'
            if _rc destring `var', replace ignore("NaN")
        }
        assert !missing(geo, year)
        assert strlen(geo) == 4
        isid geo year
        assert _N == 5089
        egen byte region_tag = tag(geo)
        quietly count if region_tag
        local regions = r(N)
        assert `regions' == 243
        egen byte year_tag = tag(year)
        quietly count if year_tag
        local years = r(N)
        assert `years' == 23
        quietly summarize year, meanonly
        local first_year = r(min)
        local last_year = r(max)
        assert `first_year' == 2001 & `last_year' == 2023
        egen byte model_missing = rowmiss(`required')
        quietly count if model_missing
        local incomplete = r(N)
        assert `incomplete' == 0
        local available_iv = .
        if "`suffix'" == "_iv" {
            quietly count if !missing(iv_ageing_pred_lag10)
            local available_iv = r(N)
            assert `available_iv' == 2815
        }
        post `audit' ("`dataset'") (_N) (`regions') (`years') ///
            (`first_year') (`last_year') (`incomplete') (`available_iv')
        drop region_tag year_tag model_missing
        encode geo, generate(region_id)
        xtset region_id year
        describe
        summarize `required' year
        misstable summarize `required'
        if "`suffix'" == "_iv" misstable summarize iv_ageing_pred_lag10
        sort geo year
        save "${STATA_ROOT}/data/`dataset'.dta", replace
    }
}
postclose `audit'
use "${STATA_ROOT}/output/data_audit.dta", clear
export delimited using "${STATA_ROOT}/output/data_audit.csv", replace
