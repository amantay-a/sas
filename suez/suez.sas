proc optmodel;
	Title "Suez Case study";
	/* declare sets and parameters */
	set <str> NETWORK_CONSUMERS = /Ellerslie Penrose Newmarket/;
	set <str> NETWORK_VALVES 	= /GreenwoodValve EricssonValve/;
	set <str> NETWORK_PUMPS		= /Cornwall_P1 Cornwall_P2 Cornwall_P3 Kingsland_P1 Kingsland_P2 Kingsland_P3/;
	set <str> CORNWALL_PUMPS 	= /Cornwall_P1 Cornwall_P2 Cornwall_P3/;
	set <str> KINGSLAND_PUMPS 	= /Kingsland_P1 Kingsland_P2 Kingsland_P3/;
	set <str> NETWORK_TANKS 	= /ClearWells Ellerslie Penrose Newmarket/;

	set <num> WORK_HOURS 				= 1..24; /*hours from 08:00->1 to 07:00->24*/
	num SOURCE_MIN_RATE 				= 800;
	num SOURCE_MAX_RATE 				= 3500;
	num TANKS_INIT{NETWORK_TANKS}		= [29000 11000 11000 17000];
	num TANKS_MIN {NETWORK_TANKS} 		= [15000 5000 5000 12000];
	num TANKS_MAX {NETWORK_TANKS} 		= [32000 14000 14000 18000];
	num PUMPS_EFFICIENCY {NETWORK_PUMPS}= [0.65 0.65 0.65 0.65 0.65 0.65];
	num PUMPS_FLOW {NETWORK_PUMPS}		= [600 600 800 800 800 400];	
	num PUMPS_LEVEL_TO{NETWORK_PUMPS} 	= [250 250 250 200 200 200];
	num PUMPS_LEVEL_FROM{NETWORK_PUMPS}	= [160 160 160 100 100 100];
	num Valve_MIN_FLOW{NETWORK_VALVES} 	= [500 200];
	num Valve_MAX_FLOW{NETWORK_VALVES} 	= [1500 1000];
	num NETWORK_DEMAND{WORK_HOURS, NETWORK_CONSUMERS}  = 
						[388 379 1165
						 458 438 1696
						 625 483 2663
						 792 521 3000
						 958 665 3190
						1058 1030 2809
						1125 1164 2679
						 958 1121 1209
						 792 669 783
						 438 375 675
						 469 228 594
						 554 263 533
						 642 320 546
						 677 408 569
						 700 448 677
						 665 506 1023
						 506 439 924
						 506 270 1063
						 529 252 1013
						 559 189 863
						 606 180 801
						 623 152 759
						 781 158 844
						 779 163 958
						];
	 num NETWORK_TARIFFS{WORK_HOURS, NETWORK_PUMPS}  = 
 						[0.10 0.10 0.10 0.06 0.06 0.06
						 0.17 0.17 0.17	0.06 0.06 0.06
						 0.17 0.17 0.17	0.12 0.12 0.12
						 0.17 0.17 0.17	0.12 0.12 0.12
						 0.24 0.24 0.24	0.18 0.18 0.18
						 0.24 0.24 0.24	0.18 0.18 0.18
						 0.24 0.24 0.24	0.18 0.18 0.18
						 0.24 0.24 0.24	0.18 0.18 0.18
						 0.24 0.24 0.24	0.12 0.12 0.12
						 0.24 0.24 0.24	0.12 0.12 0.12
						 0.17 0.17 0.17	0.12 0.12 0.12
						 0.17 0.17 0.17	0.12 0.12 0.12
						 0.17 0.17 0.17	0.12 0.12 0.12
						 0.17 0.17 0.17	0.06 0.06 0.06
						 0.17 0.17 0.17	0.06 0.06 0.06
						 0.17 0.17 0.17	0.06 0.06 0.06
						 0.10 0.10 0.10	0.06 0.06 0.06
						 0.10 0.10 0.10	0.06 0.06 0.06
						 0.10 0.10 0.10	0.06 0.06 0.06
						 0.10 0.10 0.10	0.06 0.06 0.06
						 0.10 0.10 0.10	0.06 0.06 0.06
						 0.10 0.10 0.10	0.06 0.06 0.06
						 0.10 0.10 0.10	0.06 0.06 0.06
						 0.10 0.10 0.10	0.06 0.06 0.06
						];
	num final_gap_bottom{NETWORK_TANKS} = [0 12 5 12]; /* bottom gap between tanks' final and initial volume */
	num final_gap_top{NETWORK_TANKS} 	= [0 0 0 0]; /* top gap between tanks' final and initial volume */
	num n_year = 0; /*number of year, n_year=0 for initial, n_year>0 for a number of years of a demand(pupulation) growth...*/
	num M = 10000; /* just big number for comparisons*/

