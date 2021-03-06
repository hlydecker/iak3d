#################################################################
### iaCovMatern gives analytical version for matern (nu = 0.5/1.5/2.5) with ns sd = tau0 + tau1 exp(-tau2 d)
#################################################################
iaCovMatern <- function(dIData , ad , nud , sdfdPars , sdfdType , abcd , iUElements){
  
  n <- dim(dIData)[[1]]
  
  ###########################################################
  ### assuming nud = 0.5 / 1.5 / 2.5
  ### ri and psi values from Wikipedia
  ###########################################################
  if (nud == 0.5){
    r0 <- 1
    r1 <- 0
    r2 <- 0
    psi <- 1 / ad
  }else if(nud == 1.5){
    r0 <- 1
    r1 <- sqrt(3) / ad
    r2 <- 0
    psi <- sqrt(3) / ad
  }else if(nud == 2.5){
    r0 <- 1
    r1 <- sqrt(5) / ad
    r2 <- 5 / (3 * (ad ^ 2))
    psi <- sqrt(5) / ad
  }else{
    stop('This function can only be applied with nud = 0.5, 1.5 or 2.5!')
  }
  
  ########################################################       
  ### assuming type is -1, exp change to steady state...
  ### if sdfdPars = 0, put tau0 = 1, tau1 = 0, tau2 = 1 (tau2 won't contribute to function with tau1 = 0)
  ### if sdfdPars = -1, put tau0 = 1 - sdfdPars[1], tau1 = sdfdPars[1], tau2 = sdfdPars[2]    
  ########################################################       
  if(sdfdType == 0){
    tau0 <- 1
    tau1 <- 0
    tau2 <- 1
  }else if(sdfdType == -1){
    tau0 <- 1 - sdfdPars[1]
    tau1 <- sdfdPars[1]
    tau2 <- sdfdPars[2]
  }else{
    stop('This function van only be applied with sdfdType = 0 or -1!')
  }
  
  nsMaternParams <- list('r0' = r0 , 'r1' = r1 , 'r2' = r2 , 'psi' = psi , 'tau0' = tau0 ,'tau1' = tau1 ,'tau2' = tau2) 
  
  ###############################################
  ### calculate the increment-averaged variances, which are rqd for lnN version...
  ###############################################
  avVarVec <- (tau0 ^ 2) * (dIData[,2] - dIData[,1]) - 2 * (tau0 * tau1 / tau2) * (exp(-tau2 * dIData[,2]) - exp(-tau2 * dIData[,1])) - 0.5 * ((tau1 ^ 2) / tau2) * (exp(-2 * tau2 * dIData[,2]) - exp(-2 * tau2 * dIData[,1]))
  avVarVec <- avVarVec / (dIData[,2] - dIData[,1])
  
  ###############################################
  ### take the pairs that contribute to lower diagonal elements...
  ### and arrange the 2 intervals as 4 columns so that first column (aa) is always smallest...
  ###############################################
  if(missing(abcd)){
    iTmp <- kronecker(seq(n) , matrix(1 , n , 1))
    jTmp <- kronecker(matrix(1 , n , 1) , seq(n))
    ijTmp <- cbind(iTmp , jTmp)
    iUElements <- which(ijTmp[,1] <= ijTmp[,2])
    ijTmp <- ijTmp[iUElements ,,drop=FALSE]
    abcd <- matrix(cbind(dIData[ijTmp[,1],,drop=FALSE] , dIData[ijTmp[,2],,drop=FALSE]) , ncol = 4)
    
    iTmp <- apply(abcd[,c(1,3),drop=FALSE] , 1 , which.min)
    iTmp <- which(iTmp == 2)
    if(length(iTmp) > 0){ abcd[iTmp,] <- abcd[iTmp,c(3,4,1,2),drop=FALSE] }else{}
  }else{}
  
  #############################
  ### get the entries that aregiven by the 3 cases of the integration region...	
  #############################
  iCase1 <- which(abcd[,2] <= abcd[,3])
  iCase2 <- which((abcd[,3] < abcd[,2]) & (abcd[,2] <= abcd[,4]))
  iCase3 <- which((abcd[,3] < abcd[,2]) & (abcd[,4] < abcd[,2]))
  
  avCov <- NA * abcd[,1]
  avCov[iCase1] <- intRy(aa = abcd[iCase1,1] , bb = abcd[iCase1,2] , cc = abcd[iCase1,3] , dd = abcd[iCase1,4] , nsMaternParams = nsMaternParams) 
  avCov[iCase2] <- intRy(aa = abcd[iCase2,1] , bb = abcd[iCase2,3] , cc = abcd[iCase2,3] , dd = abcd[iCase2,4] , nsMaternParams = nsMaternParams) +
    intRy(aa = abcd[iCase2,3] , bb = abcd[iCase2,2] , cc = abcd[iCase2,2] , dd = abcd[iCase2,4] , nsMaternParams = nsMaternParams) +
    2 * intTy(aa = abcd[iCase2,3] , bb = abcd[iCase2,2] , nsMaternParams = nsMaternParams)
  avCov[iCase3] <- intRy(aa = abcd[iCase3,1] , bb = abcd[iCase3,3] , cc = abcd[iCase3,3] , dd = abcd[iCase3,4] , nsMaternParams = nsMaternParams) +
    intRy(aa = abcd[iCase3,3] , bb = abcd[iCase3,4] , cc = abcd[iCase3,4] , dd = abcd[iCase3,2] , nsMaternParams = nsMaternParams) +
    2 * intTy(aa = abcd[iCase3,3] , bb = abcd[iCase3,4] , nsMaternParams = nsMaternParams)
  
  avCov <- avCov / ((abcd[,4] - abcd[,3]) * (abcd[,2] - abcd[,1]))
  
  avCovMtx <- matrix(0 , n , n)
  avCovMtx[iUElements] <- avCov
  if(n > 1){
    avCovMtx <- avCovMtx + t(avCovMtx) - diag(diag(avCovMtx))
  }else{}
  
  return(list('avCovMtx' = avCovMtx , 'avVarVec' = avVarVec))
} 

############################################
### now some useful functions...
############################################
gammafnInt <- function(alpha , a){
  ### alpha assumed to be length 3, representing quaratic coefficients (
  if(length(alpha) != 3){
    stop('Error! alpha for gammafnInt must be length 3, representing quadratic coeffients')
  }else{}
  
  gamma <- NA * numeric(3)
  gamma[1] <- -(alpha[1] + alpha[2] / a + 2 * alpha[3] / (a ^ 2))
  gamma[2] <- -(alpha[2] + 2 * alpha[3] / a)
  gamma[3] <- -(alpha[3])
  
  return(gamma)        
}

