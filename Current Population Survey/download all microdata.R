# analyze survey data for free (http://asdfree.com) with the r language
# current population survey 
# annual social and economic supplement
# 1998 - 2015

# # # # # # # # # # # # # # # # #
# # block of code to run this # #
# # # # # # # # # # # # # # # # #
# library(downloader)
# setwd( "C:/My Directory/CPS/" )
# cps.years.to.download <- c( 2015 , 2014 , 2014.58 , 2014.38 , 2013:1998 )
# source_url( "https://raw.github.com/ajdamico/asdfree/master/Current%20Population%20Survey/download%20all%20microdata.R" , prompt = FALSE , echo = TRUE )
# # # # # # # # # # # # # # #
# # end of auto-run block # #
# # # # # # # # # # # # # # #

# if you have never used the r language before,
# watch this two minute video i made outlining
# how to run this script from start to finish
# http://www.screenr.com/Zpd8

# anthony joseph damico
# ajdamico@gmail.com

# if you use this script for a project, please send me a note
# it's always nice to hear about how people are using this stuff

# for further reading on cross-package comparisons, see:
# http://journal.r-project.org/archive/2009-2/RJournal_2009-2_Damico.pdf


#########################################################################################################
# Analyze the 1998 - 2014 Current Population Survey - Annual Social and Economic Supplement file with R #
#########################################################################################################


# set your working directory.
# the CPS data files will be stored here
# after downloading and importing them.
# use forward slashes instead of back slashes

# uncomment this line by removing the `#` at the front..
# setwd( "C:/My Directory/CPS/" )
# ..in order to set your current working directory


# warning: to import the 2014 income-consistent file,
# you will need the `devtools` library to install the github sas7bdat.parso library
# if you have trouble installing devtools within R, perhaps you need the r tools software
# http://cran.r-project.org/bin/windows/Rtools/


# remove the # in order to run this install.packages line only once
# install.packages( c( "survey" , "RSQLite" , "SAScii" , "descr" , "downloader" , "digest" , "haven" , "devtools" ) )

# load the `devtools` library
library(devtools)

# remove the # in order to run this install.packages line only once
# install_github( "biostatmatt/sas7bdat.parso" )


# define which years to download #

# uncomment this line to download all available data sets
# uncomment this line by removing the `#` at the front
# cps.years.to.download <- c( 2015 , 2014.58 , 2014.38 , 2014:1998 )

# uncomment this line to only download the most current year
# cps.years.to.download <- 2011

# uncomment this line to download, for example, 2005 and 2009-2011
# cps.years.to.download <- c( 2011:2009 , 2005 )


# name the database (.db) file to be saved in the working directory
cps.dbname <- "cps.asec.db"


############################################
# no need to edit anything below this line #

# # # # # # # # #
# program start #
# # # # # # # # #

# if the cps database file already exists in the current working directory, print a warning
if ( file.exists( paste( getwd() , cps.dbname , sep = "/" ) ) ) warning( "the database file already exists in your working directory.\nyou might encounter an error if you are running the same year as before or did not allow the program to complete.\ntry changing the cps.dbname in the settings above." )


library(RSQLite) 			# load RSQLite package (creates database files in R)
library(survey)				# load survey package (analyzes complex design surveys)
library(SAScii) 			# load the SAScii package (imports ascii data with a SAS script)
library(descr) 				# load the descr package (converts fixed-width files to delimited files)
library(downloader)			# downloads and then runs the source() function on scripts from github
library(haven) 				# load the haven package (imports dta files faaaaaast)
library(sas7bdat.parso) 	# load the sas7bdat.parso (imports binary/compressed sas7bdat files)


# fix this issue https://github.com/rstats-db/RSQLite/issues/82
setOldClass( c( "tbl_df" , "data.frame" ) )


# load the download_cached and related functions
# to prevent re-downloading of files once they've been downloaded.
source_url( 
	"https://raw.github.com/ajdamico/asdfree/master/Download%20Cache/download%20cache.R" , 
	prompt = FALSE , 
	echo = FALSE 
)

