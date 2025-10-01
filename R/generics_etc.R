### "exdqlm" objects

is.exdqlm = function(m){ return(methods::is(m,"exdqlm")) }

# addition for "exdqlm" objects
"+.exdqlm" <- function(m1, m2){
  if(methods::is(m1,"dlm")){
    m1 = dlmMod(m1)
    message("m1 converted from a dlm object using 'dlmMod(m1)'")
  }
  if(methods::is(m2,"dlm")){
    m2 = dlmMod(m2)
    message("m2 converted from a dlm object using 'dlmMod(m2)'")
  }
  m1 = check_mod(m1)
  m2 = check_mod(m2)
  n = length(c(m1$m0,m2$m0))
  model<- NULL
  if(ncol(m1$FF)>1 | ncol(m2$FF)>1){
    if(ncol(m1$FF)>1 & ncol(m2$FF)>1 & ncol(m1$FF) != ncol(m2$FF)){
      stop("incompatible number of columns in m1$FF and m2$FF")
    }
    model$FF = matrix(0,n,max(ncol(m1$FF),ncol(m2$FF)))
    model$FF[1:nrow(m1$FF),] = m1$FF
    model$FF[(nrow(m1$FF)+1):n,] = m2$FF
  }else{
    model$FF = matrix(c(m1$FF,m2$FF),n,1)
  }
  if(!is.na(dim(m1$GG)[3]) | !is.na(dim(m2$GG)[3])){
    if(!is.na(dim(m1$GG)[3]) & !is.na(dim(m2$GG)[3]) & dim(m1$GG)[3] != dim(m2$GG)[3]){
      stop("incompatible third dimensions of m1$GG and m2$GG")
    }
    model$GG = array(0,c(n,n,max(dim(m1$GG)[3],dim(m2$GG)[3],na.rm = TRUE)))
    model$GG[1:dim(m1$GG)[1],1:dim(m1$GG)[1],] = m1$GG
    model$GG[(dim(m1$GG)[1]+1):n,(dim(m1$GG)[1]+1):n,] = m2$GG
  }else{
    model$GG = magic::adiag(m1$GG,m2$GG)
  }
  model$m0 = c(m1$m0,m2$m0)
  model$C0 = magic::adiag(m1$C0,m2$C0)
  
  class(model) <- "exdqlm"
  return(model)
}

# print method for "exdqlm" objects
print.exdqlm <- function(x, ...) {
  refnn <- c("m0","C0","FF","GG")
  descrip = c("Prior mean of the state vector:", 
              "Prior covariance of the state vector:",
              "Observational vector:",
              "Evolution matrix:")
  nn <- names(x)
  check <- !sapply(x, is.null)
  ind <- match(refnn,nn)
  ind <- ind[!is.na(ind)]
  final.ind = match(nn[ind][check[ind]],nn)
  # print
  for (i in 1:4){
    cat(descrip[i],"\n")
    print(x[final.ind[i]])
    cat("\n")
  }
}


