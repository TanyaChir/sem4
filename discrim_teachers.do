* ==========================================================================
* Discriminant analysis with TALIS 2024 teacher background variables
* ==========================================================================
* Run this after loading the teacher file, e.g.:  use "TT4_teachers.dta", clear
* In the TALIS file, codes 8/98/998 mean "Not administered" and 9/99/999 mean
* "Omitted or invalid". Both are recoded to Stata missing values below.

version 16
set more off

* --------------------------------------------------------------------------
* 0. Make copies so the original variables stay untouched
* --------------------------------------------------------------------------
foreach v in TT4G01 T4TAGEGR T4THEDAT T4TYQUAL T4TEMPWH T4TYEXPE T4CLSINF ///
             T4TNSCH T4TYEXPTS T4TYEXPTT T4TYEXPO TT4G14 TT4G10 TT4G09   ///
             TT4G15 TT4G08 TT4G04 {
    clonevar r_`v' = `v'
}

* --------------------------------------------------------------------------
* 1. Missing codes -> Stata missing (.n = not administered, .o = omitted)
* --------------------------------------------------------------------------
* 1-digit variables: 8 / 9
mvdecode r_TT4G01 r_T4TAGEGR r_T4THEDAT r_T4TEMPWH r_T4TYEXPE r_T4CLSINF ///
         r_T4TNSCH r_T4TYEXPTS r_T4TYEXPTT r_T4TYEXPO r_TT4G10 r_TT4G09  ///
         r_TT4G08 r_TT4G04, mv(8 = .n \ 9 = .o)
* 2-digit variable: 98 / 99
mvdecode r_T4TYQUAL, mv(98 = .n \ 99 = .o)
* 3-digit (hours) variables: 998 / 999
mvdecode r_TT4G14 r_TT4G15, mv(998 = .n \ 999 = .o)

* --------------------------------------------------------------------------
* 2. Recode into analysis variables
* --------------------------------------------------------------------------
* -- Binary variables -> 0/1 dummies
recode r_TT4G01 (1 = 1 "Female") (2 = 0 "Male"),          gen(female)
recode r_T4TEMPWH (1 = 1 "Full-time") (2 = 0 "Part-time"), gen(fulltime)
recode r_TT4G08 (1 = 1 "Yes") (2 = 0 "No"),                gen(firstchoice)
recode r_TT4G10 (1 = 1 "Yes") (2 = 0 "No"),                gen(otherlevel)
label var female      "Female teacher"
label var fulltime    "Full-time (>90% hours)"
label var firstchoice "Teaching was first career choice"
label var otherlevel  "Also teaches another ISCED level elsewhere"

* -- Ordinal variables: higher value = more of the trait (used as scores)
gen age_gr   = r_T4TAGEGR      // 1 = under 29 ... 5 = 60+
gen educ     = r_T4THEDAT      // 1 = below ISCED 5 ... 5 = ISCED 8
gen yqual    = r_T4TYQUAL      // year of first qualification (grouped)
gen exp_tot  = r_T4TYEXPTT     // total teaching experience
gen exp_sch  = r_T4TYEXPTS     // experience at this school
gen exp_edu  = r_T4TYEXPE      // other education roles
gen exp_oth  = r_T4TYEXPO      // non-education roles
gen nschools = r_T4TNSCH       // 0 / 1 / 2+ other schools
gen infra    = r_T4CLSINF      // 1 = not a problem ... 3 = a problem
label var age_gr   "Age group"
label var educ     "Highest education (ISCED)"
label var yqual    "Year of first teaching qualification (grouped)"
label var exp_tot  "Years of experience, total"
label var exp_sch  "Years of experience, this school"
label var exp_edu  "Years in other education roles"
label var exp_oth  "Years in non-education roles"
label var nschools "Number of other schools"
label var infra    "Classroom infrastructure problem"

* -- Continuous: working hours (implausible values set to missing)
gen hrs_total = r_TT4G14 if inrange(r_TT4G14, 0, 80)
gen hrs_teach = r_TT4G15 if inrange(r_TT4G15, 0, 60)
replace hrs_teach = . if hrs_teach > hrs_total & !missing(hrs_teach, hrs_total)
label var hrs_total "Total working hours per week"
label var hrs_teach "Teaching hours per week"

