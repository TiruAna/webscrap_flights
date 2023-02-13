library(jsonlite)
library(openxlsx)
library(tidyverse)

# import excel file
flights = read.xlsx("flights.xlsx")

# transform date
flights$data_plecare = gsub('\\.', '-', flights$data_plecare)
flights$data_intoarcere = gsub('\\.', '-', flights$data_intoarcere)

# Functions

build_json_link = function(depart_date, return_date, origin, destination) {
  
  ryanair_url = "https://www.ryanair.com/"
  l1 = "api/booking/v4/ro-ro/availability?ADT=1&CHD=0&DateIn="
  l2 = "&DateOut="
  l3 = "&Destination="
  l4 = "&Disc=0&INF=0&Origin="
  l5 = "&TEEN=0&promoCode=&IncludeConnectingFlights=false&FlexDaysBeforeOut=2&FlexDaysOut=2&FlexDaysBeforeIn=2&FlexDaysIn=2&RoundTrip=true&ToUs=AGREED"
  
  ryanair_js = paste0(ryanair_url, l1, return_date, l2, depart_date, l3, destination, l4, origin, l5)
  
  return(ryanair_js)
}

validate_json = function(flights){
  nr = nrow(flights)
  flights$valid_json = ""
  for (i in 1:nr){
    an.error.occured = FALSE
    tryCatch( { result <- jsonlite::fromJSON(flights$json[i]) }
              , error = function(e) {an.error.occured <<- TRUE})
    if(isTRUE(an.error.occured)){
      print(paste0("Nr. ",i, " Invalid JSON: ", 
                   an.error.occured, " - posibil nu exista zboruri pentru destinatia: ", 
                   flights$destinatia[i]))
      flights$valid_json[i] = FALSE
      next
    }
    print(paste0("Nr. ",i, " Valid JSON: ", 
                 an.error.occured, " - Exista zboruri pentru destinatia: ", 
                 flights$destinatia[i]))
    flights$valid_json[i] = TRUE
  }
  return(flights)
}

get_trips = function (json_list){
  df_trips = json_list$trips
  return(df_trips)
}

get_df_dates = function(df_trips) {
  nr_trips = nrow(df_trips)
  df_dates = data.frame()
  for (i in 1:nr_trips){
    df = as.data.frame(df_trips$dates[i])
    df_dates = rbind(df_dates, df)
  }
  return(df_dates)
}

get_df_flights = function (df_dates) {
  nr_dates = nrow(df_dates)
  df_flights = data.frame()
  for (i in 1:nr_dates){
    df = as.data.frame(df_dates$flights[i][[1]])
    df_flights = dplyr::bind_rows(df_flights, df)
  }
  return(df_flights)
}

get_df_details = function(df_flights){
  nr_flights = nrow(df_flights)
  df_details = data.frame()
  for(i in 1:nr_flights) {
    l = df_flights[i,]
    det = l$regularFare$fares[[1]]
    l_det = cbind(l, det)
    
    df_details = dplyr::bind_rows(df_details, l_det)
  }
  return(df_details)
}

ryanair_js = build_json_link(flights$data_plecare, flights$data_intoarcere,
                             flights$origine, flights$cod_aeroport_destinatie)
flights$json = ryanair_js

flights = validate_json(flights)
flights$valid_json = as.logical(flights$valid_json)


# GET ryanair data
rynair_data = data.frame()
nr.row = nrow(flights)

for (i in 1:nr.row){
  print(i)

  if(isFALSE(flights$valid_json[i])) next
  
  json_list = jsonlite::fromJSON(flights$json[i])
  df_trips = get_trips(json_list)
  
  print(i)
  df_dates = get_df_dates(df_trips)
  df_flights = get_df_flights(df_dates)
  if(nrow(df_flights) == 0){
    print(paste0("Nu exista zboruri pentru destinatia: ", flights$destinatia[i]))
    next
  } 
  
  df_details = get_df_details(df_flights)
  
  rynair_data = dplyr::bind_rows(rynair_data, df_details)
}


# clean data

rynair_data$nr_zbor = trimws(rynair_data$flightNumber)

