while(TRUE) {
  cat("\n--- Update Cycle Started:", as.character(Sys.time()), "---\n")
  
  tryCatch({
    # 1. Run the data processing script
    source("script.R")
    
    # 2. STAGE changes first (Solves the "unstaged changes" error)
    system("git add v16activas.html map_base.html README.md data/*.csv")
    
    # 3. PULL with rebase (Integrates remote work with your staged files)
    # We use -X ours to favor your map if there is a conflict
    system("git pull --rebase -X ours origin main")
    
    # 4. COMMIT
    system('git commit -m "Auto-update from GCP VM [skip ci]"')
    
    # 5. PUSH
    system("git push origin main")
    
    cat("Success: Map updated and pushed to GitHub.\n")
  }, error = function(e) {
    cat("Error occurred:", conditionMessage(e), "\n")
  })
  
  cat("Waiting 120 seconds...\n")
  Sys.sleep(120)
}