* -- Nominal: first qualification type -> dummies (reference = regular programme)
recode r_TT4G04 (1 = 1 "Regular programme")            ///
                (2 = 2 "Fast-track/specialised")       ///
                (3 = 3 "Subject-specific only")        ///
                (4/5 = 4 "Other / none"), gen(qualtype)
tabulate qualtype, gen(q_)
rename (q_2 q_3 q_4) (q_fast q_subj q_other)
drop q_1
label var q_fast  "Qualification: fast-track/specialised"
label var q_subj  "Qualification: subject-specific only"
label var q_other "Qualification: other / none"

* --------------------------------------------------------------------------
* 3. Grouping variable (the outcome the discriminant functions separate)
* --------------------------------------------------------------------------
* Default: contract type (3 groups). To use another grouping, change the
* recode below and remove that variable from the predictor list.
recode r_TT4G09 (1 = 1 "Permanent")                  ///
                (2 = 2 "Fixed-term > 1 year")        ///
                (3 = 3 "Fixed-term <= 1 year"), gen(group)
label var group "Contract type"

* --------------------------------------------------------------------------
* 4. Predictors and sample check
* --------------------------------------------------------------------------
global X female age_gr educ yqual fulltime exp_tot exp_sch exp_edu exp_oth ///
         nschools infra firstchoice otherlevel hrs_total hrs_teach        ///
         q_fast q_subj q_other

* Several questions were "Not administered" for large parts of the sample
* (gender: 170k of 278k). Listwise deletion can shrink the sample a lot,
* so look at this before running the model.
misstable summarize group $X
mark complete
markout complete group $X
tab complete
* If too few cases remain, drop the predictors with the most missing values
* from $X (or run the analysis by country).

* Descriptives by group
tabstat $X if complete, by(group) statistics(mean sd) columns(statistics) ///
        longstub format(%6.2f)

* Correlations: check for multicollinearity (|r| > .8 is a problem)
pwcorr $X if complete

* --------------------------------------------------------------------------
* 5. Assumptions
* --------------------------------------------------------------------------
* Equality of covariance matrices across groups (Box's M).
* With n this large it will almost always be significant; if so, compare
* with quadratic DA (step 7) instead of treating it as a stopper.
mvtest covariances $X if complete, by(group)

* --------------------------------------------------------------------------
* 6. Linear discriminant analysis (canonical)
* --------------------------------------------------------------------------
candisc $X if complete, group(group) priors(proportional)

* Significance of each discriminant function (Wilks' lambda)
estat canontest
* Standardized coefficients: relative contribution of each predictor
estat loadings, standardized
* Structure matrix: correlation of each predictor with each function
estat structure
* Group means on the discriminant functions (centroids)
estat grmeans, totalstd
* Univariate F tests: which predictors differ across groups
estat anova
* Classification table (hit rate)
estat classtable, nototals
* Compare hit rate with chance level
tab group if complete

* Save discriminant scores and predicted group
predict ld1 ld2 if complete, dscore
predict group_hat if complete, classification
label var ld1 "Discriminant function 1"
label var ld2 "Discriminant function 2"

* Plot groups on the two functions
scoreplot, msymbol(i) mlabel(group) mlabsize(tiny)
* For a lighter plot on a large sample:
* twoway (scatter ld2 ld1 if group==1 & runiform()<.05, msize(tiny)) ///
*        (scatter ld2 ld1 if group==2 & runiform()<.05, msize(tiny)) ///
*        (scatter ld2 ld1 if group==3 & runiform()<.05, msize(tiny)), ///
*        legend(order(1 "Permanent" 2 "Fixed > 1 yr" 3 "Fixed <= 1 yr"))

* --------------------------------------------------------------------------
* 7. Robustness: quadratic DA (if Box's M rejected equal covariances)
* --------------------------------------------------------------------------
discrim qda $X if complete, group(group) priors(proportional) notable
estat classtable, nototals
