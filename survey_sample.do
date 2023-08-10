
// PROJECT: SURVEY SAMPLE
// AUTHOR: ROBERTO VACANTE

ssc install estout, replace
set seed 12345
local dir `c(pwd)'
cap mkdir mysurvey
clear

**# SECTION 1 - SAMPLE DATA GENERATING

* dates
set obs 1000
gen numdate = floor((mdy(12,31,2020)-mdy(1,1,2010)+1)*runiform() + mdy(1,1,2010))
gen date = strofreal(numdate, "%tdNN-DD-CCYY")
drop numdate

* random choice variables
gen dummy = uniform() < .5
gen indicator = "Male"
replace indicator = "Female" if dummy == 0

* discrete choice variable 
gen num_var = runiformint(1,10)

* IDs generation
while 1 {
	cap drop id
	gen id = ""
	local N = _N
	forv j = 1/`N' {
		local id = ""
		forv i = 1/6 {
			local randi = char(floor((90 - 65) * runiform() + 65))
			// "char" command allows ASCII code conversion, where the range 65-90 covers capital letters.  Thus, the following lines fill the variable `id` with random capital letters for each observation, making an ID code.
			local id = "`id'`randi'"
		} 
		qui replace id = "`id'" in `j'
	}
// furthermore, this loop ends only when each ID is different, ensuring the uniqueness of IDs.
	qui duplicates report id
	if r(unique_value) == r(N) {
		exit
	}
}

**# SECTION 2 - CSV EXPORT FOR EACH RESPONDENT
local N = _N
forv i = 1/`N' {
	preserve 
	keep in `i'
	outsheet id date indicator num_var using "mysurvey/respondent`i'.csv", replace  // command "outsheet" allows file exporting of the selected variables.
	restore
}

**# SECTION 3 - SURVEY ANALYSIS

*specify survey design in stata
svyset id, vce(linearized) singleunit(missing)

* survey twoway table
estpost svy: tab indicator num_var, col percent

* twoway table exporting in `table1.tex`
local a = 1
local nrow = 3
local ncol = 11
matrix table1 = J(`nrow',`ncol', .)
forv j = 1/`ncol' {
	forv i = 1/`nrow' {
		matrix table1[`i', `j'] = e(b)[1,`a']
			local a = `a' + 1
			}
		}
matrix rownames table1 = "Male" "Female" "Total"
matrix colnames table1 = "1" "2" "3" "4" "5" "6" "7" "8" "9" "10" "Total"
outtable using "table1", mat(table1) replace nobox center


**# SECTION 4 - OBSERVATION APPEND

// since the "append" command would require a time-consuming dta format, the following routine join each csv file, generating again the dataset.
import delimited "mysurvey/respondent1.csv", varnames(1) stringcols(4) clear 
set obs 1000

local N = _N  
forv i = 2/`N' {
	preserve
	qui import delimited "mysurvey/respondent`i'.csv", varnames(1) stringcols(4) clear
	foreach v of varlist _all {
		local `v'_app = `v'[1]   // it saves the first observation in a local
	}
	restore
	foreach v of varlist _all {
		qui replace `v' = "``v'_app'" in `i'
	}
}


**# SECTION 5 - TESTING FOR DATA REPRODUCIBILITY

// when the first dofile execution occurs, "dataset.dta" has not been generated yet. Hence, the loop verifies whether `dataset.dta` already exists and (if it does) executes the "reproducibility check". This means that the command "cf" will check for data reproducibility only at the second execution.

preserve
cap use "dataset.dta", clear
if _rc == 0 {
	cf _all using "dataset.dta", all
}
restore
save "dataset.dta", replace

**# SECTION 6 - TESTING FOR GOODNESS OF FIT

// the sex indicator variable "Male"/"Female" has been generated randomly following a uniform distribution. Hence, we expect the amount of male to be close to the amount to females.
bys indicator: egen ind_freq = count(indicator)
bys num_var: egen ind1_freq = count(num_var)
local mean_ind = `N'/2
ttest ind_freq == `mean_ind'
drop ind*

**# SECTION 7 - MAIN TEX FILE EXPORT

local nl = char(10) // this local stores the ASCII character 10 which is used as a line delimiter.
cap file close texfile
file open texfile using "write_sample.tex", replace write
file write texfile "\documentclass[aspectratio = 169]{beamer} `nl' \usetheme{Berlin} `nl' \usepackage{graphicx} `nl' \usepackage{booktabs} `nl' \usepackage{amsmath} `nl' \usepackage{footmisc} `nl' \usepackage{float} `nl' \usepackage{hyperref} `nl' \usepackage{xcolor} `nl'\usepackage{ragged2e} `nl' \title{Survey Simulation} `nl' \subtitle{Writing Sample} `nl' \author{Roberto Vacante} `nl' \date{} `nl' \begin{document} `nl' \begin{frame} `nl' \maketitle `nl' \end{frame} `nl' \begin{frame}{Survey} `nl' \scalebox{0.65}{% `nl' \renewenvironment{table}[1][]{\ignorespaces}{\unskip}% `nl' \input{table1} `nl' \unskip `nl' } `nl' \end{frame} `nl' \end{document}"
file close texfile 



