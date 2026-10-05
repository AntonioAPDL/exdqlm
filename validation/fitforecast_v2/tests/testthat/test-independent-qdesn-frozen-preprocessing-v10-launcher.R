iqfp_launcher_fixture <- function(mode="success") {
  root <- tempfile("v10-launcher-");dir.create(root)
  repo <- file.path(root,"repo");run <- file.path(root,"run");legacy <- file.path(root,"legacy")
  dir.create(file.path(repo,"validation/fitforecast_v2/scripts"),recursive=TRUE)
  dir.create(file.path(run,"configs"),recursive=TRUE);dir.create(legacy)
  artifact <- file.path(root,"immutable.txt");writeLines("mock source",artifact)
  manifest <- data.frame(path=artifact,sha256=unname(tools::sha256sum(artifact)))
  for(f in c("source_hashes.csv","materialization_hashes.csv"))
    write.csv(manifest,file.path(run,f),row.names=FALSE)
  write.csv(manifest,file.path(legacy,"final_artifact_manifest.csv"),row.names=FALSE)
  writeLines("status=COMPLETE",file.path(legacy,"pipeline.status"))
  jsonlite::write_json(list(status="COMPLETE_INTERNAL_MCMC_BRIDGE",successful_jobs=14L,failures=0L),
    file.path(legacy,"closeout.json"),auto_unbox=TRUE)
  ids <- sprintf("job%02d",1:14);configs <- file.path(run,"configs",paste0(ids,".json"))
  for(i in seq_along(ids))jsonlite::write_json(list(job_id=ids[i]),configs[i],auto_unbox=TRUE)
  plan <- data.frame(job_id=ids,config_path=configs,
    config_sha256=unname(tools::sha256sum(configs)),status_path=file.path(run,"status",ids),
    result_path=file.path(run,"results",ids))
  write.csv(plan,file.path(run,"plan.csv"),row.names=FALSE)
  script <- file.path(repo,"validation/fitforecast_v2/scripts/independent_qdesn_frozen_preprocessing_v10.R")
  writeLines("# Mock worker entry point",script)
  writeLines("# Mock resource entry point",file.path(dirname(script),"resource_independent_qdesn_mcmc_bridge_v9.R"))
  wrapper <- file.path(root,"mock-rscript")
  writeLines(c("#!/usr/bin/env bash","set -euo pipefail",
    "if [[ ${2-} == -e ]]; then",
    "  if [[ $MOCK_MODE == extract_error && $3 == *'cat(paste('* ]]; then exit 53; fi",
    "  exec \"$REAL_RSCRIPT\" \"$@\"","fi",
    "if [[ ${2-} == *resource_independent_qdesn_mcmc_bridge_v9.R ]]; then exit 0; fi",
    "case ${4-} in",
    "worker)","  id=$(basename \"$5\" .json)",
    "  mkdir -p \"$RUN_ROOT/started\" \"$RUN_ROOT/finished\"",
    "  printf '%s\\n' \"$BASHPID\" > \"$RUN_ROOT/started/$id\"",
    "  if [[ $MOCK_MODE == worker_fail && $id == job01 ]]; then exit 17; fi",
    "  sleep 0.6","  printf 'done\\n' > \"$RUN_ROOT/finished/$id\"","  ;;",
    "closeout)","  if [[ $MOCK_MODE == closeout_fail ]]; then exit 32; fi",
    "  printf '{}\\n' > \"$RUN_ROOT/closeout.json\"","  ;;",
    "*) exit 54 ;;","esac"),wrapper)
  Sys.chmod(wrapper,"0755")
  allowed <- Sys.getenv("IQFP_TEST_CPU_LIST",readLines("/sys/devices/system/cpu/online"))
  cpus <- unlist(lapply(strsplit(allowed,",",fixed=TRUE)[[1]],function(x) {
    b <- as.integer(strsplit(x,"-",fixed=TRUE)[[1]]);if(length(b)==1L)b else seq.int(b[1],b[2])
  }))
  stopifnot(length(cpus)>=6L)
  list(root=root,repo=repo,run=run,legacy=legacy,artifact=artifact,plan=plan,
    env=c(REPO_ROOT=repo,RUN_ROOT=run,LEGACY_RUN_ROOT=legacy,RSCRIPT=wrapper,
      REAL_RSCRIPT=file.path(R.home("bin"),"Rscript"),CPU_LIST=paste(head(cpus,6),collapse=","),MOCK_MODE=mode))
}

