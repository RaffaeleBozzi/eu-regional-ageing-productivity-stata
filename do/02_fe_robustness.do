* Two-way FE under three sample rules (MATLAB: Estimation_Robustness.m).
version 19.0

foreach rule in baseline_2011_220_10 stricter_2011_230_10 later_2013_220_10 {
    foreach measure in lf emp {
        local definition = upper("`measure'")
        local ageing aging_`measure'_55_64
        use "${STATA_ROOT}/data/REG_`measure'_reg.dta", clear
        merge 1:1 geo year using "${STATA_ROOT}/data/sample_`rule'_`measure'.dta", ///
            keep(match) nogen

        quietly summarize region_id, meanonly
        local base_region = r(min)
        quietly summarize year, meanonly
        local base_year = r(min)

        * Two-way FE, standard errors clustered by region.
        regress ${outcome} `ageing' ${controls} ///
            ib`base_region'.region_id ib`base_year'.year, vce(cluster region_id)
        record_result, analysis(robustness) definition(`definition') ///
            model(`rule') variant(stata) term(`ageing') ///
            note("Region-clustered OLS; common iterative coverage sample; t(G-1).")
    }
}
