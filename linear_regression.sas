*Kevin Pleli
*import data from file;
data valuations;
*Adjust length of string variables to 30 characters;
length Team $30.;
length PlayoffAppearance $30.;
length MVPCyYoungWinner $30.;
title 'MLB Valuations data set 2009-2018';
INFILE "MLB_Valuation_Chart.csv" Delimiter=',' MISSOVER FirstObs=2;
input Team $ Year TeamValuation Revenue OperatingIncome PlayerExpenses GateReceipts MetroAreaPopulation StadiumYearBuilt StadiumAge 
AverageAttendance AverageTicketPrice FanCostIndex RecordPercentage NumberofAllStars MVPCyYoungWinner PlayoffAppearance WorldSeriesChampionship
;
run;

*print imported dataset valuations;
proc print;
run;

*create dummy variables for categorical variables and interaction terms;
data valuations;
set valuations;
title 'MLB Valuations data set w/dummy variables 2009-2018';
CyYoungAward =(MVPCyYoungWinner = 'Cy Young');
MVPAward = (MVPCyYoungWinner = 'MVP');
BothAwards = (MVPCyYoungWinner = 'MVP and Cy Young');
PlayoffWild = (PlayoffAppearance = 'Wild Card');
PlayoffDS = (PlayoffAppearance = 'ALDS') OR (PlayoffAppearance = 'NLDS');
PlayoffCS = (PlayoffAppearance = 'ALCS') OR (PlayoffAppearance = 'NLCS');
PlayoffWS = (PlayoffAppearance = 'WS');
AvgAttendence_RecordPercentage = AverageAttendance*RecordPercentage;
AvgAttendence_NumAllstars = AverageAttendance*NumberofAllStars;
run;

proc print;
run;

*Histogram for TeamValuation;
title 'TeamValuation Histogram';
proc univariate normal;
var TeamValuation;
histogram/normal (mu=est sigma=est);
run;

*Descriptives for TeamValuation;
proc means min p25 p50 p75 max;
var TeamValuation;
run;

*Transform TeamValuation variable;
data valuations;
set valuations;
ln_TeamValuation = log(TeamValuation);
run;

proc print;
run;

*Histogram for ln_TeamValuation;
title 'TeamValuation Histogram';
proc univariate normal;
var ln_TeamValuation;
histogram/normal (mu=est sigma=est);
run;

*Scatterplots ;
PROC GPLOT;
PLOT ln_TeamValuation*(Revenue OperatingIncome PlayerExpenses GateReceipts MetroAreaPopulation StadiumAge
AverageAttendance AverageTicketPrice FanCostIndex RecordPercentage);
RUN;

*Full regression model;
proc reg;
model ln_TeamValuation = Revenue OperatingIncome PlayerExpenses GateReceipts MetroAreaPopulation StadiumAge AverageAttendance AverageTicketPrice FanCostIndex 
RecordPercentage NumberofAllStars WorldSeriesChampionship CyYoungAward MVPAward BothAwards PlayoffWild PlayoffDS PlayoffCS PlayoffWS AvgAttendence_RecordPercentage
AvgAttendence_NumAllstars; 
run;

*Generate Pearson Correlation Coefficients;
proc corr;
var ln_TeamValuation Revenue OperatingIncome PlayerExpenses GateReceipts MetroAreaPopulation StadiumAge
AverageAttendance AverageTicketPrice FanCostIndex RecordPercentage;
run;

*Check multicollinearity;
proc reg;
model ln_TeamValuation = Revenue OperatingIncome PlayerExpenses GateReceipts MetroAreaPopulation StadiumAge AverageAttendance AverageTicketPrice FanCostIndex 
RecordPercentage NumberofAllStars WorldSeriesChampionship CyYoungAward MVPAward BothAwards PlayoffWild PlayoffDS PlayoffCS PlayoffWS /vif; 
run;

*Check multicollinearity without AverageTicketPrice;
proc reg;
model ln_TeamValuation = Revenue OperatingIncome PlayerExpenses GateReceipts MetroAreaPopulation StadiumAge AverageAttendance FanCostIndex 
RecordPercentage NumberofAllStars WorldSeriesChampionship CyYoungAward MVPAward BothAwards PlayoffWild PlayoffDS PlayoffCS PlayoffWS /vif; 
run;

