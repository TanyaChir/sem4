* Discriminant analysis with TALIS 2024 teacher background variables
* Load the teacher file first, e.g.:  use "TT4_teachers.dta", clear

* ---- 1. Recode (gen() keeps the original variables unchanged) ----------

* Yes/no items -> 0/1 ; 8 = not administered, 9 = omitted -> missing
recode TT4G01   (1=1 "Female")    (2=0 "Male")      (8 9=.), gen(female)
recode T4TEMPWH (1=1 "Full-time") (2=0 "Part-time") (8 9=.), gen(fulltime)
recode TT4G08   (1=1 "Yes")       (2=0 "No")        (8 9=.), gen(firstchoice)

* Ordered categories: keep values, only set 8/9 to missing
recode T4TAGEGR T4THEDAT T4TYEXPTT T4TYEXPTS T4TYEXPE T4TYEXPO T4TNSCH T4CLSINF ///
       (8 9=.), gen(age educ exp_tot exp_sch exp_edu exp_oth nschools infra)

* Here 8 and 9 are valid values, so missing codes are 98/99 and 998/999
recode T4TYQUAL      (98 99=.),   gen(yqual)
recode TT4G14 TT4G15 (998 999=.), gen(hrs_total hrs_teach)

* Qualification type is not ordered -> dummies (reference = regular programme)
recode TT4G04 (8 9=.) (5=4), gen(qualtype)
tab qualtype, gen(q)          // creates q1-q4; q1 is the reference

* Grouping variable: contract type
recode TT4G09 (8 9=.), gen(group)

* ---- 2. Sample and descriptives ----------------------------------------
global X female age educ yqual fulltime exp_tot exp_sch exp_edu exp_oth ///
         nschools infra firstchoice hrs_total hrs_teach q2 q3 q4

misstable summarize group $X       // how much is missing per variable
mark ok
markout ok group $X                // ok = 1 if no missing values
tab ok

tabstat $X if ok, by(group) stat(mean)

* ---- 3. Discriminant analysis ------------------------------------------
mvtest covariances $X if ok, by(group)   // Box's M

candisc $X if ok, group(group) priors(proportional)
estat loadings, standardized             // standardized coefficients
estat structure                          // structure matrix
estat classtable                         // hit rate