poly2Exp <- function(w , alpha , psi){
  ### evaluates (alpha0 + alpha1 w + alpha2 (w ^ 2) ) * exp(-psi w)   
  return( (alpha[1] + alpha[2] * w + alpha[3] * (w ^ 2)) * exp(-psi * w) )   
}

#################################
### function for integral of covariance over square region, 
### from x = aa to bb, y = cc to dd, where y > x
#################################
intRy <- function(aa , bb , cc , dd , nsMaternParams){
  
  intRy <- intRy12(ee = dd , aa = aa , bb = bb , nsMaternParams = nsMaternParams) - intRy12(ee = cc , aa = aa , bb = bb , nsMaternParams = nsMaternParams) + 
    intRy34(ee = dd , aa = aa , bb = bb , nsMaternParams = nsMaternParams) - intRy34(ee = cc , aa = aa , bb = bb , nsMaternParams = nsMaternParams)
  
  return(intRy)
}


intRy12 <- function(ee, aa , bb , nsMaternParams){
  ### note definitions with 'aa' etc to avoid confusion with the function 'c'    
  gamma1 <- gammafnInt(alpha = c(nsMaternParams$r0 , nsMaternParams$r1 , nsMaternParams$r2) , a = nsMaternParams$psi)
  gamma11 <- gammafnInt(alpha = gamma1 , a = nsMaternParams$psi)
  psi_tau2 <- nsMaternParams$psi - nsMaternParams$tau2
  ### to avoid numerical errors with very small absolute values of psi - tau2...        
  if((psi_tau2 >= 0) & (psi_tau2 < 1E-3)){
    psi_tau2 <- 1E-3
  }else if((psi_tau2 < 0) & (psi_tau2 > -1E-3)){
    psi_tau2 <- -1E-3
  }else{}
  
  gamma12 <- gammafnInt(alpha = gamma1 , a = psi_tau2)
  
  intRy12 <- -((nsMaternParams$tau0 ^ 2) / (nsMaternParams$psi ^ 2)) * 
    (poly2Exp(ee - bb , gamma11 , nsMaternParams$psi) - poly2Exp(ee - aa , gamma11 , nsMaternParams$psi)) - 
    ((nsMaternParams$tau0 * nsMaternParams$tau1) / (nsMaternParams$psi * psi_tau2)) * exp(-nsMaternParams$tau2 * ee) *
    (poly2Exp(ee - bb , gamma12 , psi_tau2) - poly2Exp(ee - aa , gamma12 , psi_tau2))        
  
  return(intRy12)
}

intRy34 <- function(ee, aa , bb , nsMaternParams){
  ### note definitions with 'aa' etc to avoid confusion with the function 'c'    
  gamma1 <- gammafnInt(alpha = c(nsMaternParams$r0 , nsMaternParams$r1 , nsMaternParams$r2) , a = nsMaternParams$psi + nsMaternParams$tau2)
  gamma11 <- gammafnInt(alpha = gamma1 , a = nsMaternParams$psi)
  
  psi_tau2 <- nsMaternParams$psi - nsMaternParams$tau2
  ### to avoid numerical errors with very small absolute values of psi - tau2...        
  if((psi_tau2 >= 0) & (psi_tau2 < 1E-3)){
    psi_tau2 <- 1E-3
  }else if((psi_tau2 < 0) & (psi_tau2 > -1E-3)){
    psi_tau2 <- -1E-3
  }else{}
  
  gamma12 <- gammafnInt(alpha = gamma1 , a = psi_tau2)
  
  intRy34 <- -((nsMaternParams$tau0 * nsMaternParams$tau1) / ((nsMaternParams$psi + nsMaternParams$tau2) * nsMaternParams$psi)) * exp(-nsMaternParams$tau2 * ee) * 
    (poly2Exp(ee - bb , gamma11 , nsMaternParams$psi) - poly2Exp(ee - aa , gamma11 , nsMaternParams$psi)) -
    ((nsMaternParams$tau1 ^ 2) / ((nsMaternParams$psi + nsMaternParams$tau2) * psi_tau2)) * exp(-2 * nsMaternParams$tau2 * ee) * 
    (poly2Exp(ee - bb , gamma12 , psi_tau2) - poly2Exp(ee - aa , gamma12 , psi_tau2))        
  
  return(intRy34)
}

#################################
### function for integral of covariance over triangular region bounded by diagonal, 
### from x = aa to bb, where y > x
#################################
intTy <- function(aa , bb , nsMaternParams){
  
  gamma1 <- gammafnInt(alpha = c(nsMaternParams$r0 , nsMaternParams$r1 , nsMaternParams$r2) , a = nsMaternParams$psi)
  gamma11 <- gammafnInt(alpha = gamma1 , a = nsMaternParams$psi)
  psi_tau2 <- nsMaternParams$psi - nsMaternParams$tau2
  ### to avoid numerical errors with very small absolute values of psi - tau2...        
  if((psi_tau2 >= 0) & (psi_tau2 < 1E-3)){
    psi_tau2 <- 1E-3
  }else if((psi_tau2 < 0) & (psi_tau2 > -1E-3)){
    psi_tau2 <- -1E-3
  }else{}
  
  gamma12 <- gammafnInt(alpha = gamma1 , a = psi_tau2)
  
  gamma2 <- gammafnInt(alpha = c(nsMaternParams$r0 , nsMaternParams$r1 , nsMaternParams$r2) , a = nsMaternParams$psi + nsMaternParams$tau2)
  gamma21 <- gammafnInt(alpha = gamma2 , a = nsMaternParams$psi)
  gamma22 <- gammafnInt(alpha = gamma2 , a = psi_tau2)
  
  tmp <- exp(-nsMaternParams$tau2 * cbind(aa , bb , 2 * aa , 2 * bb))
  exp_tau2aa <- tmp[,1] 
  exp_tau2bb <- tmp[,2] 
  exp_2tau2aa <- tmp[,3] 
  exp_2tau2bb <- tmp[,4] 
  
  intTy1 <- -((nsMaternParams$tau0 ^ 2) / (nsMaternParams$psi ^ 2)) * 
    (gamma11[1] - poly2Exp(bb - aa , gamma11 , nsMaternParams$psi)) - 
    ((nsMaternParams$tau0 * nsMaternParams$tau1) / (nsMaternParams$psi * psi_tau2)) * exp_tau2bb *
    (gamma12[1] - poly2Exp(bb - aa , gamma12 , psi_tau2))        
  
  intTy2 <- ((nsMaternParams$tau0 ^ 2) / nsMaternParams$psi) * gamma1[1] * (bb - aa) - 
    ((nsMaternParams$tau0 * nsMaternParams$tau1) / (nsMaternParams$psi * nsMaternParams$tau2)) * gamma1[1] * 
    (exp_tau2bb - exp_tau2aa)        
  
  intTy3 <- -((nsMaternParams$tau0 * nsMaternParams$tau1) / (nsMaternParams$psi * (nsMaternParams$psi + nsMaternParams$tau2))) * exp_tau2bb *
    (gamma21[1] - poly2Exp(bb - aa , gamma21 , nsMaternParams$psi)) - 
    ((nsMaternParams$tau1 ^ 2) / ((nsMaternParams$psi + nsMaternParams$tau2) * psi_tau2)) * exp_2tau2bb *
    (gamma22[1] - poly2Exp(bb - aa , gamma22 , psi_tau2))        
  
  intTy4 <- -((nsMaternParams$tau0 * nsMaternParams$tau1) / (nsMaternParams$tau2 * (nsMaternParams$psi + nsMaternParams$tau2))) * gamma2[1] * 
    (exp_tau2bb - exp_tau2aa) - 
    ((nsMaternParams$tau1 ^ 2) / (2 * (nsMaternParams$psi + nsMaternParams$tau2) * nsMaternParams$tau2)) * gamma2[1] * 
    (exp_2tau2bb - exp_2tau2aa)        
  
  intTy <- intTy1 - intTy2 + intTy3 - intTy4
  
  return(intTy)
}

