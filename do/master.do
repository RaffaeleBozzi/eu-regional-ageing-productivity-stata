version 19.0
clear all
set more off
set linesize 120
set type double

* Run from the repository folder: do "do/master.do"
* or from anywhere: do "<path>/do/master.do" "<path>"
args root
if `"`root'"' == "" local root `"`c(pwd)'"'
global STATA_ROOT `"`root'"'
capture confirm file "${STATA_ROOT}/data/REG_lf_reg.csv"
if _rc {
    display as error "Run from the repository folder, or pass its path as the first argument."
    exit 601
}
capture mkdir "${STATA_ROOT}/output"
capture mkdir "${STATA_ROOT}/output/logs"
capture mkdir "${STATA_ROOT}/output/estimates"
capture log close _all
log using "${STATA_ROOT}/output/logs/master.log", text replace
display "Stata version: " c(stata_version)

global outcome ln_prod_real_gva_per_hour
global controls share_agri share_industry tertiary_education log_capital_labor_ratio_lag

do "${STATA_ROOT}/do/00_setup_import.do"
do "${STATA_ROOT}/do/lib/build_fe_samples.do"
do "${STATA_ROOT}/do/lib/record_result.do"

tempname result_handle key_handle
global RESULTS_HANDLE `result_handle'
global KEYS_HANDLE `key_handle'
postfile ${RESULTS_HANDLE} str20 analysis str3 ageing_definition str32 model ///
    str20 variant str32 term double(stata_beta stata_se stata_t stata_p ///
    stata_n stata_regions stata_years year_min year_max model_rank test_df ///
    r2_overall adj_r2_overall rmse_residual first_stage_F cluster_multiplier) ///
    str244 notes using "${STATA_ROOT}/output/stata_results.dta", replace
postfile ${KEYS_HANDLE} str20 analysis str3 ageing_definition str32 model ///
    str20 variant str4 geo int year using "${STATA_ROOT}/output/stata_sample_keys.dta", replace

foreach step in 01_baseline_models 02_fe_robustness 03_identification_robustness ///
    04_endogeneity_test 05_first_stage_iv 06_fe_2sls {
    display _newline "Running `step'"
    capture noisily do "${STATA_ROOT}/do/`step'.do"
    local rc = _rc
    if `rc' {
        capture postclose ${RESULTS_HANDLE}
        capture postclose ${KEYS_HANDLE}
        display as error "Stopped in `step'; return code `rc'."
        log close
        exit `rc'
    }
}
postclose ${RESULTS_HANDLE}
postclose ${KEYS_HANDLE}
do "${STATA_ROOT}/do/07_compare_matlab_stata.do"
display _newline "STATA_REPLICATION_COMPLETE"
log close
