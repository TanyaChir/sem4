* Discriminant analysis with TALIS 2024 teacher background variables
* Load the teacher file first. Do not save over the original file.

* 1. Missing codes -> missing (8 = not administered, 9 = omitted)
recode TT4G01 T4TAGEGR T4THEDAT T4TEMPWH T4TYEXPE T4CLSINF T4TNSCH ///
       T4TYEXPTS T4TYEXPTT T4TYEXPO TT4G10 TT4G09 TT4G08 TT4G04 (8 9 = .)

* In these variables 8 and 9 are valid values
recode T4TYQUAL (98 99 = .)
recode TT4G14 TT4G15 (998 999 = .)

* 2. Yes/no variables -> 0/1
recode TT4G01   (2 = 0)     // 1 = female,    0 = male
recode T4TEMPWH (2 = 0)     // 1 = full-time, 0 = part-time
recode TT4G08   (2 = 0)     // 1 = yes,       0 = no
recode TT4G10   (2 = 0)     // 1 = yes,       0 = no

* 3. First qualification (not ordered) -> dummies, 1 = regular programme is reference
recode TT4G04 (5 = 4)       // join "other" and "none"
tab TT4G04, gen(qual)       // creates qual1-qual4

* 4. Discriminant analysis
* Grouping variable: TT4G09 contract type (1 permanent, 2 fixed >1 yr, 3 fixed <=1 yr)
candisc TT4G01 T4TAGEGR T4THEDAT T4TYQUAL T4TEMPWH T4TYEXPE T4CLSINF T4TNSCH ///
        T4TYEXPTS T4TYEXPTT T4TYEXPO TT4G14 TT4G15 TT4G10 TT4G08            ///
        qual2 qual3 qual4, group(TT4G09)

estat loadings, standardized    // standardized coefficients
estat structure                 // structure matrix
estat classtable                // classification table (hit rate)