/* declare variables */

	var pumps_schedule	{WORK_HOURS, NETWORK_PUMPS} binary;
	var sources_schedule{WORK_HOURS} >= SOURCE_MIN_RATE <=SOURCE_MAX_RATE integer;
	var valves_schedule	{WORK_HOURS, NETWORK_VALVES}  >= 0 integer;
	var valves_open {WORK_HOURS, NETWORK_VALVES} binary;
	var bs {0..3} binary;
	var bv {WORK_HOURS, NETWORK_VALVES} binary;

	impvar pumps_flow_schedule{h in WORK_HOURS, np in NETWORK_PUMPS} = pumps_schedule[h, np] * PUMPS_FLOW[np];
	impvar Cornwall_flaw{h in WORK_HOURS} = sum{cp in CORNWALL_PUMPS} pumps_flow_schedule[h, cp];
	impvar Kingsland_flaw{h in WORK_HOURS} = sum{kp in KINGSLAND_PUMPS} pumps_flow_schedule[h, kp];

	impvar tanks_level{h in 0..24, nt in NETWORK_TANKS}  = 
		if (h=0) then(TANKS_INIT[nt])
		else (tanks_level[h-1, nt]+
			if (nt = "ClearWells") then (sources_schedule[h] - Cornwall_flaw[h] - valves_schedule[h, "GreenwoodValve"])
			else (if nt = "Ellerslie" then (Cornwall_flaw[h] - valves_schedule[h, "EricssonValve"] - (1.1**n_year)*NETWORK_DEMAND[h, "Ellerslie"])
				  else (if (nt = "Penrose") then (valves_schedule[h, "GreenwoodValve"] - Kingsland_flaw[h] - (1.1**n_year)*NETWORK_DEMAND[h, "Penrose"])
						else (if (nt = "Newmarket") then (valves_schedule[h, "EricssonValve"] + Kingsland_flaw[h] - (1.1**n_year)*NETWORK_DEMAND[h, "Newmarket"])
							 )
				  		)
			     )
			);