##################################################################
### the matern covariance function...
##################################################################
maternCov <- function(D , pars){
  c1 <- pars[1]
  a <- pars[2]
  nu <- pars[3]
  
  ########################################################
  ########################################################
  ### TEMP ADDITION TO RETURN SPHERICAL COV FOR TESTING...
  ########################################################
  ########################################################
  useSpher <- FALSE
  
  if(useSpher){
    if((c1 > 0) & (a > 0) & (nu >= 0.05)  & (nu <= 20)){
      DOVERa <- D / a
      C <- 1 - (1.5 * DOVERa - 0.5 * (DOVERa ^ 3) )
      C[which(DOVERa > 1)] <- 0
      C <- c1 * C
    }else{
      C <- NA
    }
    
    return(C)
  }else{}
  
  ########################################################
  ########################################################
  ########################################################
  
  if((c1 > 0) & (a > 0) & (nu >= 0.05)  & (nu <= 20)){
    
    iD0 <- which(D == 0)
    iDGT0 <- which(D > 0)
    
    ### range is approx rho * 3...this is from wiki, 
    ### and is i think what stein's parameterization was supposed to be.
    sqrt2nuOVERa <- sqrt(2 * nu) / a 
    Dsqrt2nuOVERa <- D * sqrt2nuOVERa  
    
    bes <- 0 * D
    bes[iDGT0] <- besselK(Dsqrt2nuOVERa[iDGT0] , nu) 
    
    lnconstmatern <- NA * Dsqrt2nuOVERa
    lnconstmatern[iDGT0] <- nu * log(Dsqrt2nuOVERa[iDGT0]) - (nu - 1) * log(2) - lgamma(nu)
    
    realmin <- 3.448490e-304 
    ibesGT0 <- which(bes > realmin)
    
    C <- 0 * D # initiate.
    C[ibesGT0] <- c1 * exp(lnconstmatern[ibesGT0]+log(bes[ibesGT0]))
    C[iD0] <- c1
    C[which(is.infinite(bes))] <- c1
    
  }else{
    C <- NA
  }
  
  return(C)
}

##################################################################
### to set up random-effects design matrices and disc pts (if needed)
##################################################################
setupIAK3D <- function(xData , dIData , nDscPts = 0 , partSetup = FALSE){
  ### note, I only use 'U' for unique in xU and dIU.
  ### Dx and other mats are defined with the unique locations, 
  ### but for simpler notation I don't use the 'U' notation there. 
  xU <- xData[!duplicated(xData),,drop=FALSE]
  dIU <- dIData[!duplicated(dIData),,drop=FALSE]
  
  ndIU <- nrow(dIU)
  nxU <- nrow(xU)
  
  iK <- jK <- c()
  for (i in 1:nxU){
    iKThis <- which((xData[,1] == xU[i,1]) & (xData[,2] == xU[i,2]))
    iK <- c(iK , iKThis)
    jK <- c(jK , matrix(i , length(iKThis) , 1))
  }
  Kx <- sparseMatrix(i = iK , j = jK , x = 1)
  
  iK <- jK <- c()
  for (i in 1:ndIU){
    iKThis <- which((dIData[,1] == dIU[i,1]) & (dIData[,2] == dIU[i,2]))
    iK <- c(iK , iKThis)
    jK <- c(jK , matrix(i , length(iKThis) , 1))
  }
  Kd <- sparseMatrix(i = iK , j = jK , x = 1)
  
  #############################################################
  ### to have proper variances at least down to 2 m for valid predictions to all GSM depths. 
  #############################################################
  maxd <- max(max(dIU) , 2) 
  
  #################################################    
  ### can return here if partSetup is TRUE...
  #################################################    
  if(partSetup){
    return(list('xU' = xU , 'Kx' = Kx , 'dIU' = dIU , 'Kd' = Kd , 'maxd' = maxd))  
  }else{}
  
  Dx <- xyDist(xU , xU)
  
  #############################################
  ### and the disc pts, if numerical approx of average covariances is being used...
  ### not being used in the current code, but left in as might be used for checking in future.
  #############################################
  if(nDscPts > 0){
    dDsc <- dIU[,1] + (dIU[,2] - dIU[,1]) %*% matrix(seq(0.5/nDscPts, 1 - 0.5/nDscPts , 1 / nDscPts) , 1 , nDscPts)
    dDsc <- matrix(t(dDsc) , nDscPts * ndIU , 1)
    
    DdDsc <- xyDist(dDsc , dDsc)
    KdDsc <- kronecker(sparseMatrix(i=seq(ndIU) , j = seq(ndIU) , x = 1), matrix(1 , nDscPts , 1))
  }else{
    dDsc <- DdDsc <- KdDsc <- NA
  }
  
  ###########################################################
  ### and the setup stuff for the analytical version...
  ###########################################################
  iTmp <- kronecker(seq(ndIU) , matrix(1 , ndIU , 1))
  jTmp <- kronecker(matrix(1 , ndIU , 1) , seq(ndIU))
  ijTmp <- cbind(iTmp , jTmp)
  iUElements <- which(ijTmp[,1] <= ijTmp[,2])
  ijTmp <- ijTmp[iUElements ,,drop=FALSE]
  abcd <- cbind(dIU[ijTmp[,1],,drop=FALSE] , dIU[ijTmp[,2],,drop=FALSE])
  
  iTmp <- apply(abcd[,c(1,3),drop=FALSE] , 1 , which.min)
  iTmp <- which(iTmp == 2)
  if(length(iTmp) > 0){ abcd[iTmp,] <- abcd[iTmp,c(3,4,1,2),drop=FALSE] }else{}
  
  return(list('xU' = xU , 'Kx' = Kx , 'Dx' = Dx , 'dIU' = dIU , 'Kd' = Kd ,  
              'dDsc' = dDsc , 'KdDsc' = KdDsc , 'DdDsc' = DdDsc , 'nDscPts' = nDscPts , 
              'dIUabcd' = abcd , 'dIUiUElements' = iUElements , 'maxd' = maxd))  
}