*Check multicollinearity without PlayerExpenses GateReceipts;
proc reg;
model ln_TeamValuation = Revenue OperatingIncome MetroAreaPopulation StadiumAge AverageAttendance FanCostIndex 
RecordPercentage NumberofAllStars WorldSeriesChampionship CyYoungAward MVPAward BothAwards PlayoffWild PlayoffDS PlayoffCS PlayoffWS /vif; 
run;

*Check for outliers;
proc reg;
model ln_TeamValuation = Revenue OperatingIncome MetroAreaPopulation StadiumAge AverageAttendance FanCostIndex 
RecordPercentage NumberofAllStars WorldSeriesChampionship CyYoungAward MVPAward BothAwards PlayoffWild PlayoffDS PlayoffCS PlayoffWS /influence r; 
run;

*Split data into testing and training sets;
proc surveyselect data = valuations
out = valuations_split seed = 1971603567
samprate = .70 outall;

proc print data = valuations_split;
run;

*create new variable new_y = ln_teamvaluation for training set, and = NA for testing set;
data valuations_split;
set valuations_split;
if selected then new_y = ln_TeamValuation;
run;

proc print data = valuations_split;
run;

*create models using stepwise and adjusted r-squared selection;
title "Model Selection";
proc reg data = valuations_split;
*Model 1;
model new_y = Revenue OperatingIncome MetroAreaPopulation StadiumAge AverageAttendance FanCostIndex 
RecordPercentage NumberofAllStars WorldSeriesChampionship CyYoungAward MVPAward BothAwards PlayoffWild PlayoffDS PlayoffCS PlayoffWS / selection = stepwise; 
run;
*Model 2;
model new_y = Revenue OperatingIncome MetroAreaPopulation StadiumAge AverageAttendance FanCostIndex 
RecordPercentage NumberofAllStars WorldSeriesChampionship CyYoungAward MVPAward BothAwards PlayoffWild PlayoffDS PlayoffCS PlayoffWS / selection = adjrsq; 
run;

title "Training Data - Stepwise";
proc reg data = valuations_split;
model  new_y = Revenue MetroAreaPopulation CyYoungAward PlayoffCS PlayoffWS / stb;
run;

title "Training Data - Adjusted R2";
proc reg data = valuations_split;
model  new_y = Revenue OperatingIncome MetroAreaPopulation StadiumAge AverageAttendance RecordPercentage CyYoungAward MVPAward PlayoffWild PlayoffCS PlayoffWS / stb;
run;

*get predicted values for the missing new_y in the test set for 2 models;
title "Validation - Test Set";
proc reg data = valuations_split;
*Model 1;
model new_y = Revenue MetroAreaPopulation CyYoungAward PlayoffCS PlayoffWS;
output out = outm1 (where = (new_y = .)) p = yhat;
*Model 2;
model new_y = Revenue OperatingIncome MetroAreaPopulation StadiumAge AverageAttendance RecordPercentage CyYoungAward MVPAward PlayoffWild PlayoffCS PlayoffWS;
output out = outm2 (where = (new_y = .)) p = yhat;
run;

*summarize results of the cross validations for M1;
title "Difference between Observed and Predicted in Test Set";
data outm1_sum;
set outm1;
d = ln_TeamValuation-yhat;
absd = abs(d);
run;

proc summary data = outm1_sum;
var d absd;
output out=outm1_stats std(d)=rmse mean(absd)=mae;
run;
proc print data = outm1_stats;
title "Validation Statistics for Model 1";
run;

proc corr data = outm1;
var ln_TeamValuation yhat;
run;


*summarize results of the cross validations for M2;
title "Difference between Observed and Predicted in Test Set";
data outm2_sum;
set outm2;
d = ln_TeamValuation-yhat;
absd = abs(d);
run;

proc summary data = outm2_sum;
var d absd;
output out=outm2_stats std(d)=rmse mean(absd)=mae;
run;
proc print data = outm2_stats;
title "Validation Statistics for Model 2";
run;

proc corr data = outm2;
var ln_TeamValuation yhat;
run;


*Create dataset for pred value;
data pred;
input Revenue MetroAreaPopulation CyYoungAward PlayoffCS PlayoffWS;
datalines;
350 2.6 0 1 0
175 4.0 1 0 0
;

*combine pred with bankingfull_new;
data prediction;
set pred valuations_split;
run;

proc print;
run;

proc reg data=prediction;
model ln_TeamValuation = Revenue MetroAreaPopulation CyYoungAward PlayoffCS PlayoffWS / p clm cli;
run;
