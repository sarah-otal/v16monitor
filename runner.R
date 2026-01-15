while(TRUE) {
  cat("\n--- Update Cycle Started:", as.character(Sys.time()), "---\n")
  
  tryCatch({
    setwd("/home/rserranoga/v16monitor")
    source("/home/rserranoga/v16monitor/script.R")
    
    # Commit changes
    system("git add .")
    # We use '|| true' to prevent the script from stopping if there's nothing to commit
    system('git commit -m "Data Update [skip ci]" || true')
    
    # Pull and Push
    # We fetch first to be safe
    system("git fetch origin main")
    system("git pull --rebase -X ours origin main")
    system("git push origin main")
    
    cat("Success: Repository synchronized.\n")
  }, error = function(e) {
    cat("Cycle Error: ", conditionMessage(e), "\n")
    # Only abort rebase if one is actually happening
    system("git rebase --abort 2>/dev/null") 
  })
  
  cat("Waiting 120 seconds...\n")
  Sys.sleep(120)
}
