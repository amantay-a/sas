/* Question 1 */
PROC IMPORT OUT=spx500 DATAFILE='/home/u47221955/MATH802/Project/option(Jan2014-Feb2014).csv' DBMS=CSV 
		REPLACE;
	GETNAMES=YES;
	DATAROW=2;
RUN;

data spx500;
set spx500;
  date2 = input(date, yymmdd10.);
  format date2 Date10.;
run;

/*Check first 10 observations & structure */
PROC PRINT DATA=spx500 (OBS=10);
	TITLE1 'S&P 500 options (Jan-Feb2014)';
	TITLE2 'First 10 observations';
RUN;

/*PROC CONTENTS DATA=spx500;
RUN;*/

TITLE1 'VIX';
PROC IML;
	USE spx500;
	READ ALL VAR {tau, K, call_option_price, r, put_option_price, S} into opt;
	cols_opt = {'tau', 'K', 'c', 'r', 'p', 'S'};
	mattrib opt c=cols_opt;
	
	READ ALL VAR {date2} into date;	
	mattrib date format=DDMMYY10.;
	
	abs_diff = abs(opt[,'c'] - opt[,'p']);
	
	min_abs_diff = j(nrow(opt), 1, .); 
	
	DT = j(nrow(opt), 4, .); 
	cols_DT = {'D1', 'D2', 'T1', 'T2'};
	mattrib DT c=col_DT;
	
	do i = 1 to nrow(opt);                    
	    read all var {call_option_price} into c
	        where(date2=(date[i]) & tau=(opt[i, 'tau']));
	    read all var {put_option_price} into p
	        where(date2=(date[i]) & tau=(opt[i, 'tau']));	   

	 	min_abs_diff[i] = min(abs(c - p));
	 	
	 	read all var {tau} into tau
	        where(date2=(date[i]));
	 	if min(tau) <= 30
	 	then
        	D1 = max(tau[loc(tau <= 30)]);
    	else
    		D1 = min(tau);  
 	   D2 = min(tau[loc(tau > D1)]); 	   
 	   T1 = D1/365;
 	   T2 = D2/365;
 	   
 	   DT[i, 1] = D1;
 	   DT[i, 2] = D2;
 	   DT[i, 3] = D1/365;
 	   DT[i, 4] = D2/365;	 	
 	   
	end;
	

	is_min = (abs_diff=min_abs_diff);
	
	/*all together*/
	comb = opt||abs_diff||is_min||DT;
	cols_comb = cols_opt//{'abs_diff', 'is_min'}//cols_DT;
	mattrib comb c=cols_comb;
	
	/*filter by tau (near-term and next-term only)*/
	comb_f = comb[loc(comb[,'tau']=comb[,'D1'] |comb[,'tau']=comb[,'D2']),];
	date_f = date[loc(comb[,'tau']=comb[,'D1'] |comb[,'tau']=comb[,'D2']),];
	mattrib comb_f c=cols_comb;
	
	/*aggregated*/
	aggr = comb_f[loc(comb_f[,'is_min']>0 ) ,]; 
	mattrib aggr c=cols_comb;	
	cols_aggr = cols_opt//{'abs_diff'}//cols_DT;
	aggr = aggr[,cols_aggr];
	mattrib aggr c=cols_aggr;
	/*aggregated date*/
	date_aggr = date_f[loc(comb_f[,'is_min']),]; 
	mattrib date_aggr format=DDMMYY10.;

	F1  = j(nrow(aggr), 1, .);
	F2 	= j(nrow(aggr), 1, .);
	K01 = j(nrow(aggr), 1, .);
	K02 = j(nrow(aggr), 1, .);
	dK = j(nrow(comb_f), 1, .);
	mid_Q = j(nrow(comb_f), 1, .);
	Contrib = j(nrow(comb_f), 1, .);
	otype = j(nrow(comb_f), 1, 'Avg.');
	do i = 1 to nrow(aggr);
		if aggr[i,'tau']<=30
		then
			do;
			F1[i]= aggr[i,'K'] + exp(aggr[i,'r']*aggr[i, 'T1'])*(aggr[i,'c'] - aggr[i,'p']);
			K01[i] = max(opt[loc(date = (date_aggr[i]) & opt[,'tau'] =  (aggr[i,'tau']) & opt[,'K'] < (F1[i])), 'K']);
	        end;
		else
			do;
			F2[i]= aggr[i,'K'] + exp(aggr[i,'r']*aggr[i, 'T2'])*(aggr[i,'c'] - aggr[i,'p']);		
			K02[i] = max(opt[loc(date = (date_aggr[i]) & opt[,'tau'] =  (aggr[i,'tau']) & opt[,'K'] < (F2[i])), 'K']);
	        end;
	    
	    cnt=0;    
		do j = 1 to nrow(comb_f);		
	   		if (date_f[j] = date_aggr[i]) & (comb_f[j, 'tau'] = aggr[i, 'tau']) 
	   		then 
	   			do;
	   				cnt = cnt + 1;
	   			
		   			if cnt = 1
		   			then
		   				dK[j] = (comb_f[j+1, 'K'] - comb_f[j, 'K']); /*lower edge*/
					
					else if j=nrow(comb_f) | comb_f[min(j+1, nrow(comb_f)), 'tau'] ^= comb_f[j, 'tau'] | date_f[min(j+1, nrow(comb_f))] ^= date_f[j]
		   			then
		   				dK[j]= (comb_f[j, 'K'] - comb_f[j-1, 'K']);/*upper edge*/	
					else
						dK[j] = (comb_f[j+1, 'K'] - comb_f[j-1, 'K'])/2;					
								
					if comb_f[j, 'K'] < coalesce(K01[i], K02[i])
					then do;
						mid_Q[j] = comb_f[j,'p'];
						otype[j] = 'Put';
						end;
					else if comb_f[j, 'K'] > coalesce(K01[i], K02[i])
					then do;
						mid_Q[j] = comb_f[j,'c'];
						otype[j] = 'Call';
						end;
					else if comb_f[j, 'K'] = coalesce(K01[i], K02[i])
					then do;	
						mid_Q[j] =(comb_f[j,'p'] + comb_f[j,'c'])/2 ;
						otype[j] = 'Avg.';
						end;
					
					if aggr[i,'tau']<=30
						then
						Contrib[j] = dK[j]/(comb_f[j, 'K']##2)*exp(comb_f[j,'r']*aggr[i, 'T1'])*mid_Q[j];
					else
						Contrib[j] = dK[j]/(comb_f[j, 'K']##2)*exp(comb_f[j,'r']*aggr[i, 'T2'])*mid_Q[j];
				end;
		end;    	
	end;
	
	Contrib_sum1 = j(nrow(aggr), 1, .);
	Contrib_sum2 = j(nrow(aggr), 1, .);
	sigma_sq1  = j(nrow(aggr), 1, .);
	sigma_sq2  = j(nrow(aggr), 1, .);
	vix		 = j(nrow(aggr), 1, .);
	do i = 1 to nrow(aggr);
		if aggr[i,'tau']<=30
		then do;
			Contrib_sum1[i] = sum(Contrib[loc(date_f = date_aggr[i] & comb_f[, 'tau'] = aggr[i, 'tau'] )]);
			sigma_sq1[i] = (2/aggr[i, 'T1'])*Contrib_sum1[i];
			sigma_sq1[i] = sigma_sq1[i] - (1/aggr[i, 'T1'])*(F1[i]/K01[i]-1)##2;
			end;
		else do;
			Contrib_sum2[i] = sum(Contrib[loc(date_f = date_aggr[i] & comb_f[, 'tau'] = aggr[i, 'tau'] )]);
			sigma_sq2[i] = (2/aggr[i, 'T2'])*Contrib_sum2[i];
			sigma_sq2[i] = sigma_sq2[i] - (1/aggr[i, 'T2'])*(F2[i]/K02[i]-1)##2;
			end;
		if mod(i,2)=0
		then do;
			vix[i] = aggr[i, 'T1']*sigma_sq1[i-1]*(aggr[i, 'D2']-30)/(aggr[i, 'D2'] - aggr[i, 'D1']) +  aggr[i, 'T2']*sigma_sq2[i]*(30 - aggr[i, 'D1'])/(aggr[i, 'D2'] - aggr[i, 'D1']);
			vix[i] = 100*sqrt(vix[i]*365/30);
		end;
	end;
	
	
	print date_aggr[l='date'] (aggr[, 'tau'])[l='T'] (aggr[, 'T1'])[l='T1'] (aggr[, 'T2'])[l='T2']  F1 F2 K01 K02 Contrib_sum1 Contrib_sum2 sigma_sq1 sigma_sq2 vix[f = number5.2];	
	
	/*Deatailed contributions table 
	
	ods startpage=now;
	run;
	TITLE 'Detailed Contributions by Strike';
	print date_f[l='date' f=ddmmyy.10] (comb_f[,{'tau','r', 'p', 'c', 'abs_diff', 'is_min', 'K'}])[c={'tau', 'r', 'p', 'c', 'abs_diff', 'is_min', 'K'}] otype dK mid_Q Contrib[f=number12.10];
	*/

	
/*Question 2*/
	ods startpage=now;
	run;
	
	start newton_raphson_sigma(T, r, K, S0, c);
	   		sigma=0.2;
			pi = constant("pi");
			total_run=3;
			do i = 1 to total_run;
				d1=(log(S0/K)+(r+sigma**2/2)*T)/(sigma*sqrt(T));
				d2=d1-sigma*sqrt(T);
				fs=S0*cdf("Normal",d1)-K*(exp(-r*T)*cdf("Normal",d2));
				vega=S0*1/sqrt(2*pi)*exp(-d1**2/2)*sqrt(T);
				g=fs-c;
				sigma=sigma-g/vega;
			end;
	      return (sigma);
	finish newton_raphson_sigma;
	
	
	atm_row =  j(nrow(comb_f),1,.);
	do i = 1 to nrow(comb_f); 
		l = loc(comb_f[,'tau'] = (comb_f[i, 'tau']) & date_f = (date_f[i]));
		grouped_K = comb_f[l, 'K'];
		grouped_S = comb_f[l, 'S'];
		atm_row[i] = (abs(comb_f[i, 'K'] - comb_f[i, 'S']) = min(abs(grouped_K - grouped_S)));
		
		if atm_row[i] = 1 /*additional condition to avoid dublicate minima*/
		then do;
		l2 = loc(comb_f[,'tau'] = (comb_f[i, 'tau']) & date_f = (date_f[i]) & atm_row = 1);
		atm_row[i] = (atm_row[i]&(comb_f[i, 'K'] = min(comb_f[l2, 'K'])));
		end;
	end;
	
		
	cols_atm = {'tau', 'r', 'K', 'S', 'c'};
	l_atm = loc(atm_row =1);
	atm_vol = comb_f[l_atm, cols_atm];
	atm_date = date_f[l_atm];
	mattrib atm_vol c=cols_atm;
	
	atm_sigma = j(nrow(atm_vol), 1, .);
	do i = 1 to nrow(atm_vol); 
		atm_sigma[i] = newton_raphson_sigma(atm_vol[i,'tau']/365, atm_vol[i,'r'], atm_vol[i,'K'], atm_vol[i,'S'], atm_vol[i,'c']);
	end;
	
	TITLE 'At-the-money implied volatility';
	print atm_date[f=ddmmyy10.] atm_vol atm_sigma;
	
	
/*Question 3*/
	ods startpage=now;
	run;
	
	vix_sigma = coalesce(sqrt(sigma_sq1), sqrt(sigma_sq2));
	diff_vix_atm = vix_sigma - atm_sigma;
	
	
	
	TITLE 'Difference between VIX and Implied volatility (ATM Vol.)';
	print date_aggr[f = ddmmyy10. l='date'] (aggr[, 'tau'])[l='tau'] vix_sigma[l='VIX sigma'] atm_sigma[l='ATM implied vol'] (diff_vix_atm)[l='difference'];

	TITLE 'Historgram of difference (VIX - ATM)';
	call histogram(diff_vix_atm) density={"Normal" "Kernel"};

	
	TITLE 'ATM Vol vs VIX sigma';
	call Scatter(vix_sigma, atm_sigma) label={"VIX sigma" "ATM Vol"};
	run;	
	corr=Corr(vix_sigma||atm_sigma);
	print corr;
	
	
	
	/*call regress(vix_sigma, atm_sigma, {'vix_sigma'}, quantile("T", 1-0.025, 5));
	run;*/
	
	optn = j(9,1,.);
	optn[2]= 1;    /* do not print residuals, diagnostics, or history */
	call lms(sc, coef, wgt, optn, vix_sigma, atm_sigma);
	r1 = {"Quantile", "Number of Subsets", "Number of Singular Subsets",
	       "Number of Nonzero Weights", "Objective Function",
	       "Preliminary Scale Estimate", "Final Scale Estimate",
	       "Robust R Squared", "Asymptotic Consistency Factor"};
	sc1 = sc[1:9];
	print sc1[r=r1 L="LMS Information and Estimates"];
	

RUN;

