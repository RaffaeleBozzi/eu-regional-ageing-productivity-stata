* First stage of the IV model (MATLAB: First_Stage_IV.m).
version 19.0

foreach definition in lf emp {
    use "${STATA_ROOT}/data/REG_`definition'_reg_iv.dta", clear
    local age aging_`definition'_55_64
    local label = upper("`definition'")

    * MATLAB builds this sample without the outcome variable; check it matches the IV sample.
    egen byte first_missing = rowmiss(`age' iv_ageing_pred_lag10 ${controls})
    egen byte iv_missing = rowmiss(${outcome} `age' iv_ageing_pred_lag10 ${controls})
    assert (first_missing == 0) == (iv_missing == 0)
    keep if first_missing == 0
    drop first_missing iv_missing
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

    regress `age' iv_ageing_pred_lag10 ${controls} ///
        i.region_id i.year, vce(cluster region_id)
    assert e(N) == 2815 & e(N_clust) == 226 & e(df_r) == 225

    * One instrument, so F = t^2.
    test iv_ageing_pred_lag10
    local first_f = r(F)
    assert reldif(`first_f', (_b[iv_ageing_pred_lag10] / ///
        _se[iv_ageing_pred_lag10])^2) < 1e-10
    record_result, analysis(first_stage) definition(`label') ///
        model(first_stage) variant(stata) term(iv_ageing_pred_lag10) ///
        firstf(`first_f') note("One excluded IV; clustered F equals t squared.")

    preserve
        contract year
        rename _freq n_regions
        export delimited using ///
            "${STATA_ROOT}/output/iv_year_coverage_`definition'.csv", replace
    restore
}
