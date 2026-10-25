# Paired timing of the same weighted Gaussian integral and conditional mean.
# Synthetic inputs only; this kernel benchmark is not total fit/forecast runtime.
source('validation/autodesn/load_checkout.R')
Rcpp::sourceCpp('src/autodesn_rhs.cpp',cacheDir='validation/autodesn/remediation/artifacts/cpp',showOutput=FALSE)
set.seed(4266100);results<-list();k<-0L
for(p in c(101L,201L,401L)) {
 n<-2000L;X<-cbind(1,matrix(rnorm(n*(p-1)),n,p-1));X[,p]<-X[,p-1];y<-rnorm(n)
 d<-list(X=X,XtX=crossprod(X),Xty=as.vector(crossprod(X,y)))
 lv<-seq(-10,1,length.out=p);ld<-seq(-1.5,1.5,length.out=n)
 R<-.ext_gaussian(d,y,ld,lv,'R');C<-.ext_gaussian(d,y,ld,lv,'cpp')
 stopifnot(abs(R$log_evidence-C$log_evidence)<1e-8,max(abs(R$mean-C$mean))<1e-9)
 for(replicate in 1:9)for(backend in sample(c('R','cpp'))) {
  t<-proc.time();z<-.ext_gaussian(d,y,ld,lv,backend);delta<-proc.time()-t
  k<-k+1L;results[[k]]<-data.frame(n=n,p=p,replicate=replicate,backend=backend,elapsed_seconds=unname(delta[3]),cpu_seconds=unname(sum(delta[1:2])),log_integral=z$log_evidence)
 }
}
r<-do.call(rbind,results);write.csv(r,'validation/autodesn/remediation/evidence/weighted_kernel_timings.csv',row.names=FALSE)
summary<-aggregate(cbind(elapsed_seconds,cpu_seconds)~p+backend,r,median)
jsonlite::write_json(list(complete=TRUE,scope='Paired synthetic weighted Gaussian kernel; other training jobs active, not an isolated total-fit benchmark',threads=1,seed=4266100,replicates=9,n=2000,summary=summary),'validation/autodesn/remediation/evidence/weighted_kernel_benchmark.json',pretty=TRUE,auto_unbox=TRUE)
print(summary)
