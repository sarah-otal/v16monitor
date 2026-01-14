library(httr)
library(xml2)
library(dplyr)
library(purrr)
library(tibble)
library(lubridate)
library(jsonlite)

# --- 1. Flattener and Names ---
flatten_node <- function(node, prefix = "") {
  res <- list()
  attrs <- xml_attrs(node)
  if (length(attrs) > 0) {
    for (i in seq_along(attrs)) {
      attr_name <- names(attrs)[i]
      if (!grepl("xmlns|xsi", attr_name)) {
        res[[paste0(prefix, if(prefix=="") "" else "/", "_", attr_name)]] <- attrs[[i]]
      }
    }
  }
  children <- xml_children(node)
  if (length(children) == 0) {
    text <- xml_text(node, trim = TRUE)
    if (text != "") res[[paste0(prefix, "/__text")]] <- text
  } else {
    child_names <- xml_name(children)
    name_counts <- table(child_names)
    current_counts <- list()
    indexed_tags <- c("situationRecord", "carriageway", "lane", "point", "value")
    for (i in seq_along(children)) {
      nm <- child_names[i]
      use_index <- (nm %in% indexed_tags) || (name_counts[nm] > 1)
      new_path <- if (prefix == "") nm else paste0(prefix, "/", nm)
      if (use_index) {
        idx <- if (nm %in% names(current_counts)) current_counts[[nm]] else 0
        current_counts[[nm]] <- idx + 1
        res <- c(res, flatten_node(children[[i]], paste0(new_path, "/", idx)))
      } else {
        res <- c(res, flatten_node(children[[i]], new_path))
      }
    }
  }
  return(res)
}

apply_meaningful_names <- function(df) {
  raw_names <- names(df)
  clean_names <- raw_names %>%
    gsub("/__text", "", .) %>%
    gsub("/([0-9]+)/", "_\\1_", .) %>%
    gsub("/", "_", .)
  mapping <- c("situationRecord" = "Record", "locationReference" = "Loc", "supplementaryPositionalDescription" = "Pos", "tpegLinearLocation" = "Linear", "tpegPointLocation" = "Point", "pointCoordinates" = "Coords", "extendedTpegNonJunctionPoint" = "Ext", "autonomousCommunity" = "Region", "validityTimeSpecification" = "Validity", "overallStartTime" = "Start", "overallEndTime" = "End", "sourceIdentification" = "Source", "probabilityOfOccurrence" = "Probability", "roadOrCarriagewayOrLaneManagementType" = "MgmtType", "forVehiclesWithCharacteristicsOf" = "VehicleLimits")
  for (i in seq_along(mapping)) { clean_names <- gsub(names(mapping)[i], mapping[i], clean_names, fixed = TRUE) }
  names(df) <- gsub("_+", "_", clean_names) %>% gsub("^_|_$", "", .)
  return(df)
}

# --- 2. Execution Pipeline ---
run_pipeline <- function() {
  url <- paste0("https://nap.dgt.es/datex2/v3/dgt/SituationPublication/datex2_v36.xml?v=", as.numeric(Sys.time()))
  res <- GET(url, add_headers(`User-Agent` = "Mozilla/5.0"))
  if (status_code(res) == 200) {
    xml_data <- read_xml(content(res, "raw"))
    pub_time_raw <- xml_text(xml_find_first(xml_data, "//*[local-name()='publicationTime']"))
    pub_time_dt <- as_datetime(pub_time_raw)
    file_ts <- gsub("[:T-]", "", substr(pub_time_raw, 1, 19))
    if(!dir.exists("data")) dir.create("data")
    situations <- xml_find_all(xml_data, "//*[local-name()='situation']")
    df_final <- map_dfr(situations, ~{
      row_list <- flatten_node(.x)
      row_list$Publication_Time <- pub_time_raw
      start_key <- "situationRecord/0/validity/validityTimeSpecification/overallStartTime/__text"
      if (start_key %in% names(row_list)) { 
        row_list$Time_elapsed <- as.numeric(difftime(pub_time_dt, as_datetime(row_list[[start_key]]), units = "mins")) 
      }
      as_tibble(row_list)
    })
    df_final <- apply_meaningful_names(df_final)
    
    col1 <- "Record_0_Loc_Point_tpegSimplePointExtension_extendedTpegSimplePoint_tpegDirectionRoad"
    if (col1 %in% names(df_final)) { df_final[[col1]] <- recode(df_final[[col1]], "both" = "ambos", "negative" = "decreciente", "positive" = "creciente", .default = df_final[[col1]]) }
    col2 <- "Record_0_Loc_Point_tpegDirection"
    if (col2 %in% names(df_final)) { df_final[[col2]] <- recode(df_final[[col2]], "eastBound" = "Este", "northBound" = "Norte", "northEastBound" = "Nordeste", "northWestBound" = "Noroeste", "southBound" = "Sur", "southEastBound" = "Sudeste", "southWestBound" = "Sudoeste", "unknown" = "desconocido", "westBound" = "Oeste", .default = df_final[[col2]]) }
    
    csv_filename <- paste0("data/", file_ts, "_dgt_transformed.csv")
    write.csv(df_final, csv_filename, row.names = FALSE, na = "")
    message(paste("Success: CSV created at", csv_filename))
  }
}