##########################################################
### compute ia covs with matern correlation, exp fn for vars, using discretization approach...
##########################################################
iaCovDsc <- function(dIData , ad , nud , sdfdPars , sdfdType , dDsc , DdDsc , KdDsc , nDscPts = 50){
  ndI <- dim(dIData)[[1]]
  
  ### put these in as inputs...
  if(missing(dDsc)){
    dDsc <- dIData[,1] + (dIData[,2] - dIData[,1]) %*% matrix(seq(0.5/nDscPts, 1 - 0.5/nDscPts , 1 / nDscPts) , 1 , nDscPts)
    dDsc <- matrix(t(dDsc) , nDscPts * ndI , 1)
    
    DdDsc <- xyDist(dDsc , dDsc)
    KdDsc <- kronecker(sparseMatrix(i=seq(ndI) , j = seq(ndI) , x = 1), matrix(1 , nDscPts , 1))
  }else{}
  
  phidDsc <- maternCov(DdDsc , c(1 , ad , nud))
  
  ### set up so that sdfd (d == 0) = 1...
  sdfdDsc <- sdfd(dDsc , sdfdPars , sdfdType)
  
  parsOK <- T
  if ((length(sdfdDsc) == 1) && (is.na(sdfdDsc))){ parsOK <- F }else{}
  
  if(parsOK){
    ### make CdDsc...
    CdDsc <- (sdfdDsc %*% t(sdfdDsc)) * phidDsc
    
    ### average...
    Cd <- (1/(nDscPts^2)) * (t(KdDsc) %*% CdDsc %*% KdDsc)
  }else{
    Cd <- NA
  }
  return(Cd)
}

##################################################
### empirical horizontal variogram with hxBins (2 cols, lower and upper for each bin)...
##################################################
varioCloud <- function(xData , zData , decl = 0){
  
  sepDists <- xyDist(xData , xData)
  if(decl > 0){
    #    wData <- rowSums(sepDists < (max(sepDists)/50))
    wData <- rowSums(sepDists < decl)
    wData <- 1 / wData
    wData <- wData / sum(wData)
  }else{
    wData <- rep(1 / nrow(xData) , nrow(xData))
  }
  ww <- matrix(wData , ncol = 1) %*% matrix(wData , nrow = 1)
  
  semivar <- 0.5 * (xyDist(zData , zData) ^ 2)
  
  n <- length(zData)
  
  ijTmp <- cbind(kronecker(seq(n) , matrix(1 , n , 1)) , kronecker(matrix(1 , n , 1) , seq(n)))
  ijTmp <- ijTmp[which(ijTmp[,2] > ijTmp[,1]),]
  sepDists <- sepDists[ijTmp]
  semivar <- semivar[ijTmp]
  ww <- ww[ijTmp]
  
  iGT0 <- which(sepDists > 0)
  sepDists <- sepDists[iGT0]
  semivar <- semivar[iGT0] 
  ww <- ww[iGT0]
  
  return(list('sepDists' = sepDists , 'semivar' = semivar , 'ww' = ww))
}

vario <- function(hxBins , xData , zData , decl = 0){
  vTmp <- varioCloud(xData = xData , zData = zData , decl = decl)
  
  vgm <- hxAv <- nAv <- NA * hxBins[,1]
  for(ihx in 1:nrow(hxBins)){
    iThis <- which(vTmp$sepDists >= hxBins[ihx,1] & vTmp$sepDists < hxBins[ihx,2])
    if(decl > 0){
      vgm[ihx] <- sum(vTmp$ww[iThis] * vTmp$semivar[iThis])/sum(vTmp$ww[iThis])
    }else{
      vgm[ihx] <- mean(vTmp$semivar[iThis])
    }
    hxAv[ihx] <- mean(vTmp$sepDists[iThis])
    nAv[ihx] <- length(iThis)
  }
  return(list('vgm' = vgm , 'hxAv' = hxAv , 'nAv' = nAv))
}

covCloud <- function(xData , zData){
  
  n <- length(zData)
  
  if(is.null(dim(xData))){
    xData <- matrix(xData , ncol = 1)
  }else{}
  
  dfx <- data.frame(matrix(NA , ncol = 2 * ncol(xData) + 1, nrow = 0.5 * n * (n + 1)))
  names(dfx) <- c(paste0('x1.' , seq(1 , ncol(xData))) , paste0('x2.' , seq(1 , ncol(xData))) , 'cov')
  iNext <- 1 
  for(i in 1:n){
    x1This <- xData[i,,drop=FALSE]
    x2This <- xData[seq(i,n),,drop=FALSE]
    z1This <- zData[i]
    z2This <- zData[seq(i,n)]
    for(j in 1:ncol(xData)){
      dfx[iNext:(iNext+length(z2This)-1),j] <- x1This[,j]
      dfx[iNext:(iNext+length(z2This)-1),j+ncol(xData)] <- x2This[,j]
    }
    dfx$cov[iNext:(iNext+length(z2This)-1)] <- z1This * z2This
    
    iNext <- iNext + length(z2This)
  }
  
  return(dfx)
}