for(i in 1:nrow(rynair_data)){
  stsplit = strsplit(rynair_data$flightKey[i], "~")[[1]]
  rynair_data$origine[i] = stsplit[5]
  rynair_data$destinatie[i] = stsplit[7]
  rynair_data$data_plecare[i] = strsplit(stsplit[6], " ")[[1]][1]
  rynair_data$ora_plecare[i] = strsplit(stsplit[6], " ")[[1]][2]
  rynair_data$ora_sosire[i] = strsplit(stsplit[8], " ")[[1]][2]
}
rynair_data$pret = trimws(rynair_data$amount)
rynair_data$um = "EURO"
rynair_data$nr_pasageri = 1
rynair_data$compania = "Ryanair"
rynair_data$tip_companie = "low_cost"
rynair_data$clasa = "economic"
rynair_data$nr_escale = 0
rynair_data$durata_escala = 0
rynair_data$data_colectare = Sys.Date()

rynair_data$data_colectare = gsub('-', '\\.', rynair_data$data_colectare)

as.Date(rynair_data$data_colectare[1], format = "%Y-%m-%d")

rynair_data = rynair_data[, c("nr_zbor", "origine", "destinatie", "data_plecare", "ora_plecare",
                              "ora_sosire", "pret", "um", "compania", "nr_escale",
                              "durata_escala","data_colectare")]

# write data
write.xlsx(rynair_data, "rynair_data.xlsx", overwrite = TRUE)













###################################################################################

json_list = fromJSON(flights$json[20])

get_flights = function (json_link) {
  
  #from_json_to_list = jsonlite::fromJSON(json_link)
  trips = json_link$trips
  
  df_flights = data.frame()
  
  nr_trips = nrow(trips)
  print(paste0("Nr of trips: ", nr_trips))
  for (j in 1:nr_trips) {
    trip = trips$dates[j]
    nr_trips = length(trip[[1]]$dateOut)
    
    dateout = c()
    flight_key = c()
    amount = c()
    
    for (i in 1:nr_trips) {
      print(i)
      dt = trip[[1]]$dateOut[i]
      dateout = c(dateout, dt)
      
      nr_flights = nrow(trip[[1]]$flights[[i]])
      
      if (is.null(nr_flights)){
        fk = NA
        am = NA
      } else if (nr_flights == 0 ) {
        fk = NA
        am = NA
      } else{
        print("Nr. of flights: ", nr_flights)
        fk = trip[[1]]$flights[[i]]$flightKey
        am = trip[[1]]$flights[[i]]$regularFare$fares[[1]]$amount
      }

      flight_key = c(flight_key, fk)
      amount = c(amount, am)
    }
    
    df_fl = data.frame(dateout, flight_key, amount)
    df_flights = rbind(df_flights, df_fl)
  }
  
  return(df_flights)
}

l = fromJSON(flights$json[24])
xx = get_flights(fromJSON(flights$json[24]))

df_result = data.frame()
for (i in c(24)) {
  an.error.occured = FALSE
  tryCatch( { result <- jsonlite::fromJSON(flights$json[i]) }
            , error = function(e) {an.error.occured <<- TRUE})
  if(isTRUE(an.error.occured)){
    print(paste0("Nr. ",i, " Invalid JSON: ", 
                 an.error.occured, " - posibil nu exista zboruri pentru destinatia: ", 
                 flights$destinatia[i]))
    next
  }
  print(paste0("Nr. ",i, " Valid JSON: ", 
               an.error.occured, " - Exista zboruri pentru destinatia: ", 
               flights$destinatia[i]))
  
  result_flights = get_flights(result)
  df_result = rbind(df_result, result_flights)
}


20, 24



json_link = fromJSON(flights$json[17])


#https://www.ryanair.com/api/booking/v4/ro-ro/availability?ADT=1&CHD=0&DateIn=2023-06-06&DateOut=2023-06-02&Destination=MAD&Disc=0&INF=0&Origin=OTP&TEEN=0&promoCode=&IncludeConnectingFlights=false&FlexDaysBeforeOut=2&FlexDaysOut=2&FlexDaysBeforeIn=2&FlexDaysIn=2&RoundTrip=true&ToUs=AGREED
# 2023-06-06

js = "https://www.ryanair.com/api/booking/v4/ro-ro/availability?ADT=1&CHD=0&DateIn=2023-06-06&DateOut=2023-06-04&Destination=MAD&Disc=0&INF=0&Origin=OTP&TEEN=0&promoCode=&IncludeConnectingFlights=false&FlexDaysBeforeOut=2&FlexDaysOut=2&FlexDaysBeforeIn=2&FlexDaysIn=2&RoundTrip=true&ToUs=AGREED"








