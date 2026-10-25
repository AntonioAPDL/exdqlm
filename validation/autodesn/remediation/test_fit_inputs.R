source('validation/autodesn/load_checkout.R')
source('validation/autodesn/remediation/fit_inputs.R')
root<-'validation/autodesn/remediation'
result<-testthat::test_that('study inputs keep the selected mean and validate certificate identities',{
 for(mean in c('F1','F2','F2flat'))for(family in c('SV','SVseasonal')){
  x<-remediation_family_controls(family,list(family=mean))
  testthat::expect_identical(x$mean_family,mean)
  testthat::expect_identical(x$readout$prior,if(mean=='F2')'grouped' else 'flat')
  testthat::expect_identical(x$variance$seasonal,family=='SVseasonal')
  if(mean=='F1'){
   if(family=='SV')testthat::expect_null(x$seasonal) else testthat::expect_identical(x$seasonal$harmonics,0L)
  }else testthat::expect_identical(x$seasonal$harmonics,16L)
 }
 testthat::expect_error(remediation_family_controls('SV'),'qualified mean')
 testthat::expect_error(remediation_family_controls('SVseasonal'),'qualified mean')
 testthat::expect_error(remediation_mean_selection(''),'certificate')
 d<-tempfile('certificate-fixture-');dir.create(d);on.exit(unlink(d,recursive=TRUE))
 input<-file.path(d,'small_training_fixture.txt');writeLines('isolated test input, never a study selection',input)
 selection<-list(complete=TRUE,selection_frozen=TRUE,posterior_qualified=TRUE,chosen_mean_family='F1',heldout_test_used=FALSE,development_cutoffs=c(1500L,2000L),inputs=setNames(list(digest::digest(file=input,algo='sha256')),input))
 path<-file.path(d,'test_certificate.json');jsonlite::write_json(selection,path,auto_unbox=TRUE)
 testthat::expect_identical(remediation_mean_selection(path)$family,'F1')
 writeLines('tampered',input)
 testthat::expect_error(remediation_mean_selection(path),'identity mismatch')
 for(field in c('complete','selection_frozen','posterior_qualified')){
  bad<-selection;bad[[field]]<-FALSE;jsonlite::write_json(bad,path,auto_unbox=TRUE)
  testthat::expect_error(remediation_mean_selection(path),'Invalid')
 }
 bad<-selection;bad$development_cutoffs<-1500L;jsonlite::write_json(bad,path,auto_unbox=TRUE)
 testthat::expect_error(remediation_mean_selection(path),'both qualified development folds')
 bad<-selection;bad$inputs<-unname(bad$inputs);jsonlite::write_json(bad,path,auto_unbox=TRUE)
 testthat::expect_error(remediation_mean_selection(path),'Invalid')
 for(family in c('F1ridge','F2ridge'))testthat::expect_identical(remediation_family_controls(family)$beta_prior,'ridge')
})
jsonlite::write_json(list(complete=TRUE,tests_passed=isTRUE(result),source_sha256=digest::digest(file=file.path(root,'fit_inputs.R'),algo='sha256'),test_sha256=digest::digest(file=file.path(root,'test_fit_inputs.R'),algo='sha256'),production_selection_created=FALSE,scope='Isolated certificate/mean-family control unit checks. Full-bank input preflights and actual fold inference are separate.'),file.path(root,'evidence/fit_inputs_tests.json'),auto_unbox=TRUE,pretty=TRUE)