####################################################################
### distance function...
####################################################################
xyDist <- function(xData , yData){
  
  if(is.null(dim(xData)) & is.null(dim(yData))){
    xData <- matrix(xData , ncol = 1)
    yData <- matrix(yData , ncol = 1)
  }else{}
  
  if(!is.element(class(xData) , c('matrix' , 'Matrix' , 'dgeMatrix' , 'data.frame'))){ stop('Error - xyDist function programmed for matrices or data.frames!') }
  if(!is.element(class(yData) , c('matrix' , 'Matrix' , 'dgeMatrix' , 'data.frame'))){ stop('Error - xyDist function programmed for matrices or data.frames!') }
  
  nd <- ncol(xData)
  if(ncol(yData) != nd){ stop('Error - both xData and yData must have the same number of columns!') }else{}
  
  nx <- nrow(xData)
  ny <- nrow(yData)
  
  D <- matrix(0 , nx , ny)
  for(id in 1:nd){
    D <- D + (matrix(xData[,id] , nx , ny) - matrix(yData[,id] , nx , ny , byrow = TRUE)) ^ 2
  }
  D <- sqrt(D)
  
  return(D)
}

####################################################################
### for plotting the covariance function (as variogram) for given depths...
### overlapsByRegression = FALSE removes overlapping depth intervals for harmonixing with eas
### overlapsByRegression = TRUE removes full profiles with overlap or 1 depth interval; then
###                             fits regression to predict profile using fully fitted eas fns as calibration covariate data
###                             and the actual sampled (overlapping) horizons as prediction covariates 
####################################################################
plotCovx <- function(lmm.fit , hx , dIPlot , addExpmntlV = TRUE , hzntlUnits = 'km' , ylim = NULL , roundTo = NULL , noPlot = FALSE , overlapsByRegression = TRUE){
  
  if(is.null(roundTo)){ spline4ExpV <- TRUE }else{ spline4ExpV <- FALSE }
  
  if (hx[1] != 0){ stop('For the plotCov function, enter hx with first element 0!') }else{}
  hxBins <- cbind(hx[-length(hx)] , hx[-1])
  hxModelPlot <- seq(0 , max(hx) , max(hx) / 500)
  
  if(spline4ExpV){
    ### run a hack of mppsline funtion with residuals...
    tmp <- harmonizeMPS(xData = lmm.fit$xData , dIData = lmm.fit$dIData , zData = lmm.fit$zData - lmm.fit$XData %*% lmm.fit$betahat , dIStd = dIPlot , overlapsByRegression = overlapsByRegression)
    xDataH <- tmp$xDataH 
    hrmnzdResData <- tmp$hrmnzdData 
    hrmnzdResDataEAS <- tmp$hrmnzdDataEAS    
    
  }else{
    ### round dIFit to nearest roundTo cm...
    dIFitRnd <- lmm.fit$dIData
    dIFitRnd[,1] <- round(dIFitRnd[,1] / roundTo) * roundTo
    dIFitRnd[,2] <- round(dIFitRnd[,2] / roundTo) * roundTo
  }
  
  CTmp <- VTmp <- matrix(NA , nrow(dIPlot) , length(hxModelPlot))
  EVTmp <- hxEVTmp <- nEVTmp <- matrix(NA , nrow(dIPlot) , length(hx)-1)
  n4dIPlot <- NA * numeric(nrow(dIPlot))
  
  ### for reporting, give the parameterisation from Minsany and McBratney(2007)  
  ### their 'r' = my 'a / sqrt(2*nu)'
  parsVario <- data.frame('c0' = NA * numeric(nrow(dIPlot)) , 'c1' = NA , 'r' = NA , 'nu' = NA)
  
  for(i in 1:nrow(dIPlot)){
    if(!is.null(lmm.fit$parsBTfmd)){
      dITmp <- cbind(rep(dIPlot[i,1] , length(hxModelPlot)) , rep(dIPlot[i,2] , length(hxModelPlot)))
      setupMats <- setupIAK3D(xData = cbind(0 , hxModelPlot) , dIData = dITmp , nDscPts = 0)
      tmp <- setCIAK3D(parsBTfmd = lmm.fit$parsBTfmd , modelx = lmm.fit$modelx , 
                       sdfdType_cd1 = lmm.fit$sdfdType_cd1 , sdfdType_cxd0 = lmm.fit$sdfdType_cxd0 , sdfdType_cxd1 = lmm.fit$sdfdType_cxd1 , cmeOpt = lmm.fit$cmeOpt , setupMats = setupMats)
      
      CTmp[i,] <- tmp$C[1,]
      VTmp[i,] <- CTmp[i,1] - CTmp[i,]
      
      dITmp <- cbind(rep(dIPlot[i,1] , 2) , rep(dIPlot[i,2] , 2))
      setupMats <- setupIAK3D(xData = cbind(0 , c(0, 1E-18)) , dIData = dITmp , nDscPts = 0)
      tmp <- setCIAK3D(parsBTfmd = lmm.fit$parsBTfmd , modelx = lmm.fit$modelx , 
                       sdfdType_cd1 = lmm.fit$sdfdType_cd1 , sdfdType_cxd0 = lmm.fit$sdfdType_cxd0 , sdfdType_cxd1 = lmm.fit$sdfdType_cxd1 , cmeOpt = lmm.fit$cmeOpt , setupMats = setupMats)
      
      covariancesTmp <- tmp$C[1,]
      c0Tmp <- covariancesTmp[1] - covariancesTmp[2]
      c1Tmp <- covariancesTmp[2]
      
      ### return effective parameters for each depth for the horizontal variograms...
      parsVario$c0[i] <- c0Tmp
      parsVario$c1[i] <- c1Tmp
      parsVario$r[i] <- lmm.fit$parsBTfmd$ax / sqrt(2*lmm.fit$parsBTfmd$nux)
      parsVario$nu[i] <- lmm.fit$parsBTfmd$nux
    }else{}
    
    if(spline4ExpV){
      iDataThis <- which(!is.na(hrmnzdResData[,i]))
      n4dIPlot[i] <- length(iDataThis)
      if(length(iDataThis) > 10){
        vTmp <- vario(hxBins = hxBins , xData = xDataH[iDataThis,,drop=FALSE] , zData = hrmnzdResData[iDataThis,i])
        
        EVTmp[i,] <- vTmp$vgm
        hxEVTmp[i,] <- vTmp$hxAv
        nEVTmp[i,] <- vTmp$nAv
      }else{}
      
    }else{  
      iDataThis <- which(abs(dIFitRnd[,1] - dIPlot[i,1]) < 1E-4 & abs(dIFitRnd[,2] - dIPlot[i,2]) < 1E-4)
      n4dIPlot[i] <- length(iDataThis)
      if(length(iDataThis) > 10){
        xDataThis <- lmm.fit$xData[iDataThis,]
        zDataThis <- lmm.fit$zData[iDataThis]
        resDataThis <- zDataThis - lmm.fit$XData[iDataThis,,drop=FALSE] %*% lmm.fit$betahat
        
        iU <- which(!duplicated(xDataThis))
        xDataThis <- xDataThis[iU,,drop=FALSE]
        zDataThis <- zDataThis[iU]
        resDataThis <- resDataThis[iU]
        
        vTmp <- vario(hxBins = hxBins , xData = xDataThis , zData = resDataThis)
        
        EVTmp[i,] <- vTmp$vgm
        hxEVTmp[i,] <- vTmp$hxAv
        nEVTmp[i,] <- vTmp$nAv
      }else{}
    }
  }
  
  if(!is.null(lmm.fit$parsBTfmd)){
    CTmp <- CTmp[,-1,drop=FALSE]
    VTmp <- VTmp[,-1,drop=FALSE]
    hxModelPlot <- hxModelPlot[-1]
  }else{}
  
  EVTmp[is.nan(EVTmp)] <- NA
  hxEVTmp[is.nan(hxEVTmp)] <- NA
  
  if(is.null(ylim)){ ylim <- c(0 , 1.01 * max(max(CTmp) , max(EVTmp , na.rm = TRUE))) }else{}
  
  if(noPlot){
    listRtn <- list('hxEV' = hxEVTmp , 'EV' = EVTmp , 'nEV' = nEVTmp , 'n4dIPlot' = n4dIPlot , 'ylim' = ylim , 'parsVario' = parsVario)    
    listRtn$xSplinedRes <- xDataH
    listRtn$splinedRes <- hrmnzdResData
    return(listRtn)
  }else{}
  
  colorRamp <- c('red' , 'yellow' , 'blue')
  colVec <- colorRampPalette(colorRamp)(nrow(dIPlot))
  pch <- 2
  
  plot(c() , c() , xlim = c(0 , max(hx)) , ylim = ylim , 
       xlab = paste0('Horizontal separation distance, ' , hzntlUnits) , ylab = 'Variance')
  
  for(i in 1:nrow(dIPlot)){
    if(!all(is.na(EVTmp[i,]))){
      points(hxEVTmp[i,] , EVTmp[i,] , col = colVec[i] , pch = pch)
    }else{}
  }
  
  for(i in 1:nrow(dIPlot)){
    lines(hxModelPlot , VTmp[i,] , col = colVec[i])
  }
  legTxt <- character(nrow(dIPlot))
  for (i in 1:nrow(dIPlot)){ legTxt[i] <- paste0(dIPlot[i,1] , ' - ' , dIPlot[i,2]) }
  
  legend('bottomright' , legend = legTxt , col = colVec , lty = 1 , pch = pch , title = 'Depth, m')
  
  listRtn <- list('hxEV' = hxEVTmp , 'EV' = EVTmp , 'nEV' = nEVTmp , 'n4dIPlot' = n4dIPlot , 'ylim' = ylim , 'parsVario' = parsVario)
  if(spline4ExpV){
    listRtn$xSplinedRes <- xDataH
    listRtn$splinedRes <- hrmnzdResData
  }else{}
  
  return(listRtn)
}