/* declare constraints */

	/*tanks constraints*/
	/* Not less than INITIAL - final_gap: */
	con tanks_level_delta1{nt in NETWORK_TANKS}:
		tanks_level[24, nt] >= tanks_level[0, nt] - final_gap_bottom[nt];
	/* No more than INITIAL + final_gap: */
	con tanks_level_delta2{nt in NETWORK_TANKS}:
		tanks_level[24, nt] <= tanks_level[0, nt] + final_gap_top[nt];

	/*tanks min volume control every hour*/
	con tank_level_min{h in WORK_HOURS, nt in NETWORK_TANKS}: 
		tanks_level[h, nt] >=TANKS_MIN[nt];
	/*tanks max volume control every hour*/
	con tank_level_max{h in WORK_HOURS, nt in NETWORK_TANKS}:
		tanks_level[h, nt] <=TANKS_MAX[nt];
		
	/*source constraints*/
	/*Extension: source can only change flow rate every 4 hours*/
	con sources_ext1{h in WORK_HOURS, j in 0..3}:
	  	sources_schedule[if (h + j <= 24) then (h+j) else (h+j-24)] - sources_schedule[h-mod(h-1,4) + j]<=M*bs[j];
	con sources_ext2{h in WORK_HOURS, j in 0..3}:
	  	-sources_schedule[if (h + j <= 24) then (h+j) else (h+j-24)] + sources_schedule[h-mod(h-1,4) + j]<=M*bs[j];
	con sources_bool:
	  	sum{j in 0..3}bs[j] = 3;

	/*Pumps Constraints*/
	/*Extension: A pump has to run for at least 2 hours*/	
	con pumps_ext{h in WORK_HOURS, np in NETWORK_PUMPS}:
	 	pumps_schedule[h, np] + pumps_schedule[if(h+2<=24) then (h+2) else (h+2-24), np] >= pumps_schedule[if(h+1<=24)then (h+1) else (h+1-24), np];

	/*valve constraints, valve can be closed*/
	con valves_min1{h in WORK_HOURS, nv in NETWORK_VALVES}:
	valves_schedule[h,nv] >= Valve_MIN_FLOW[nv]*valves_open[h,nv];
	con valves_min2{h in WORK_HOURS, nv in NETWORK_VALVES}:
	valves_schedule[h,nv] <= M*valves_open[h,nv];

	con valves_max{h in WORK_HOURS, nv in NETWORK_VALVES}:
	valves_schedule[h,nv] <= Valve_MAX_FLOW[nv];

	/*Extension: If a valve is open, it has to stay open at the same flow rate for at least 4 hours*/	
	con valves_ext{h in WORK_HOURS, j in 1..3, nv in NETWORK_VALVES}:
	  valves_open[h, nv] + valves_open[if (h+4<=24) then (h+4) else (h+4-24), nv]>=valves_open[if (h+j<=24) then (h+j) else (h+j-24), nv];

	con valves_ext_eq1{h in WORK_HOURS, nv in NETWORK_VALVES}:
	  valves_schedule[h, nv] <= M*(1 - bv[h, nv]);
	con valves_ext_eq2{h in WORK_HOURS, nv in NETWORK_VALVES}:
		valves_schedule[h, nv] - valves_schedule[if (h+1<=24) then (h+1) else (h+1-24), nv] <=  M*bv[if (h+1<=24) then (h+1) else (h+1-24), nv];
	con valves_ext_eq3{h in WORK_HOURS, nv in NETWORK_VALVES}:
		-valves_schedule[h, nv] + valves_schedule[if (h+1<=24) then (h+1) else (h+1-24), nv] <=  M*bv[h, nv];


/* declare objective */
	min NetCost  = sum {h in WORK_HOURS} sum{np in NETWORK_PUMPS} NETWORK_TARIFFS[h, np]*pumps_schedule[h, np]*PUMPS_FLOW[np]*1000*9.8*(PUMPS_LEVEL_TO[np] - PUMPS_LEVEL_FROM[np])/(PUMPS_EFFICIENCY[np]*3.6*1e6);

/*Print formulation*/
	/*expand / var impvar/*con*/;

	/*MILP*/
	solve with milp / relobjgap = 1e-4;
	print 'Costs, $:' (NetCost) dollar8.2;

	reset options pmatrix=3;
	print 'pumps_flow_schedule:' pumps_flow_schedule; 
	print 'sources_schedule:' sources_schedule;
	print 'valves_schedule:'   valves_schedule /*valves_open bv*/;
	/*print _CON_.name _CON_.body _CON_.dual;
	print network_demand tanks_initial;*/
	print tanks_level;

	create data tank_level_out from [WORK_HOURS] = {j in 0..24} 
		x=j
		x0 = 0
		y_LC = tanks_level[j, "ClearWells"] 
		y_LE = tanks_level[j, "Ellerslie"]
		y_LP = tanks_level[j, "Penrose"]
		y_LN = tanks_level[j, "Newmarket"] 

		y_LC_min = TANKS_MIN["ClearWells"]
		y_LE_min = TANKS_MIN["Ellerslie"]
		y_LP_min = TANKS_MIN["Penrose"]
		y_LN_min = TANKS_MIN["Newmarket"]

		y_LC_max = TANKS_MAX["ClearWells"]
		y_LE_max = TANKS_MAX["Ellerslie"]
		y_LP_max = TANKS_MAX["Penrose"]
		y_LN_max = TANKS_MAX["Newmarket"]	

		y_LC0 = TANKS_INIT["ClearWells"]
		y_LE0 = TANKS_INIT["Ellerslie"]
		y_LP0 = TANKS_INIT["Penrose"]
		y_LN0 = TANKS_INIT["Newmarket"]
	;
	create data flow_out from [WORK_HOURS] = {j in 1..24} 
		x=j	
		y_PC = Cornwall_flaw[j]
		y_PK = Kingsland_flaw[j]
		y_VE = valves_schedule[j, "EricssonValve"]
		y_VG = valves_schedule[j, "GreenwoodValve"]	
	;