iqfp_launcher_start <- function(f) {
  processx::process$new("bash",file.path(harness_root,
    "scripts/run_independent_qdesn_frozen_preprocessing_v10.sh"),env=f$env,
    stdout=file.path(f$root,"launcher.log"),stderr=file.path(f$root,"launcher.err"))
}

iqfp_launcher_state <- function(f) {
  file <- file.path(f$run,"pipeline.status")
  if(!file.exists(file))return("")
  sub("^status=","",grep("^status=",readLines(file),value=TRUE))
}

iqfp_launcher_wait <- function(p,f) {
  p$wait(timeout=30000)
  if(p$is_alive()) {
    p$signal(15L);p$wait(timeout=10000)
    stop("Mock launcher exceeded its test budget: ",f$root)
  }
  p$get_exit_status()
}

test_that("real Bash scheduler handles empty startup, multiple waves and final drain", {
  f <- iqfp_launcher_fixture();p <- iqfp_launcher_start(f)
  expect_equal(iqfp_launcher_wait(p,f),0L)
  expect_identical(iqfp_launcher_state(f),"COMPLETE")
  x <- read.csv(file.path(f$run,"launcher_exit_codes.csv"))
  expect_equal(nrow(x),14L);expect_equal(sort(x$job_id),f$plan$job_id)
  expect_true(all(x$exit_code==0L));expect_equal(length(unique(x$cpu)),6L)
  expect_equal(length(list.files(file.path(f$run,"finished"))),14L)
  m <- read.csv(file.path(f$run,"final_artifact_manifest.csv"))
  expect_true(all(unname(tools::sha256sum(m$path))==m$sha256))
  expect_false(any(basename(m$path)=="pipeline.status"))
  old <- readLines(file.path(f$run,"pipeline.status"))
  again <- iqfp_launcher_start(f)
  expect_equal(iqfp_launcher_wait(again,f),74L)
  expect_identical(readLines(file.path(f$run,"pipeline.status")),old)
})

test_that("a worker failure stops new scheduling and drains existing workers", {
  f <- iqfp_launcher_fixture("worker_fail");p <- iqfp_launcher_start(f)
  expect_equal(iqfp_launcher_wait(p,f),1L)
  expect_identical(iqfp_launcher_state(f),"FAILED_REPLAY")
  x <- read.csv(file.path(f$run,"launcher_exit_codes.csv"))
  expect_equal(nrow(x),6L);expect_equal(sum(x$exit_code!=0L),1L)
  expect_equal(x$exit_code[x$job_id=="job01"],17L)
  expect_equal(length(list.files(file.path(f$run,"started"))),6L)
  expect_equal(length(list.files(file.path(f$run,"finished"))),5L)
  expect_false(file.exists(file.path(f$run,"closeout.json")))
})

test_that("a duplicate launcher cannot change the owning launcher's state", {
  f <- iqfp_launcher_fixture();p <- iqfp_launcher_start(f)
  deadline <- Sys.time()+10
  while(iqfp_launcher_state(f)!="RUNNING_REPLAY" && p$is_alive() && Sys.time()<deadline)Sys.sleep(.02)
  expect_identical(iqfp_launcher_state(f),"RUNNING_REPLAY")
  other <- iqfp_launcher_start(f)
  expect_equal(iqfp_launcher_wait(other,f),73L)
  state <- readLines(file.path(f$run,"pipeline.status"))
  expect_true(paste0("launcher_pid=",p$get_pid()) %in% state)
  expect_equal(iqfp_launcher_wait(p,f),0L)
})