#####################################################
### simple plot of the vertical correlation function on point support
### (non-stationary) variances not included here. 
#####################################################
plotCord <- function(lmm.fit , hdPlot , vrtclUnits = 'm'){
  
  CTmp <- maternCov(D = hdPlot , pars = c(1 , lmm.fit$parsBTfmd$ad , lmm.fit$parsBTfmd$nud))
  
  plot(c() , c() , xlim = c(0 , max(hdPlot)) , ylim = c(0 , 1.01 * max(CTmp)) , 
       xlab = paste0('Vertical separation distance, ' , vrtclUnits) , ylab = 'Correlation')
  
  lines(hdPlot , CTmp , col = 'red')
}

############################################################################
### a color plot to show modelled covariances between different depth intervals (above x=y)
### and empirical covariances between (rounded) depth intervals (below x=y)
############################################################################
getCovs4Plot <- function(lmm.fit = NULL , dIPlot , roundTo = NULL , overlapsByRegression = TRUE){ # roundTo = 0.10 , 
  
  if(is.null(roundTo)){ spline4ExpV <- TRUE }else{ spline4ExpV <- FALSE }
  
  dIPlotMdPts <- rowMeans(dIPlot)
  
  if(!is.null(lmm.fit$parsBTfmd)){
    setupMats <- setupIAK3D(xData = cbind(0 , rep(0 , nrow(dIPlot))) , dIData = dIPlot , nDscPts = 0)
    tmp <- setCIAK3D(parsBTfmd = lmm.fit$parsBTfmd , modelx = lmm.fit$modelx , 
                     sdfdType_cd1 = lmm.fit$sdfdType_cd1 , sdfdType_cxd0 = lmm.fit$sdfdType_cxd0 , sdfdType_cxd1 = lmm.fit$sdfdType_cxd1 , cmeOpt = lmm.fit$cmeOpt , setupMats = setupMats)
    modelC <- tmp$C
  }else{
    modelC <- NULL
  }
  
  if(spline4ExpV){
    ### run a hack of mppsline funtion with residuals...
    # profIDData <- makeProfID(lmm.fit$xData)
    # profEAS <- data.frame('ID' = profIDData , 'Eastings' = lmm.fit$xData[,1]  , 'Northings' = lmm.fit$xData[,2] , 
    #                       'dU' = 100 * lmm.fit$dIData[,1] , 'dL' = 100 * lmm.fit$dIData[,2] , 'residuals' = lmm.fit$zData - lmm.fit$XData %*% lmm.fit$betahat) 
    # 
    # z.s <- mpspline.source(dfHzns = profEAS , lam = 0 , vlow = -1000 , d = t(c(0,100*max(dIPlot[,2]))))
    # nProfs <- ncol(z.s$var.1cm)
    # x.s <- matrix(NA , nProfs , 2)
    # for(i in 1:nProfs){
    #   x.s[i,] <- as.numeric(lmm.fit$xData[which(profIDData == z.s$idcol[i])[1],])
    # }
    # var.1cm <- z.s$var.1cm
# 
#     resDataAll <- matrix(NA , nProfs , nrow(dIPlot))
#     for(i in 1:nrow(dIPlot)){
#       resDataAll[,i] <- colSums(var.1cm[seq(round(dIPlot[i,1]*100) + 1 , round(dIPlot[i,2]*100)),,drop=FALSE]) / ((dIPlot[i,2]-dIPlot[i,1])*100)
#     }
    
    ### run a hack of mppsline funtion with residuals...
    tmp <- harmonizeMPS(xData = lmm.fit$xData , dIData = lmm.fit$dIData , zData = lmm.fit$zData - lmm.fit$XData %*% lmm.fit$betahat , dIStd = dIPlot , overlapsByRegression = overlapsByRegression)
    xDataH <- tmp$xDataH 
    hrmnzdResData <- tmp$hrmnzdData 
    hrmnzdResDataEAS <- tmp$hrmnzdDataEAS    
    nProfs <- nrow(xDataH)
    
    dfCovariances <- NULL
    for (i in 1:nProfs){
      iOKThis <- which(!is.na(hrmnzdResData[i,]))
      if(length(iOKThis) > 0){
        if(is.null(dfCovariances)){
          dfCovariances <- covCloud(xData = dIPlot[iOKThis,,drop=FALSE] , zData = hrmnzdResData[i,iOKThis])
        }else{
          dfCovariances <- rbind(dfCovariances , covCloud(xData = dIPlot[iOKThis,,drop=FALSE] , zData = hrmnzdResData[i,iOKThis]))
        }
      }else{}
    }
    
  }else{
    ### round dIFit to nearest roundTo cm...
    dIFitRnd <- lmm.fit$dIData
    dIFitRnd[,1] <- round(dIFitRnd[,1] / roundTo) * roundTo
    dIFitRnd[,2] <- round(dIFitRnd[,2] / roundTo) * roundTo
    
    resData <- lmm.fit$zData - lmm.fit$XData %*% lmm.fit$betahat
    iU <- which(!duplicated(lmm.fit$xData)) 
    for (i in 1:length(iU)){
      iThis <- which(lmm.fit$xData[,1] == lmm.fit$xData[iU[i],1] & lmm.fit$xData[,2] == lmm.fit$xData[iU[i],2])
      dIDataThis <- dIFitRnd[iThis,,drop=FALSE]
      resDataThis <- resData[iThis]
      if(i == 1){
        dfCovariances <- covCloud(xData = dIDataThis , zData = resDataThis)
      }else{
        dfCovariances <- rbind(dfCovariances , covCloud(xData = dIDataThis , zData = resDataThis))
      }
    }
    
  }
  
  minn4EmpC <- 10
  empiricalC <- nempiricalC <- matrix(NA , nrow(dIPlot) , nrow(dIPlot))
  for (i in 1:nrow(dIPlot)){ # for y
    for (j in 1:nrow(dIPlot)){ # for x
      ### find all the cases where these two depth intervals appear in the same profile...      
      iThis <- which((dfCovariances$x1.1 == dIPlot[i,1] & dfCovariances$x1.2 == dIPlot[i,2] & dfCovariances$x2.1 == dIPlot[j,1] & dfCovariances$x2.2 == dIPlot[j,2]) |
                       (dfCovariances$x1.1 == dIPlot[j,1] & dfCovariances$x1.2 == dIPlot[j,2] & dfCovariances$x2.1 == dIPlot[i,1] & dfCovariances$x2.2 == dIPlot[i,2]))
      if(length(iThis) >= minn4EmpC){
        empiricalC[i,j] <- mean(dfCovariances$cov[iThis])
        empiricalC[j,i] <- empiricalC[i,j]
        nempiricalC[i,j] <- length(iThis)
        nempiricalC[j,i] <- nempiricalC[i,j]
      }else{}
    }
  }
  return(list('empiricalC' = empiricalC , 'nempiricalC' = nempiricalC , 'modelC' = modelC , 'dfCovariances' = dfCovariances))
}

