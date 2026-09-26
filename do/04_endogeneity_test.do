* Control-function endogeneity test (MATLAB: Endogeneity_Test_IV.m).
version 19.0

foreach definition in lf emp {
    use "${STATA_ROOT}/data/REG_`definition'_reg_iv.dta", clear
    local age aging_`definition'_55_64
    local label = upper("`definition'")

    * IV sample: complete cases for outcome, ageing, instrument and controls.
    egen byte n_missing = rowmiss(${outcome} `age' iv_ageing_pred_lag10 ${controls})
    keep if n_missing == 0
    drop n_missing
    sort geo year
    isid geo year
    assert _N == 2815
    egen byte region_tag = tag(region_id)
    quietly count if region_tag
    assert r(N) == 226
    egen byte year_tag = tag(year)
    quietly count if year_tag
    assert r(N) == 13
    quietly summarize year, meanonly
    assert r(min) == 2011 & r(max) == 2023
    drop region_tag year_tag

    * First stage, keeping the residual.
    regress `age' iv_ageing_pred_lag10 ${controls} ///
        i.region_id i.year, vce(cluster region_id)
    assert e(N) == 2815 & e(N_clust) == 226 & e(df_r) == 225
    predict double vhat, residuals
    assert !missing(vhat)
    test iv_ageing_pred_lag10
    local first_f = r(F)

    * Add the residual to the FE equation and test its coefficient.
    regress ${outcome} `age' ${controls} vhat ///
        i.region_id i.year, vce(cluster region_id)
    assert e(N) == 2815 & e(N_clust) == 226 & e(df_r) == 225
    test vhat
    record_result, analysis(endogeneity) definition(`label') ///
        model(control_function) variant(stata) term(vhat) firstf(`first_f') ///
        note("Clustered control-function test; does not establish instrument validity.")

    preserve
        keep geo year vhat
        export delimited using ///
            "${STATA_ROOT}/output/control_function_residuals_`definition'.csv", replace
    restore
}
