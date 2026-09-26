* FE OLS and FE-2SLS on the IV sample (MATLAB: IV_2SLS_FE.m).
version 19.0

foreach definition in lf emp {
    use "${STATA_ROOT}/data/REG_`definition'_reg_iv.dta", clear
    local age aging_`definition'_55_64
    local label = upper("`definition'")

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

    * FE OLS; keep its sample to check that 2SLS uses the same observations.
    regress ${outcome} `age' ${controls} ///
        i.region_id i.year, vce(cluster region_id)
    generate byte ols_sample = e(sample)
    assert ols_sample == 1
    assert e(N) == 2815 & e(N_clust) == 226 & e(df_r) == 225
    record_result, analysis(iv) definition(`label') ///
        model(same_sample_ols) variant(stata) term(`age') ///
        note("FE OLS on the exact IV complete-case sample.")

    * FE-2SLS with Stata's default clustered standard errors.
    ivregress 2sls ${outcome} ${controls} i.region_id i.year ///
        (`age' = iv_ageing_pred_lag10), vce(cluster region_id)
    assert e(sample) == ols_sample
    assert e(N) == 2815 & e(N_clust) == 226
    local default_beta = _b[`age']
    local default_se = _se[`age']
    record_result, analysis(iv) definition(`label') ///
        model(fe_2sls) variant(stata_default) term(`age') ///
        note("Default ivregress: unadjusted cluster covariance and normal inference.")

    * With small: the finite-sample correction and t(G-1) used in the MATLAB code.
    * K = 243: constant, 4 controls, 225 region and 12 year dummies, ageing.
    ivregress 2sls ${outcome} ${controls} i.region_id i.year ///
        (`age' = iv_ageing_pred_lag10), vce(cluster region_id) small
    assert e(sample) == ols_sample
    assert e(N) == 2815 & e(N_clust) == 226 & e(df_r) == 225
    assert reldif(_b[`age'], `default_beta') < 1e-10
    local correction = (226/225)*((2815-1)/(2815-243))
    assert reldif(_se[`age'] / `default_se', sqrt(`correction')) < 1e-8
    record_result, analysis(iv) definition(`label') ///
        model(fe_2sls) variant(stata) term(`age') ///
        note("ivregress small: MATLAB finite-sample cluster correction; t(225).")

    preserve
        keep geo year
        export delimited using ///
            "${STATA_ROOT}/output/iv_sample_`definition'.csv", replace
    restore
}