plotCovd <- function(lmm.fit , dIPlot , vrtclUnits = 'm' , breaksVec = NULL , addScalebar = FALSE , roundTo = NULL , overlapsByRegression = TRUE){
  
  tmp <- getCovs4Plot(lmm.fit = lmm.fit , dIPlot = dIPlot , roundTo = roundTo , overlapsByRegression = overlapsByRegression)
  empiricalC <- tmp$empiricalC 
  modelC <- tmp$modelC 
  dfCovariances <- tmp$dfCovariances
  
  if(is.null(breaksVec)){
    ncols <- 32
    maxTmp <- 1.001 * max(modelC)
    breaksVec <- seq(maxTmp / ncols , maxTmp , maxTmp / ncols)
  }else{
    ncols <- length(breaksVec)
  }  
  
  colorRamp <- c('blue' , 'yellow' , 'red')
  colVec <- colorRampPalette(colorRamp)(ncols)
  
  plotValBnds <- cbind(c(0 , breaksVec[-length(breaksVec)]) , breaksVec)
  colMtxModelC <- colMtxEmpiricalC <- matrix(NA , nrow(modelC) , ncol(modelC))
  for (i in 1:ncols){
    if(i == 1){
      iThis <- which(modelC < plotValBnds[i,2])
    }else if(i == ncols){
      iThis <- which(modelC >= plotValBnds[i,1])
    }else{    
      iThis <- which(modelC >= plotValBnds[i,1] & modelC < plotValBnds[i,2])
    }
    if(length(iThis) > 0){
      colMtxModelC[iThis] <- colVec[i]
    }else{}
    
    if(i == 1){
      iThis <- which(empiricalC < plotValBnds[i,2])
    }else if(i == ncols){
      iThis <- which(empiricalC >= plotValBnds[i,1])
    }else{    
      iThis <- which(empiricalC >= plotValBnds[i,1] & empiricalC < plotValBnds[i,2])
    }
    if(length(iThis) > 0){
      colMtxEmpiricalC[iThis] <- colVec[i]
    }else{}
  }
  
  xlim <- c(min(dIPlot[,1]) , max(dIPlot[,2]))
  ylim <- c(min(dIPlot[,1]) , max(dIPlot[,2]))
  
  if(addScalebar){
    xlim[2] <- xlim[2] + 3 * (dIPlot[1,2] - dIPlot[1,1])
  }else{}
  
  plot(c() , c() , xlim = xlim , ylim = ylim , xlab = 'Depth, m' , ylab = 'Depth, m' , asp = 1 , bty = 'n') # xaxt = 'n' , yaxt = 'n' , 
  for (i in 1:nrow(dIPlot)){ # for y
    for (j in 1:nrow(dIPlot)){ # for x
      xminThis <- dIPlot[j,1]
      xmaxThis <- dIPlot[j,2]
      yminThis <- dIPlot[i,1]
      ymaxThis <- dIPlot[i,2]
      if(i > j){
        polyxThis <- c(xminThis , xmaxThis , xmaxThis , xminThis , xminThis)
        polyyThis <- c(yminThis , yminThis , ymaxThis , ymaxThis , yminThis)
        polygon(polyxThis , polyyThis , col = colMtxModelC[i,j] , border = 'white' , lwd = 0.5)
      }else if(i == j){
        polyxThis <- c(xminThis , xmaxThis , xminThis , xminThis)
        polyyThis <- c(yminThis , ymaxThis , ymaxThis , yminThis)
        polygon(polyxThis , polyyThis , col = colMtxModelC[i,j] , border = 'white' , lwd = 0.5)
        
        polyxThis <- c(xminThis , xmaxThis , xmaxThis , xminThis)
        polyyThis <- c(yminThis , ymaxThis , yminThis , yminThis)
        polygon(polyxThis , polyyThis , col = colMtxEmpiricalC[i,j] , border = 'white' , lwd = 0.5)
      }else{        
        polyxThis <- c(xminThis , xmaxThis , xmaxThis , xminThis , xminThis)
        polyyThis <- c(yminThis , yminThis , ymaxThis , ymaxThis , yminThis)
        polygon(polyxThis , polyyThis , col = colMtxEmpiricalC[i,j] , border = 'white' , lwd = 0.5)
      }
      
    }
  }
  
  if(addScalebar){
    wThis <- dIPlot[1,2] - dIPlot[1,1]
    xminThis <- max(dIPlot[,2]) + wThis
    xmaxThis <- max(dIPlot[,2]) + 1.7 * wThis
    
    yminSB <- ylim[1] + 0.2 * (ylim[2] - ylim[1])
    ymaxSB <- ylim[1] + (1 - 0.2) * (ylim[2] - ylim[1])
    hThis <- (ymaxSB - yminSB) / ncols
    for (i in 1:ncols){
      yminThis <- yminSB + (i-1) * hThis
      ymaxThis <- yminSB + i * hThis
      polyxThis <- c(xminThis , xmaxThis , xmaxThis , xminThis , xminThis)
      polyyThis <- c(yminThis , yminThis , ymaxThis , ymaxThis , yminThis)
      polygon(polyxThis , polyyThis , col = colVec[i] , border = 'white' , lwd = 0.5)
      
      if((i - 1) %% 8 == 0){
        text(xmaxThis , yminThis , round(plotValBnds[i , 1] , digits = 2) , pos = 4)
      }else{}
    }  
    
  }else{}
  
  return(list('empiricalC' = empiricalC , 'modelC' = modelC , 'dfCovariances' = dfCovariances))
}

