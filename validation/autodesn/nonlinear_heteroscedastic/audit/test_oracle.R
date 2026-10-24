source('validation/autodesn/nonlinear_heteroscedastic/dgp.R')
b<-'validation/autodesn/nonlinear_heteroscedastic';d<-read.csv(file.path(b,'input/dgp_truth.csv'));N<-8L;H<-30L;o<-2500L
z<-matrix(sin(seq_len(N*H)*1.2345),H,N);lag<-matrix(rep(rev(d$residual[(o-59):o]),N),60L,N);v<-rep(d$conditional_sd[o]^2,N);e<-rep(d$conditional_sd[o]*d$innovation[o],N);r<-list()
for(h in seq_len(H)) {
 v<-nh_variance(o+h,lag[1,],e,v);f<-nh_location(lag);mu<-nh_season(o+h)+f;e<-sqrt(v)*z[h,];x<-f+e
 r[[h]]<-data.frame(horizon=h,path=seq_len(N),mu=mu,variance=v,y=nh_season(o+h)+x,z=z[h,]);lag<-rbind(x,lag[1:59,,drop=FALSE])
}
write.csv(do.call(rbind,r),file.path(b,'audit/artifacts/oracle_R_reference.csv'),row.names=FALSE)
cat('Independent R continuation exported\n')