test_that("source failures and fatal preflight exits produce truthful terminal states", {
  f <- iqfp_launcher_fixture();writeLines("status=FAILED",file.path(f$legacy,"pipeline.status"))
  p <- iqfp_launcher_start(f)
  expect_equal(iqfp_launcher_wait(p,f),1L)
  expect_identical(iqfp_launcher_state(f),"BLOCKED_SOURCE_CAMPAIGN")
  expect_false(dir.exists(file.path(f$run,"started")))
  f <- iqfp_launcher_fixture();f$env["REPO_ROOT"] <- file.path(f$root,"missing-repo")
  p <- iqfp_launcher_start(f)
  expect_true(iqfp_launcher_wait(p,f)!=0L)
  expect_identical(iqfp_launcher_state(f),"FAILED_PREFLIGHT")
  expect_false(dir.exists(file.path(f$run,"started")))
})

test_that("empty, malformed and corrupt plans fail before any child starts", {
  for(mode in c("empty","duplicate","missing","corrupt","wrong_count")) {
    f <- iqfp_launcher_fixture();x <- f$plan
    if(mode=="empty")x <- x[FALSE,]
    if(mode=="duplicate")x$job_id[2] <- x$job_id[1]
    if(mode=="missing")x$config_path[1] <- file.path(f$root,"absent.json")
    if(mode=="corrupt")x$config_sha256[1] <- paste(rep("0",64),collapse="")
    if(mode=="wrong_count")x <- x[-1,]
    write.csv(x,file.path(f$run,"plan.csv"),row.names=FALSE)
    p <- iqfp_launcher_start(f)
    expect_true(iqfp_launcher_wait(p,f)!=0L,info=mode)
    expect_identical(iqfp_launcher_state(f),"FAILED_MANIFEST_OR_PLAN",info=mode)
    expect_false(dir.exists(file.path(f$run,"started")),info=mode)
  }
})

test_that("manifest and row-extraction errors do not disappear in process substitution", {
  f <- iqfp_launcher_fixture();writeLines("changed",f$artifact)
  p <- iqfp_launcher_start(f)
  expect_true(iqfp_launcher_wait(p,f)!=0L)
  expect_identical(iqfp_launcher_state(f),"FAILED_MANIFEST_OR_PLAN")
  expect_false(dir.exists(file.path(f$run,"started")))
  f <- iqfp_launcher_fixture("extract_error");p <- iqfp_launcher_start(f)
  expect_equal(iqfp_launcher_wait(p,f),53L)
  expect_identical(iqfp_launcher_state(f),"FAILED_MANIFEST_OR_PLAN")
  expect_false(dir.exists(file.path(f$run,"started")))
})

test_that("closeout failure cannot be marked complete", {
  f <- iqfp_launcher_fixture("closeout_fail");p <- iqfp_launcher_start(f)
  expect_equal(iqfp_launcher_wait(p,f),32L)
  expect_identical(iqfp_launcher_state(f),"FAILED_CLOSEOUT")
  expect_equal(nrow(read.csv(file.path(f$run,"launcher_exit_codes.csv"))),14L)
  expect_false(file.exists(file.path(f$run,"final_artifact_manifest.csv")))
})

test_that("an interrupted scheduler drains its own mock workers without scheduling more", {
  f <- iqfp_launcher_fixture();p <- iqfp_launcher_start(f)
  deadline <- Sys.time()+10
  while(length(list.files(file.path(f$run,"started")))<6L && p$is_alive() && Sys.time()<deadline)Sys.sleep(.02)
  expect_equal(length(list.files(file.path(f$run,"started"))),6L)
  p$signal(15L)
  expect_equal(iqfp_launcher_wait(p,f),130L)
  expect_identical(iqfp_launcher_state(f),"INTERRUPTED_DRAINED")
  x <- read.csv(file.path(f$run,"launcher_exit_codes.csv"))
  expect_equal(nrow(x),6L);expect_true(all(x$exit_code==0L))
  expect_equal(length(list.files(file.path(f$run,"finished"))),6L)
})
