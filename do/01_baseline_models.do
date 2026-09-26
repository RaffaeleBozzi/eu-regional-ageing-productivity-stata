* Pooled regressions and two-way FE (MATLAB: Estimation.m).
version 19.0

foreach measure in lf emp {
    local definition = upper("`measure'")
    local ageing aging_`measure'_55_64
    use "${STATA_ROOT}/data/REG_`measure'_reg.dta", clear

    * Pooled models: rreg is the closest built-in match for MATLAB's robust fitlm.
    rreg ${outcome} `ageing', tolerance(1e-10) iterate(1000) genwt(weight_ageing)
    record_result, analysis(baseline) definition(`definition') model(pooled_ageing) ///
        variant(rreg) term(`ageing') ///
        note("Stata rreg: Cook screening, Huber then biweight; distinct from MATLAB fitlm bisquare.")

    rreg ${outcome} `ageing' ${controls}, tolerance(1e-10) iterate(1000) genwt(weight_controls)
    record_result, analysis(baseline) definition(`definition') model(pooled_controls) ///
        variant(rreg) term(`ageing') ///
        note("Stata rreg: Cook screening, Huber then biweight; distinct from MATLAB fitlm bisquare.")
    preserve
        keep geo year weight_ageing weight_controls
        export delimited using "${STATA_ROOT}/output/pooled_weights_`measure'.csv", replace
    restore

    * Plain OLS with robust standard errors, for comparison.
    regress ${outcome} `ageing', vce(robust)
    record_result, analysis(baseline) definition(`definition') model(pooled_ageing) ///
        variant(ols_hc1) term(`ageing') ///
        note("Standard OLS with HC1 standard errors; separate from the published robust-fit estimator.")
    regress ${outcome} `ageing' ${controls}, vce(robust)
    record_result, analysis(baseline) definition(`definition') model(pooled_controls) ///
        variant(ols_hc1) term(`ageing') ///
        note("Standard OLS with HC1 standard errors; separate from the published robust-fit estimator.")

    merge 1:1 geo year using "${STATA_ROOT}/data/sample_main_`measure'.dta", keep(match) nogen
    assert _N == 2993
    * Two-way FE on the main sample, with conventional standard errors as in the paper.
    regress ${outcome} `ageing' ${controls} i.region_id i.year
    record_result, analysis(baseline) definition(`definition') model(fe) ///
        variant(stata) term(`ageing') note("Main single-pass coverage sample; conventional standard errors.")
}