# load the dd_parser function to disentangle census bureau-provided import scripts
# for any march extracts that haven't been provided by nber
source_url( 
	"https://raw.github.com/ajdamico/asdfree/master/Current%20Population%20Survey/dd_parser.R" , 
	prompt = FALSE , 
	echo = FALSE 
)

# load the read.SAScii.sqlite function (a variant of read.SAScii that creates a database directly)
source_url( "https://raw.github.com/ajdamico/asdfree/master/SQLite/read.SAScii.sqlite.R" , prompt = FALSE )


# set R to produce conservative standard errors instead of crashing
# http://r-survey.r-forge.r-project.org/survey/exmample-lonely.html
options( survey.lonely.psu = "adjust" )
# this setting matches the MISSUNIT option in SUDAAN


# if this option is set to TRUE
# R will exactly match SUDAAN results and Stata with the MSE option results
options( survey.replicates.mse = TRUE )
# otherwise if it is commented out or set to FALSE
# R will exactly match Stata without the MSE option results

# Stata svyset command notes can be found here: http://www.stata.com/help.cgi?svyset


# begin looping through every cps year specified
for ( year in cps.years.to.download ){


	# name the final data table to be saved in the working directory
	# this default setup will name the tables asec05, asec06, asec07 and so on
	cps.tablename <- paste0( "asec" , substr( year , 3 , nchar( year ) ) )

	# overwrite 2014.38 with three-eights
	cps.tablename <- gsub( "\\.38" , "_3x8" , cps.tablename )

	# overwrite 2014.58 with three-eights
	cps.tablename <- gsub( "\\.58" , "_5x8" , cps.tablename )

	# # # # # # # # # # # #
	# load the main file  #
	# # # # # # # # # # # #

	# this process is slow.
	# for example, the CPS ASEC 2011 file has 204,983 person-records.

	# for the 2014 cps, load the income-consistent file as the full-year extract
	if ( year == 2014 ){
		
		db <- dbConnect( SQLite() , cps.dbname )
		
		tf1 <- tempfile() ; tf2 <- tempfile() ; tf3 <- tempfile()
	
		download_cached( "http://www.census.gov/housing/extract_files/data%20extracts/cpsasec14/hhld.sas7bdat" , tf1 , mode = 'wb' )
		download_cached( "http://www.census.gov/housing/extract_files/data%20extracts/cpsasec14/family.sas7bdat" , tf2 , mode = 'wb' )
		download_cached( "http://www.census.gov/housing/extract_files/data%20extracts/cpsasec14/person.sas7bdat" , tf3 , mode = 'wb' )

		hhld <- read.sas7bdat.parso( tf1 )
		names( hhld ) <- tolower( names( hhld ) )
		for ( i in names( hhld ) ) hhld[ , i ] <- as.numeric( hhld[ , i ] )
		hhld$hsup_wgt <- hhld$hsup_wgt / 100
		dbWriteTable( db , 'hhld' , hhld )
		rm( hhld ) ; gc() ; file.remove( tf1 )
		
		family <- read.sas7bdat.parso( tf2 )
		names( family ) <- tolower( names( family ) )
		for ( i in names( family ) ) family[ , i ] <- as.numeric( family[ , i ] )
		family$fsup_wgt <- family$fsup_wgt / 100
		dbWriteTable( db , 'family' , family )
		rm( family ) ; gc() ; file.remove( tf2 )
		
		person <- read.sas7bdat.parso( tf3 )
		names( person ) <- tolower( names( person ) )
		for ( i in names( person ) ) person[ , i ] <- as.numeric( person[ , i ] )
		for ( i in c( 'marsupwt' , 'a_ernlwt' , 'a_fnlwgt' ) ) person[ , i ] <- person[ , i ] / 100
		dbWriteTable( db , 'person' , person )
		rm( person ) ; gc() ; file.remove( tf3 )

		# create an index to speed up the merge
		dbSendQuery( db , "CREATE INDEX household_index ON hhld ( h_seq )" )

		# create an index to speed up the merge
		dbSendQuery( db , "CREATE INDEX family_index ON family ( fh_seq , ffpos )" )

		# create an index to speed up the merge
		dbSendQuery( db , "CREATE INDEX person_index ON person ( ph_seq , pppos )" )

		dbSendQuery( db , "create table f_p as select * from family as a inner join person as b on a.fh_seq = b.ph_seq AND a.ffpos = b.phf_seq" )
	
		dbSendQuery( db , "create table hfpz as select * from hhld as a inner join f_p as b on a.h_seq = b.ph_seq" )

		stopifnot( dbGetQuery( db , 'select count(*) from hfpz' )[ 1 , 1 ] == dbGetQuery( db , 'select count(*) from person' )[ 1 , 1 ] )

		dbRemoveTable( db , 'f_p' )
		
	} else {
		
		# note: this CPS March Supplement ASCII (fixed-width file) contains household-, family-, and person-level records.

		# census.gov website containing the current population survey's main file
		CPS.ASEC.mar.file.location <- 
			ifelse( 
				# if the year to download is 2007, the filename doesn't match the others..
				year == 2007 ,
				"http://thedataweb.rm.census.gov/pub/cps/march/asec2007_pubuse_tax2.zip" ,
				# ifelse(
					# year == 2014 ,
					# "http://thedataweb.rm.census.gov/pub/cps/march/asec2014early_pubuse.zip" ,
					ifelse(
						year %in% 2004:2003 ,
						paste0( "http://thedataweb.rm.census.gov/pub/cps/march/asec" , year , ".zip" ) ,
						ifelse(
							year %in% 2002:1998 ,
							paste0( "http://thedataweb.rm.census.gov/pub/cps/march/mar" , substr( year , 3 , 4 ) , "supp.zip" ) ,
							ifelse(
								year == 2014.58 ,
								"http://thedataweb.rm.census.gov/pub/cps/march/asec2014_pubuse_tax_fix_5x8.zip" ,
								ifelse( 
									year == 2014.38 ,
									"http://thedataweb.rm.census.gov/pub/cps/march/asec2014_pubuse_3x8_rerun_v2.zip" ,
									ifelse( year == 2015 ,
										paste0( "http://thedataweb.rm.census.gov/pub/cps/march/asec" , year , "early_pubuse.zip" ) ,
										paste0( "http://thedataweb.rm.census.gov/pub/cps/march/asec" , year , "_pubuse.zip" )
									)
								)
							)
						)
					)
				# )
			)

		if( year < 2011 ){
			
			# national bureau of economic research website containing the current population survey's SAS import instructions
			CPS.ASEC.mar.SAS.read.in.instructions <- 
					ifelse(
						year %in% 1987 ,
						paste0( "http://www.nber.org/data/progs/cps/cpsmar" , year , ".sas" ) , 
						paste0( "http://www.nber.org/data/progs/cps/cpsmar" , substr( year , 3 , 4 ) , ".sas" ) 
					)

			# figure out the household, family, and person begin lines
			hh_beginline <- grep( "HOUSEHOLD RECORDS" , readLines( CPS.ASEC.mar.SAS.read.in.instructions ) )
			fa_beginline <- grep( "FAMILY RECORDS" , readLines( CPS.ASEC.mar.SAS.read.in.instructions ) )
			pe_beginline <- grep( "PERSON RECORDS" , readLines( CPS.ASEC.mar.SAS.read.in.instructions ) )

		} else {
			
			if( year == 2015 ) sas_strus <- dd_parser( "http://thedataweb.rm.census.gov/pub/cps/march/asec2015early_pubuse.dd.txt" )
			if( year == 2014.38 ) sas_strus <- dd_parser( "http://thedataweb.rm.census.gov/pub/cps/march/asec2014R_pubuse.dd.txt" )
			if( year == 2014.58 ) sas_strus <- dd_parser( "http://thedataweb.rm.census.gov/pub/cps/march/asec2014early_pubuse.dd.txt" )
			if( year == 2013 ) sas_strus <- dd_parser( "http://thedataweb.rm.census.gov/pub/cps/march/asec2013early_pubuse.dd.txt" )
			if( year == 2012 ) sas_strus <- dd_parser( "http://thedataweb.rm.census.gov/pub/cps/march/asec2012early_pubuse.dd.txt" )
			if( year == 2011 ) sas_strus <- dd_parser( "http://thedataweb.rm.census.gov/pub/cps/march/asec2011_pubuse.dd.txt" )

		}
			
		# create a temporary file and a temporary directory..
		tf <- tempfile() ; td <- tempdir()

		# download the CPS repwgts zipped file to the local computer
		download_cached( CPS.ASEC.mar.file.location , tf , mode = "wb" )

		# unzip the file's contents and store the file name within the temporary directory
		fn <- unzip( tf , exdir = td , overwrite = TRUE )

		# create three more temporary files
		# to store household-, family-, and person-level records ..and also the crosswalk
		tf.household <- tempfile()
		tf.family <- tempfile()
		tf.person <- tempfile()
		tf.xwalk <- tempfile()
		
		# create four file connections.

		# one read-only file connection "r" - pointing to the ASCII file
		incon <- file( fn , "r") 

		# three write-only file connections "w" - pointing to the household, family, and person files
		outcon.household <- file( tf.household , "w") 
		outcon.family <- file( tf.family , "w") 
		outcon.person <- file( tf.person , "w") 
		outcon.xwalk <- file( tf.xwalk , "w" )
		
		# start line counter #
		line.num <- 0

		# store the current scientific notation option..
		cur.sp <- getOption( "scipen" )

		# ..and change it
		options( scipen = 10 )
		
		
		# figure out the ending position for each filetype
		# take the sum of the absolute value of the width parameter of the parsed-SAScii SAS input file, for household-, family-, and person-files separately
		if( year < 2011 ){
			end.household <- sum( abs( parse.SAScii( CPS.ASEC.mar.SAS.read.in.instructions , beginline = hh_beginline )$width ) )
			end.family <- sum( abs( parse.SAScii( CPS.ASEC.mar.SAS.read.in.instructions , beginline = fa_beginline )$width ) )
			end.person <- sum( abs( parse.SAScii( CPS.ASEC.mar.SAS.read.in.instructions , beginline = pe_beginline )$width ) )
		} else {
			end.household <- sum( abs( sas_strus[[1]]$width ) )
			end.family <- sum( abs( sas_strus[[2]]$width ) )
			end.person <- sum( abs( sas_strus[[3]]$width ) )
		}
		
		# create a while-loop that continues until every line has been examined
		# cycle through every line in the downloaded CPS ASEC 20## file..

		while( length( line <- readLines( incon , 1 ) ) > 0 ){

			# ..and if the first character is a 1, add it to the new household-only CPS file.
			if ( substr( line , 1 , 1 ) == "1" ){
				
				# write the line to the household file
				writeLines( substr( line , 1 , end.household ) , outcon.household )
				
				# store the current unique household id
				curHH <- substr( line , 2 , 6 )
			
			}
			
			# ..and if the first character is a 2, add it to the new family-only CPS file.
			if ( substr( line , 1 , 1 ) == "2" ){
			
				# write the line to the family file
				writeLines( substr( line , 1 , end.family )  , outcon.family )
				
				# store the current unique family id
				curFM <- substr( line , 7 , 8 )
			
			}
			
			# ..and if the first character is a 3, add it to the new person-only CPS file.
			if ( substr( line , 1 , 1 ) == "3" ){
				
				# write the line to the person file
				writeLines( substr( line , 1 , end.person )  , outcon.person )
				
				# store the current unique person id
				curPN <- substr( line , 7 , 8 )
				
				writeLines( paste0( curHH , curFM , curPN ) , outcon.xwalk )
				
			}

			# add to the line counter #
			line.num <- line.num + 1

			# every 10k records..
			if ( line.num %% 10000 == 0 ) {
				
				# print current progress to the screen #
				cat( "   " , prettyNum( line.num  , big.mark = "," ) , "of approximately 400,000 cps asec lines processed" , "\r" )
				
			}
		}

		# restore the original scientific notation option
		options( scipen = cur.sp )

		# close all four file connections
		close( outcon.household )
		close( outcon.family )
		close( outcon.person )
		close( outcon.xwalk )
		close( incon , add = T )


		# open the connection to the sqlite database
		db <- dbConnect( SQLite() , cps.dbname )


		# the 2011 SAS file produced by the National Bureau of Economic Research (NBER)
		# begins each INPUT block after lines 988, 1121, and 1209, 
		# so skip SAS import instruction lines before that.
		# NOTE that this 'beginline' parameters of 988, 1121, and 1209 will change for different years.

		if( year < 2011 ){
			# store CPS ASEC march household records as a SQLite database
			read.SAScii.sqlite ( 
				tf.household , 
				CPS.ASEC.mar.SAS.read.in.instructions , 
				beginline = hh_beginline , 
				zipped = FALSE ,
				tl = TRUE ,
				tablename = 'household' ,
				conn = db
			)

			# store CPS ASEC march family records as a SQLite database
			read.SAScii.sqlite ( 
				tf.family , 
				CPS.ASEC.mar.SAS.read.in.instructions , 
				beginline = fa_beginline , 
				zipped = FALSE ,
				tl = TRUE ,
				tablename = 'family' ,
				conn = db
			)

			# store CPS ASEC march person records as a SQLite database
			read.SAScii.sqlite ( 
				tf.person , 
				CPS.ASEC.mar.SAS.read.in.instructions , 
				beginline = pe_beginline , 
				zipped = FALSE ,
				tl = TRUE ,
				tablename = 'person' ,
				conn = db
			)
		} else {
			# store CPS ASEC march household records as a SQLite database
			read.SAScii.sqlite ( 
				tf.household , 
				sas_stru = sas_strus[[1]] ,
				zipped = FALSE ,
				tl = TRUE ,
				tablename = 'household' ,
				conn = db
			)

			# store CPS ASEC march family records as a SQLite database
			read.SAScii.sqlite ( 
				tf.family , 
				sas_stru = sas_strus[[2]] ,
				zipped = FALSE ,
				tl = TRUE ,
				tablename = 'family' ,
				conn = db
			)

			# store CPS ASEC march person records as a SQLite database
			read.SAScii.sqlite ( 
				tf.person , 
				sas_stru = sas_strus[[3]] ,
				zipped = FALSE ,
				tl = TRUE ,
				tablename = 'person' ,
				conn = db
			)
		}

		
			
		# create an index to speed up the merge
		dbSendQuery( db , "CREATE INDEX household_index ON household ( h_seq )" )

		# create an index to speed up the merge
		dbSendQuery( db , "CREATE INDEX family_index ON family ( fh_seq , ffpos )" )

		# create an index to speed up the merge
		dbSendQuery( db , "CREATE INDEX person_index ON person ( ph_seq , pppos )" )


		# create a fake sas input script for the crosswalk..
		xwalk.sas <-
			"INPUT
				@1 h_seq 5.
				@6 ffpos 2.
				@8 pppos 2.
			;"
			
		# save it to the local disk
		xwalk.sas.tf <- tempfile()
		writeLines ( xwalk.sas , con = xwalk.sas.tf )

		
		# store CPS ASEC march xwalk records as a SQLite database
		read.SAScii.sqlite ( 
			tf.xwalk , 
			xwalk.sas.tf , 
			zipped = FALSE ,
			tl = TRUE ,
			tablename = 'xwalk' ,
			conn = db
		)

		# create an index to speed up the merge
		dbSendQuery( db , "CREATE INDEX xwalk_index ON xwalk ( h_seq , ffpos , pppos )" )

		# clear up RAM
		gc()

		
		# create the merged file
		dbSendQuery( db , "create table h_xwalk as select * from xwalk as a inner join household as b on a.h_seq = b.h_seq" )
		dbSendQuery( db , "create table h_f_xwalk as select * from h_xwalk as a inner join family as b on a.h_seq = b.fh_seq AND a.ffpos = b.ffpos" )
		dbSendQuery( db , "create table hfpz as select * from h_f_xwalk as a inner join person as b on a.h_seq = b.ph_seq AND a.pppos = b.pppos" )
	
	}
		
	# tack on _anycov_ variables
	# tack on _outtyp_ variables
	if( year > 2013 ){
		
		dbSendQuery( db , "create table hfp_pac as select * from hfpz" )
		
		dbRemoveTable( db , 'hfpz' )
		
		stopifnot( year %in% c( 2015 , 2014.58 , 2014.38 , 2014 ) )
		
		tf <- tempfile()
		
		ac <- NULL
		
		ot <- NULL
		
		if( year %in% c( 2014 , 2014.58 ) ){
			
			ace <- "http://www.census.gov/hhes/www/hlthins/data/incpovhlth/2013/asec14_now_anycov.dat"

			download_cached( ace , tf , mode = "wb" )	

			ac <- rbind( ac , read.fwf( tf , c( 5 , 2 , 1 ) ) )
			
		}

		if( year %in% c( 2014 , 2014.38 ) ){
			
			ace <- "http://www.census.gov/housing/extract_files/data%20extracts/health%20data%20files/asec14_now_anycov_redes.dat"

			download_cached( ace , tf , mode = "wb" )	

			ac <- rbind( ac , read.fwf( tf , c( 5 , 2 , 1 ) ) )
			
		}
		
		if ( year %in% c( 2014 , 2014.38 , 2014.58 ) ){
		
			ote <- "http://www.census.gov/housing/extract_files/data%20extracts/health%20data%20files/asec14_outtyp_full.dat"
			
			download_cached( ote , tf , mode = 'wb' )
			
			ot <- read.fwf( tf , c( 5 , 2 , 2 , 1 ) )
			
		}
		
		
		if ( year %in% 2015 ){
		
			ote <- "http://www.census.gov/housing/extract_files/data%20extracts/health%20data%20files/asec15_outtyp.dat"
		
			download_cached( ote , tf , mode = 'wb' )
			
			ot <- read.fwf( tf , c( 5 , 2 , 2 , 1 ) )
			
			ace <- "http://www.census.gov/housing/extract_files/data%20extracts/health%20data%20files/asec15_currcov_extract.dat"
		
			download_cached( ace , tf , mode = 'wb' )
			
			ac <- read.fwf( tf , c( 5 , 2 , 1 ) ) 
		
		}
		
		names( ot ) <- c( 'ph_seq' , 'ppposold' , 'outtyp' , 'i_outtyp' )
		
		names( ac ) <- c( 'ph_seq' , 'ppposold' , 'census_anycov' )
		
		ac[ ac$census_anycov == 2 , 'census_anycov' ] <- 0
		
		ot_ac <- merge( ot , ac )
		
		dbWriteTable( db , 'ot_ac' , ot_ac )
		
		rm( ot , ac , ot_ac ) ; gc()
		
		dbSendQuery( db , "create table hfp as select * from hfp_pac as a inner join ot_ac as b on a.h_seq = b.ph_seq AND a.ppposold = b.ppposold" )
		
		stopifnot( dbGetQuery( db , 'select count(*) from hfp' )[ 1 , 1 ] == dbGetQuery( db , 'select count(*) from hfp_pac' )[ 1 , 1 ] )
		
		dbRemoveTable( db , 'ot_ac' )
		
		dbRemoveTable( db , 'hfp_pac' )
		
		file.remove( tf )
	
	} else {
	
		dbSendQuery( db , "create table hfp as select * from hfpz" )
		
		dbRemoveTable( db , 'hfpz' )
		
	}
	
	
	
	
	dbSendQuery( db , "CREATE INDEX hfp_index ON hfp ( h_seq , ffpos , pppos )" )
	

	if( year > 2004 ){
		

		# confirm that the number of records in the 2011 cps asec merged file
		# matches the number of records in the person file
		stopifnot( dbGetQuery( db , "select count(*) as count from hfp" ) == dbGetQuery( db , "select count(*) as count from person" ) )


		# # # # # # # # # # # # # # # # # #
		# load the replicate weight file  #
		# # # # # # # # # # # # # # # # # #
				
		# this process is also slow.
		# the CPS ASEC 2011 replicate weight file has 204,983 person-records.

		# census.gov website containing the current population survey's replicate weights file
		CPS.replicate.weight.file.location <- 
			ifelse(
				year == 2014.38 ,
				"http://thedataweb.rm.census.gov/pub/cps/march/CPS_ASEC_ASCII_REPWGT_2014_3x8_run5.zip" ,
				ifelse(
					year == 2014 ,
					"http://www.census.gov/housing/extract_files/weights/CPS_ASEC_ASCII_REPWGT_2014_FULLSAMPLE.DAT" ,
					paste0( 
						"http://thedataweb.rm.census.gov/pub/cps/march/CPS_ASEC_ASCII_REPWGT_" , 
						substr( year , 1 , 4 ) , 
						".zip" 
					)
				)
			)
			
		# census.gov website containing the current population survey's SAS import instructions
		if( year %in% 2014.38 ){
		
			CPS.replicate.weight.SAS.read.in.instructions <- tempfile()

			writeLines(
				paste(
					"INPUT" ,
					paste0( "pwwgt" , 0:160 , " " , seq( 1 , 1601 , 10 ) , "-" , seq( 10 , 1610 , 10 ) , " 0.4" , collapse = "\n" ) ,
					paste( "h_seq 1611 - 1615" , "pppos 1616-1617" , ";" , collapse = "\n" ) ,
					sep = "\n"
				) , 
				CPS.replicate.weight.SAS.read.in.instructions 
			)
			
		} else {
			
			CPS.replicate.weight.SAS.read.in.instructions <- 
				paste0( 
					"http://thedataweb.rm.census.gov/pub/cps/march/CPS_ASEC_ASCII_REPWGT_" , 
					substr( year , 1 , 4 ) , 
					".SAS" 
				)

		}

		zip_file <- 
			tolower( 
				substr( 
					CPS.replicate.weight.file.location , 
					nchar( CPS.replicate.weight.file.location ) - 2 , 
					nchar( CPS.replicate.weight.file.location ) 
				)
			) == 'zip'

			
		if( !zip_file ){
			rw_tf <- tempfile()
			download_cached( CPS.replicate.weight.file.location , rw_tf , mode = 'wb' )
			CPS.replicate.weight.file.location <- rw_tf
		}
		
		# store the CPS ASEC march 2011 replicate weight file as an R data frame
		read.SAScii.sqlite ( 
			CPS.replicate.weight.file.location , 
			CPS.replicate.weight.SAS.read.in.instructions , 
			zipped = zip_file , 
			tl = TRUE ,
			tablename = 'rw' ,
			conn = db
		)
		
		
		# create an index to speed up the merge
		dbSendQuery( db , "CREATE INDEX rw_index ON rw ( h_seq , pppos )" )


		###################################################
		# merge cps asec file with replicate weights file #
		###################################################

		sql <- paste( "create table" , cps.tablename , "as select * from hfp as a inner join rw as b on a.h_seq = b.h_seq AND a.pppos = b.pppos" )
		
		dbSendQuery( db , sql )

	} else {
	
		dbSendQuery( db , paste( "create table" , cps.tablename , "as select * from h_f_xwalk as a inner join person as b on a.h_seq = b.ph_seq AND a.pppos = b.pppos" ) )
			
	}
		
	# confirm that the number of records in the 2011 person file
	# matches the number of records in the merged file
	stopifnot( dbGetQuery( db , paste( "select count(*) as count from " , cps.tablename ) ) == dbGetQuery( db , "select count(*) as count from person" ) )

	# drop unnecessary tables
	try( dbSendQuery( db , "drop table h_xwalk" ) , silent = TRUE )
	try( dbSendQuery( db , "drop table h_f_xwalk" ) , silent = TRUE )
	try( dbSendQuery( db , "drop table xwalk" ) , silent = TRUE )
	dbSendQuery( db , "drop table hfp" )
	try( dbSendQuery( db , "drop table rw" ) , silent = TRUE )
	try( dbSendQuery( db , "drop table household" ) , silent = TRUE )
	try( dbSendQuery( db , "drop table hhld" ) , silent = TRUE )
	dbSendQuery( db , "drop table family" )
	dbSendQuery( db , "drop table person" )

	
	# add a new column "one" that simply contains the number 1 for every record in the data set
	dbSendQuery( db , paste( "ALTER TABLE" , cps.tablename , "ADD one REAL" ) )
	dbSendQuery( db , paste( "UPDATE" , cps.tablename , "SET one = 1" ) )

	# # # # # # # # # # # # # # # # # # # # # # # # # #
	# import the supplemental poverty research files  #
	# # # # # # # # # # # # # # # # # # # # # # # # # #
	
	overlapping.spm.fields <- c( "gestfips" , "fpovcut" , "ftotval" , "marsupwt" )
	
	if( year %in% c( 2010:2014 , 2014.38 , 2014.58 ) ){

		sp.url <- 
			paste0( 
			"http://www.census.gov/housing/povmeas/spmresearch/spmresearch" , 
			floor( year - 1 ) , 
			if ( year == 2014.38 ) "_redes" else "new" ,
			".sas7bdat" 
		)
		
		download_cached( sp.url , tf , mode = 'wb' )
		
		sp <- read_sas( tf )
	
		if ( year == 2014 ){
			
			sp.url <- "http://www.census.gov/housing/povmeas/spmresearch/spmresearch2013_redes.sas7bdat"
				
			download_cached( sp.url , tf , mode = 'wb' )
			
			sp2 <- read_sas( tf )
		
			sp <- rbind( sp , sp2 )
			
			rm( sp2 ) ; gc()
			
		} 
		
		names( sp ) <- tolower( names( sp ) )

		sp <- sp[ , !( names( sp ) %in% overlapping.spm.fields ) ]

		dbWriteTable( db , paste0( cps.tablename , "_sp" ) , sp )
		
		
		rm( sp ) ; gc()
	
		dbSendQuery( db , paste( 'create table temp as select * from' , cps.tablename ) )
		
		dbRemoveTable( db , cps.tablename )
		
		dbSendQuery( 
			db , 
			paste0( 
				"create table " , 
				cps.tablename , 
				" as select * from temp as a inner join " ,
				cps.tablename , 
				"_sp as b on a.h_seq = b.h_seq AND a.pppos = b.pppos" 
			) 
		)

		stopifnot( dbGetQuery( db , paste( "select count(*) as count from " , cps.tablename ) ) == dbGetQuery( db , "select count(*) as count from temp" ) )
	
		dbRemoveTable( db , 'temp' )
				
	}
	
	
	# remove redundant colon fields
	ftk <- dbListFields( db , cps.tablename )[ !grepl( ":" , dbListFields( db , cps.tablename ) ) ]
	
	# copy over the fields-to-keep into a new table
	dbSendQuery( db , paste( "CREATE TABLE temp AS SELECT" , paste( ftk , collapse = "," ) , "FROM" , cps.tablename ) )
	
	# drop the original
	dbSendQuery( db , paste( "DROP TABLE" , cps.tablename ) )
	
	# rename the temporary table
	dbSendQuery( db , paste( "ALTER TABLE temp RENAME TO" , cps.tablename ) )
	
	# disconnect from the current database
	dbDisconnect( db )
	
}


# print a reminder: set the directory you just saved everything to as read-only!
message( paste0( "all done.  you should set the file " , file.path( getwd() , cps.dbname ) , " read-only so you don't accidentally alter these tables." ) )


# for more details on how to work with data in r
# check out my two minute tutorial video site
# http://www.twotorials.com/

# dear everyone: please contribute your script.
# have you written syntax that precisely matches an official publication?
message( "if others might benefit, send your code to ajdamico@gmail.com" )
# http://asdfree.com needs more user contributions

# let's play the which one of these things doesn't belong game:
# "only you can prevent forest fires" -smokey bear
# "take a bite out of crime" -mcgruff the crime pooch
# "plz gimme your statistical programming" -anthony damico
