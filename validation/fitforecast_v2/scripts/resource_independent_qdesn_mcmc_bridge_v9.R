#!/usr/bin/env Rscript
args <- commandArgs(TRUE)
cpus <- as.integer(strsplit(args[1],",",fixed=TRUE)[[1]])
stopifnot(length(cpus)==6L,!anyNA(cpus),!anyDuplicated(cpus))
read_cpu <- function() {
  lines <- grep("^cpu[0-9]+ ",readLines("/proc/stat"),value=TRUE)
  x <- lapply(strsplit(trimws(lines),"[[:space:]]+"),function(v)
    c(cpu=as.integer(sub("cpu","",v[1])),total=sum(as.numeric(v[2:9])),idle=sum(as.numeric(v[c(5,6)]))))
  as.data.frame(do.call(rbind,x))
}
siblings <- unique(unlist(lapply(cpus,function(c) {
  text<-readLines(sprintf("/sys/devices/system/cpu/cpu%d/topology/thread_siblings_list",c))
  unlist(lapply(strsplit(text,",")[[1]],function(s) {
    b<-as.integer(strsplit(s,"-",fixed=TRUE)[[1]]);if(length(b)==1)b else seq.int(b[1],b[2]) }))
})))
keys <- vapply(cpus,function(c) paste(readLines(sprintf("/sys/devices/system/cpu/cpu%d/topology/physical_package_id",c)),
  readLines(sprintf("/sys/devices/system/cpu/cpu%d/topology/core_id",c)),sep=":"),"")
stopifnot(!anyDuplicated(keys))
a<-read_cpu();Sys.sleep(3);b<-read_cpu()
i<-match(siblings,a$cpu);j<-match(siblings,b$cpu)
delta<-b$total[j]-a$total[i]
idle<-100*(b$idle[j]-a$idle[i])/delta
sample<-data.frame(cpu=siblings,idle_percent=idle)
stopifnot(all(is.finite(idle)),all(idle>=90))
record<-list(host=unname(Sys.info()["nodename"]),time=format(Sys.time(),tz="UTC",usetz=TRUE),
  cpus=cpus,physical_core_keys=keys,sibling_samples=sample,
  active_R_processes=system2("ps",c("-C","R","-o","pid,ppid,stat,psr,pcpu,rss,args"),stdout=TRUE),
  memory=system2("free","-h",stdout=TRUE),disk=system2("df",c("-h",args[3]),stdout=TRUE),pass=TRUE)
dir.create(dirname(args[2]),recursive=TRUE,showWarnings=FALSE)
jsonlite::write_json(record,args[2],pretty=TRUE,auto_unbox=TRUE,digits=NA)
print(sample)
