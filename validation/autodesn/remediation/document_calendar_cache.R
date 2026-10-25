(function(){
 tmp<-tempfile('calendar-cache-docs-');dir.create(tmp);dir.create(file.path(tmp,'R'))
 on.exit(unlink(tmp,recursive=TRUE),add=TRUE)
 stopifnot(file.copy('DESCRIPTION',tmp),all(file.copy(c('R/autodesn_calendar_cache.R','R/autodesn_statistics_cache.R'),file.path(tmp,'R'))))
 roxygen2::roxygenise(tmp,roclets='rd',load_code=roxygen2::load_source)
 p<-file.path(tmp,'man/autodesn_cache_calendar_blocks.Rd');stopifnot(file.copy(p,file.path('man',basename(p)),overwrite=TRUE))
})()