######################################################################
### plot components of variance as a function of depth...
######################################################################
plotVarComps <- function(lmm.fit , dPlot , xlim = NULL){
  
  if (lmm.fit$sdfdType_cd1 == -9){
    if(lmm.fit$modelx == 'nugget'){
      listComps <- c('cxd0')
    }else{
      listComps <- c('cxd0' , 'cxd1')
    }
  }else{
    if(lmm.fit$modelx == 'nugget'){
      listComps <- c('cd1' , 'cxd0')
    }else{
      listComps <- c('cd1' , 'cxd0' , 'cxd1')
    }
  }
  
  legTxt <- character(length(listComps))
  legTxt[which(listComps == 'cd1')] <- expression(italic(v[d]))
  legTxt[which(listComps == 'cxd0')] <- expression(italic(v[xd0])) 
  legTxt[which(listComps == 'cxd1')] <- expression(italic(v[xd1])) 
  
  vdPlot <- matrix(NA , length(dPlot) , length(listComps))
  for(i in 1:length(listComps)){
    vdPlot[,i] <- getVarComp(lmm.fit , dPlot , compPlot = listComps[i])
  }
  
  colVec <- character(length(listComps))
  colVec[which(listComps == 'cd1')] <- 'magenta'
  colVec[which(listComps == 'cxd0')] <- 'red'
  colVec[which(listComps == 'cxd1')] <- 'blue'
  
  if(is.null(xlim)){ xlim <- c(0 , max(vdPlot)) }else{}
  
  plot(c() , c() , xlim = xlim , ylim = c(-max(dPlot) , 0) , xlab = 'Variance' , ylab = 'Depth, m' , main = '' , yaxt = 'n')
  axis(side = 2 , at = seq(-2 , 0 , 0.5) , labels = c(2.0 , 1.5 , 1.0 , 0.5 , 0.0) , las = 2)
  
  for(i in 1:length(listComps)){
    lines(vdPlot[,i] , -dPlot , col = colVec[i])
  }
  legend('bottomright' , legend = legTxt , col = colVec , lty = 1 , title = 'Component of variance')
}


getVarComp <- function(lmm.fit , dPlot , compPlot = 'cxd1'){
  
  if(compPlot == 'cd1'){
    vTmp <- lmm.fit$parsBTfmd$cd1
    sdfdPars <- lmm.fit$parsBTfmd$sdfdPars_cd1
    sdfdType <- lmm.fit$sdfdType_cd1
  }else if(compPlot == 'cxd0'){
    vTmp <- lmm.fit$parsBTfmd$cxd0
    sdfdPars <- lmm.fit$parsBTfmd$sdfdPars_cxd0
    sdfdType <- lmm.fit$sdfdType_cxd0
  }else if(compPlot == 'cxd1'){
    vTmp <- lmm.fit$parsBTfmd$cxd1
    sdfdPars <- lmm.fit$parsBTfmd$sdfdPars_cxd1
    sdfdType <- lmm.fit$sdfdType_cxd1
  }else{
    stop('Error - enter one of cd1, cxd0 or cxd1 for compPlot!')
  }  
  
  vdTmp <- sdfd(dPlot , sdfdPars , sdfdType)
  vdTmp <- vTmp * (vdTmp ^ 2) 
  
  return(vdTmp)
}
