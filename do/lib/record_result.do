version 19.0
capture program drop record_result
program define record_result
    syntax, ANALysis(string) DEFinition(string) MODel(string) VARiant(string) ///
        TERM(string) [NOTE(string) FIRSTF(real -1)]
    if `firstf' < 0 local firstf = .
    * Post one coefficient and its sample; save the full estimates.
    tempname b se t p df k n g ny ymin ymax r2 ar2 rmse multiplier ss_total ss_error
    scalar `b' = _b[`term']
    scalar `se' = _se[`term']
    scalar `t' = `b' / `se'
    scalar `df' = e(df_r)
    scalar `p' = cond(missing(`df'), 2*normal(-abs(`t')), 2*ttail(`df',abs(`t')))
    scalar `n' = e(N)
    * K: number of estimated coefficients, omitted dummies excluded.
    quietly _ms_omit_info e(b)
    scalar `k' = colsof(e(b)) - r(k_omit)
    tempvar used region_tag year_tag fitted sq_residual
    generate byte `used' = e(sample)
    quietly count if `used'
    assert r(N) == `n'
    quietly egen byte `region_tag' = tag(geo) if `used'
    quietly count if `region_tag' == 1
    scalar `g' = r(N)
    quietly egen byte `year_tag' = tag(year) if `used'
    quietly count if `year_tag' == 1
    scalar `ny' = r(N)
    quietly summarize year if `used', meanonly
    scalar `ymin' = r(min)
    scalar `ymax' = r(max)
    scalar `multiplier' = .
    if "`e(vce)'" == "cluster" {
        scalar `multiplier' = (`g'/(`g'-1))*((`n'-1)/(`n'-`k'))
        if "`e(cmd)'" == "ivregress" & missing(`df') scalar `multiplier' = 1
    }
    * R-squared and RMSE from the fitted values.
    local dependent `e(depvar)'
    quietly predict double `fitted' if `used', xb
    quietly generate double `sq_residual' = (`dependent'-`fitted')^2 if `used'
    quietly summarize `sq_residual', meanonly
    scalar `ss_error' = r(sum)
    quietly summarize `dependent' if `used'
    scalar `ss_total' = (r(N)-1)*r(Var)
    scalar `r2' = 1-`ss_error'/`ss_total'
    scalar `ar2' = 1-(`ss_error'/(`n'-`k'))/(`ss_total'/(`n'-1))
    scalar `rmse' = sqrt(`ss_error'/(`n'-`k'))
    estimates save "${STATA_ROOT}/output/estimates/`analysis'_`definition'_`model'_`variant'.ster", replace
    post ${RESULTS_HANDLE} ("`analysis'") ("`definition'") ("`model'") ///
        ("`variant'") ("`term'") (`b') (`se') (`t') (`p') ///
        (`n') (`g') (`ny') (`ymin') (`ymax') (`k') (`df') ///
        (`r2') (`ar2') (`rmse') (`firstf') (`multiplier') ("`note'")
    preserve
        quietly keep if `used'
        quietly keep geo year
        sort geo year
        forvalues row = 1/`=_N' {
            post ${KEYS_HANDLE} ("`analysis'") ("`definition'") ///
                ("`model'") ("`variant'") (geo[`row']) (year[`row'])
        }
    restore
end