quit;

proc sgplot data=tank_level_out;

Title "Tanks volume change";

series x=x y=y_LC / lineattrs=(color=red thickness=3) legendlabel="ClearWell" name= "LC" ;
series x=x y=y_LE / lineattrs=(color=green thickness=3) legendlabel="Ellerslie" name= "LE" ;
series x=x y=y_LP / lineattrs=(color=blue thickness=3) legendlabel="Penrose" name= "LP" ;
series x=x y=y_LN / lineattrs=(color=black thickness=3) legendlabel="Newmarlet" name= "LN" ;

scatter x=x y=y_LC0 / markerattrs=(color=red  ) legendlabel = "Initial" name="Initial LC";
scatter x=x y=y_LE0 / markerattrs=(color=green size=3) legendlabel = "Initial" name="Initial LE";
scatter x=x y=y_LP0 / markerattrs=(color=blue ) legendlabel = "Initial" name="Initial LP";
scatter x=x y=y_LN0 / markerattrs=(color=black) legendlabel = "Initial" name="Initial LN";

scatter x=x y=y_LC_MIN / markerattrs=(color=red symbol = LessThan size=4) legendlabel="Min" name= "Min LC" ;
scatter x=x y=y_LE_MIN / markerattrs=(color=green symbol = LessThan size=4) legendlabel="Min" name= "Min LE" ;
scatter x=x y=y_LP_MIN / markerattrs=(color=blue symbol = LessThan size=4) legendlabel="Min" name= "Min LP" ;
scatter x=x y=y_LN_MIN / markerattrs=(color=black symbol = LessThan size=4) legendlabel="Min" name= "Min LN" ;

scatter x=x y=y_LC_MAX / markerattrs=(color=red symbol = GreaterThan size=4) legendlabel="Max" name= "Max LC" ;
scatter x=x y=y_LE_MAX / markerattrs=(color=green symbol = GreaterThan size=4) legendlabel="Max" name= "Max LE" ;
scatter x=x y=y_LP_MAX / markerattrs=(color=blue symbol = GreaterThan size=4) legendlabel="Max" name= "Max LP" ;
scatter x=x y=y_LN_MAX / markerattrs=(color=black symbol = GreaterThan size=4) legendlabel="Max" name= "Max LN" ;

yaxis label='level';
xaxis label='hour from 08:00';

run;


proc sgplot data=flow_out noborder;
	title "PS Flow";
	 styleattrs datacolors=(lightbrown gray);
	vbar x / response=y_PC legendlabel = "Cornwall PS" name="PC"
		barwidth=0.4 
		baselineattrs=(thickness=0) 
		discreteoffset= -0.2;
	vbar x / response=y_PK legendlabel = "Kingsland PS" name="PK" 
		barwidth=0.4 
		baselineattrs=(thickness=0)
		discreteoffset= 0.2;

	xaxis  label='hour from 08:00';
	yaxis  grid  label='PS flow rate';
run;

proc sgplot data=flow_out noborder;
	title "Valve flow";
	 styleattrs datacolors=(darkgray lightgreen);
	vbar x / response=y_VE legendlabel = "EricssonValve" name="VE"
		barwidth=0.4 
		baselineattrs=(thickness=0) 
		discreteoffset= -0.2;
	vbar x / response=y_VG  legendlabel = "GreenwoodValve" name="VG"
		barwidth=0.4 
		baselineattrs=(thickness=0)
		discreteoffset= 0.2;
	xaxis  label='hour from 08:00';
	yaxis  grid  label='PS flow rate';
run;

/*Reset title*/
title;
