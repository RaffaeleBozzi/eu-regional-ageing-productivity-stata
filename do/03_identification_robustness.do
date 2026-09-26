* Country-year effects and region trends (MATLAB: Identification_Robustness.m).
version 19.0

foreach measure in lf emp {
    local definition = upper("`measure'")
    local ageing aging_`measure'_55_64
    use "${STATA_ROOT}/data/REG_`measure'_reg.dta", clear
    merge 1:1 geo year using "${STATA_ROOT}/data/sample_baseline_2011_220_10_`measure'.dta", ///
        keep(match) nogen

    quietly summarize region_id, meanonly
    local base_region = r(min)
    quietly summarize year, meanonly
    local base_year = r(min)

    capture drop country
    generate str2 country = substr(geo, 1, 2)
    egen long country_year = group(country year)

    * Region and country-year fixed effects.
    regress ${outcome} `ageing' ${controls} ///
        ib`base_region'.region_id ib1.country_year, vce(cluster region_id)
    record_result, analysis(identification) definition(`definition') ///
        model(country_year) variant(stata) term(`ageing') ///
        note("Region and country-year FE; redundant indicators omitted; t(G-1).")

    * Linear region trends in centred years, first region omitted as in the MATLAB code.
    quietly summarize year, meanonly
    generate double t_center = year - r(mean)
    quietly levelsof region_id, local(regions)
    foreach region of local regions {
        if `region' != `base_region' {
            generate double trend_`region' = (region_id == `region') * t_center
        }
    }

    regress ${outcome} `ageing' ${controls} ///
        ib`base_region'.region_id ib`base_year'.year trend_*, vce(cluster region_id)
    record_result, analysis(identification) definition(`definition') ///
        model(region_trends) variant(stata) term(`ageing') ///
        note("Region and year FE plus centered region trends; region-clustered; t(G-1).")
}