run_latest_map <- function(filter_source = NULL) {
  files <- list.files(path = "data", pattern = "^[0-9]{14}_dgt_transformed\\.csv$", full.names = TRUE)
  if (length(files) == 0) stop("No CSV files found in /data")
  latest_file <- sort(files, decreasing = TRUE)[1]
  create_dgt_openlayers_map(latest_file, filter_source = filter_source)
  if(length(files) > 10) { file.remove(sort(files, decreasing = TRUE)[11:length(files)]) }
}

create_dgt_openlayers_map <- function(csv_path, filter_source = NULL, filter_cause = NULL) {
  df <- read.csv(csv_path, stringsAsFactors = FALSE, check.names = TRUE)
  if (!is.null(filter_source)) {
    src_col <- grep("Source", names(df), value = TRUE)[1]
    if(!is.na(src_col)) df <- df %>% filter(.data[[src_col]] %in% filter_source)
  }
  
  cols <- names(df)
  raw_time_utc <- ymd_hms(df$Publication_Time[1], tz = "UTC")
  local_time_madrid <- with_tz(raw_time_utc, tzone = "Europe/Madrid")
  formatted_ts <- paste0("Actualizado: ", format(local_time_madrid, "%d-%B-%Y %H:%M:%S"))
  filename_ts <- format(local_time_madrid, "%Y%m%d_%H%M")
  
  find_col <- function(pat) { m <- grep(gsub("/", "\\.", pat), cols, value = TRUE, ignore.case = TRUE); if(length(m) > 0) m[1] else NULL }
  c_muni <- find_col("Record_0_Loc_Point_point_0_tpegNonJunctionPointExtension_Ext_municipality")
  c_prov <- find_col("Record_0_Loc_Point_point_0_tpegNonJunctionPointExtension_Ext_province")
  c_road <- find_col("Record_0_Loc_Pos_roadInformation_roadName")
  c_pk <- find_col("Record_0_Loc_Point_point_0_tpegNonJunctionPointExtension_Ext_kilometerPoint")
  c_dir_r <- find_col("Record_0_Loc_Point_tpegSimplePointExtension_extendedTpegSimplePoint_tpegDirectionRoad")
  c_tpeg <- find_col("Record_0_Loc_Point_tpegDirection")
  c_lat <- find_col("Record_0_Loc_Point_point_0_Coords_latitude")
  c_lon <- find_col("Record_0_Loc_Point_point_0_Coords_longitude")
  
  df_map <- df %>%
    mutate(
      lat = as.numeric(as.character(.data[[c_lat]])),
      lon = as.numeric(as.character(.data[[c_lon]])),
      mins = as.numeric(Time_elapsed),
      Muni = ifelse(!is.na(.data[[c_muni]]), as.character(.data[[c_muni]]), "N/A"),
      Prov = ifelse(!is.na(.data[[c_prov]]), as.character(.data[[c_prov]]), "N/A"),
      Road = ifelse(!is.na(.data[[c_road]]), as.character(.data[[c_road]]), "N/A"),
      PK = ifelse(!is.na(.data[[c_pk]]), as.character(.data[[c_pk]]), "N/A"),
      Dir1 = ifelse(!is.na(.data[[c_dir_r]]), as.character(.data[[c_dir_r]]), "N/A"),
      Dir2 = ifelse(!is.na(.data[[c_tpeg]]), as.character(.data[[c_tpeg]]), "N/A")
    ) %>%
    filter(!is.na(lat) & !is.na(lon))
  
  df_map$Tooltip <- apply(df_map, 1, function(row) {
    paste0("<strong>", row["Muni"], " (", row["Prov"], "):</strong><br>", row["Road"], ", PK: ", row["PK"], " (", row["Dir1"], ", ", row["Dir2"], ")<br>(", round(as.numeric(row["lat"]), 5), ", ", round(as.numeric(row["lon"]), 5), ")")
  })
  
  json_data <- jsonlite::toJSON(df_map, auto_unbox = TRUE)
  
  # --- SELF-HEALING BASE TEMPLATE (Broken into chunks to avoid 4094 char limit) ---
  if(!file.exists("mapa_base.html")) {
    h1 <- '<!DOCTYPE html><html><head><title>DGT Map</title><link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/ol@v7.4.0/ol.css"><style>'
    h2 <- 'body{margin:0;font-family:sans-serif;}#map{width:100vw;height:100vh;background:#f8f9fa;}#header{position:absolute;top:15px;left:50%;transform:translateX(-50%);background:rgba(255,255,255,0.9);padding:12px 20px;border-radius:8px;z-index:1000;text-align:center;border:1px solid #bbb;}'
    h3 <- '.ol-popup{position:absolute;background-color:white;padding:12px;border-radius:8px;border:1px solid #ccc;bottom:15px;left:-50px;min-width:280px;font-size:11px;pointer-events:none;box-shadow:0 2px 8px rgba(0,0,0,0.2);}#legend{position:absolute;bottom:30px;left:20px;z-index:1000;background:white;padding:10px;border:1px solid #bbb;font-size:11px;}.dot{height:8px;width:8px;border-radius:50%;display:inline-block;margin-right:8px;border:1.5px solid orange;}'
    h4 <- '#footer-container{position:absolute;bottom:10px;right:10px;z-index:1000;display:flex;flex-direction:column;align-items:flex-end;}#search-box{width:240px;padding:8px;border:1px solid #bbb;border-radius:4px 4px 0 0;font-size:12px;outline:none;border-bottom:none;}#footer-links{background:white;padding:8px;font-size:11px;border:1px solid #bbb;width:240px;text-align:center;border-radius:0 0 4px 4px;}#footer-links a,#footer-links span{text-decoration:none;color:blue;margin-left:10px;cursor:pointer;}</style></head>'
    b1 <- '<body><div id="header"><div style="font-size:16px;font-weight:bold;">DGT Balizas v16 activas (Hora Local Madrid)</div><div style="font-size:12px;color:#333;margin-top:5px;">/*TS*/</div></div><div id="map"></div>'
    b2 <- '<div id="legend"><strong>Minutos Activa (Oscuro = Reciente)</strong><br><div style="display:flex;align-items:center"><span class="dot" style="background:#67000d"></span> < 15 min</div><div style="display:flex;align-items:center"><span class="dot" style="background:#a50f15"></span> 15-30 min</div><div style="display:flex;align-items:center"><span class="dot" style="background:#de2d26"></span> 30-60 min</div><div style="display:flex;align-items:center"><span class="dot" style="background:#fb6a4a"></span> 60-120 min</div><div style="display:flex;align-items:center"><span class="dot" style="background:#fcae91"></span> 120-240 min</div><div style="display:flex;align-items:center"><span class="dot" style="background:#fee5d9"></span> > 240 min</div></div>'
    b3 <- '<div id="footer-container"><input type="text" id="search-box" placeholder="Buscar (Provincia) o Carretera/Municipio..."><div id="footer-links"><span onclick="downloadCSV()">Download CSV</span><a href="about.html" target="_blank">About</a></div></div><div id="popup" class="ol-popup"><div id="popup-content"></div></div>'
    s1 <- '<script src="https://cdn.jsdelivr.net/npm/ol@v7.4.0/dist/ol.js"></script><script>const data=/*DATA*/;const fileTimestamp="/*FILETS*/";function getR(m){if(m<=15)return"#67000d";if(m<=30)return"#a50f15";if(m<=60)return"#de2d26";if(m<=120)return"#fb6a4a";if(m<=240)return"#fcae91";return"#fee5d9";}'
    s2 <- 'const features=data.map(d=>new ol.Feature({geometry:new ol.geom.Point(ol.proj.fromLonLat([d.lon,d.lat])),tooltip:d.Tooltip,mins:d.mins,muni:(d.Muni||"").toLowerCase().trim(),road:(d.Road||"").toLowerCase().trim(),prov:(d.Prov||"").toLowerCase().trim()}));const source=new ol.source.Vector({features:features});const map=new ol.Map({target:"map",layers:[new ol.layer.Tile({source:new ol.source.OSM()}),new ol.layer.Vector({source:source,style:f=>new ol.style.Style({image:new ol.style.Circle({radius:5,fill:new ol.style.Fill({color:getR(f.get("mins"))}),stroke:new ol.style.Stroke({color:"orange",width:1.5})})})})],view:new ol.View({center:ol.proj.fromLonLat([-3.70,40.41]),zoom:6})});'
    s3 <- 'document.getElementById("search-box").addEventListener("input",(e)=>{let t=e.target.value.toLowerCase().trim();let fil=t===""?features:t.startsWith("(")?features.filter(f=>f.get("prov").startsWith(t.substring(1))):features.filter(f=>f.get("muni").startsWith(t)||f.get("road").startsWith(t));source.clear();source.addFeatures(fil);});const overlay=new ol.Overlay({element:document.getElementById("popup"),autoPan:false});map.addOverlay(overlay);map.on("pointermove",e=>{const f=map.forEachFeatureAtPixel(e.pixel,feat=>feat);if(f){document.getElementById("popup-content").innerHTML=f.get("tooltip");overlay.setPosition(e.coordinate);map.getTargetElement().style.cursor="pointer";}else{overlay.setPosition(undefined);map.getTargetElement().style.cursor="";}});'
    s4 <- 'map.on("click",e=>{const f=map.forEachFeatureAtPixel(e.pixel,feat=>feat);if(f){map.getView().animate({center:f.getGeometry().getCoordinates(),zoom:14,duration:1000});}});function downloadCSV(){if(data.length===0)return;const h=["Municipio","Provincia","Carretera","PK","Sentido1","Sentido2","Lat","Lon"];const k=["Muni","Prov","Road","PK","Dir1","Dir2","lat","lon"];let csv="data:text/csv;charset=utf-8,"+h.join(",")+"\\n";data.forEach(d=>{let r=k.map(x=>\'"\' + String(d[x]||"").replace(/"/g,\'""\') + \'"\');csv+=r.join(",")+"\\n";});const l=document.createElement("a");l.setAttribute("href",encodeURI(csv));l.setAttribute("download",`dgt_balizas_activas_${fileTimestamp}.csv`);l.click();}</script></body></html>'
    
    cat(h1, h2, h3, h4, b1, b2, b3, s1, s2, s3, s4, file = "mapa_base.html", sep = "")
  }
  
  template <- paste(readLines("mapa_base.html", warn = FALSE), collapse = "\n")
  final_html <- template %>%
    gsub("/*DATA*/", json_data, ., fixed = TRUE) %>%
    gsub("/*TS*/", formatted_ts, ., fixed = TRUE) %>%
    gsub("/*FILETS*/", filename_ts, ., fixed = TRUE)

  writeLines(final_html, "v16activas.html")
  message("v16activas.html created successfully.")
                             
 # Update README with the last execution time
  readme_content <- c(
    paste("# DGT Balizas v16 Monitor"),
    paste("### Last successful update: ", formatted_ts),
    paste("\n[View Live Map](https://yourusername.github.io/dgt-v16-monitor/v16activas.html)")
  )
  writeLines(readme_content, "README.md")
}

# --- 3. EXECUTION ---
run_pipeline()
run_latest_map(filter_source = "DGT3.0")


