#-------------------------------------------------------------------------------
# BACON-test
# Multivariate outlier test written by ANDERSSON, J.. Based on Algorithm 3 in
# "BACON: blocked adaptive computationally efficient outlier nominators",
#  Billor et al (2000), p. 286
#
bacon=function(X,alpha=0.15,const=4)
{
        p=ncol(X)
        n=nrow(X)
        m=const*p
        mx=colMeans(X)
        Sx=var(X)
        d=sqrt(mahalanobis(X,center=mx,cov=Sx))
        o=order(d)
        Xs=X[o[1:m],]
        test=TRUE
        while(test)
        {
                m=colMeans(Xs)
                S=var(Xs)
                d=sqrt(mahalanobis(X,center=m,cov=S))
                h=floor((n+p+1)/2)
                r=nrow(Xs)
                chr=max(0,(h-r)/(h+r))
                cnp=1+(p+1)/(n-1)+2/(n-1-3*p)
                cnpr=chr+cnp
                crit=cnpr*qchisq(1-alpha,df=p)
                ind=d<crit
                Xs=X[ind,]
                test=r!=sum(ind)
        }
        return(data.frame(X=X,outlier=ind,dist=d))
}



#compensating for z-variables based on two-stage methods
#----- begin function two.stage
# x is a vector of input values (n_dmu x 1)
# z is a matrix with values of environmental variables (n_dmu x n_z)
# eff is a vector of unconditional efficiency scores (n_dmu x 1)
# lambda is a matrix of reference weights (n_dmu x n_dmu)
two.stage <- function(x,z,eff,lambda)
{
  #data types
  x <- as.vector(x)
  z <- as.matrix(z)
  eff <- as.vector(eff)
  lambda <- as.matrix(lambda)

  #correction based on absolute levels of z-variables
  #regression
  res.regr.abs <- lm(eff ~ z)
  #calculate final efficiency scores
  eff.corr.abs <- as.vector(eff - z%*%res.regr.abs$coefficients[2:(ncol(z)+1)])

  #correction based on NVEs "difference" method
  # AMUNDSVEEN, R.; KORDAHL, O.-P.; KVILE, H. M. & LANGSET, T.
  # SECOND STAGE ADJUSTMENT FOR FIRM HETEROGENEITY IN DEA: A NOVEL APPROACH USED IN REGULATION OF NORWEGIAN ELECTRICITY DSOS
  # Recent Developments in Data Envelopment Analysis and its Applications, 2014, 334

  #cost norm for each dmu
  x.norm <- lambda %*% x
  #norm contribution for each reference dmu
  x.norm.contrib <- lambda %*% diag(x)
  #weight for each reference dmu
  w.ref <- diag(1 / as.vector(x.norm)) %*% x.norm.contrib
  #differences versus reference dmus
  z.diff <- z - w.ref %*% z
  #regression for stage 2 based on differences
  res.regr.NVE <- lm(eff ~ z.diff, data = )  #r_normal,
  #calculate final efficiency scores based on updated z-differences
  eff.corr.NVE <- as.vector(eff - z.diff%*%res.regr.NVE$coefficients[2:(ncol(z)+1)])

  res <- list(eff.corr.abs=eff.corr.abs,eff.corr.NVE=eff.corr.NVE,regr.coeff.abs=res.regr.abs$coefficients,regr.coeff.NVE=res.regr.NVE$coefficients)

  return(res)
}

#----------------------------------------------------------------------------------------------
#----------------------------------------------------------------------------------------------

# x = x.snitt.d
# z = z=cbind(d_tilDEA$dr_hsjordand, d_tilDEA$dr_s4, d_tilDEA$dr_Geo1, d_tilDEA$dr_Geo2, d_tilDEA$dr_Geo3)
# y = y.snitt.d
# eff = d_tilDEA$d_bs_correst_e3
# lambda = d_lambda.snitt
# id = names(x)
# id.out = as.character(d_separat_dmuer)
# coeff = res.Zvar1$regr.coeff.NVE
#----------------------------------------------------------------------------------------------


#Create Geo variables used for estimating coefficients


z.est = function (geovar.in, restricted.obs = NULL)
        {
        geovar.in = as.matrix(geovar.in)
        pca = (prcomp(geovar.in, scale. = TRUE))
        geovar.ut = predict(pca, newdata = restricted.obs)[,1]*-1
        return(geovar.ut)
        }


#----------------------------------------------------------------------------------------------
#NY VERSJON TILPASSET NVE
# x is a vector of input values (n_dmu dx 1)
# z is a matrix with values of environmental variables (n_dmu x n_z)
# eff is a vector of unconditional efficiency scores (n_dmu x 1)
# lambda is a matrix of reference weights (n_dmu x n_dmu)
Zvar1 <- function(x,z,eff,lambda,id,id.out)
        {
        #data types
        x <- as.vector(x)
        z <- as.matrix(z)
        lambda <- as.matrix(lambda)
        names(x) = id
        rownames(z) = id


        #correction based on NVEs "difference" method
        # AMUNDSVEEN, R.; KORDAHL, O.-P.; KVILE, H. M. & LANGSET, T.
        # SECOND STAGE ADJUSTMENT FOR FIRM HETEROGENEITY IN DEA: A NOVEL APPROACH USED IN REGULATION OF NORWEGIAN ELECTRICITY DSOS
        # Recent Developments in Data Envelopment Analysis and its Applications, 2014, 334

        #cost norm for each dmu
        x.norm = lambda %*% x
        #norm contribution for each reference dmu  - kostnadsbidrag
        x.norm.contrib = lambda %*% diag(x)
        #weight for each reference dmu  - normkostandel
        w.ref = x.norm.contrib / rowSums(x.norm.contrib)
        #differences versus reference dmus
        z.diff = z - w.ref %*% z
        #Only companys defining the technology included in regression
        tech = setdiff(id, id.out)
        z.diff = z.diff[tech, ]
        #outlier-test
        outlier.X <- bacon(cbind(eff, z.diff), alpha = 0.15, const=4)
        id.out = union(id.out,rownames(outlier.X[which(!outlier.X$outlier),]))
        #regression for stage 2 based on differences
        res.regr.NVE <- lm(eff ~ z.diff,subset = setdiff(id,id.out))
        coeff=res.regr.NVE$coefficients
        names(coeff)=c("constant",colnames(z.diff))

        res <- list(coeff=coeff,z.diff=z.diff, id.out=id.out, res.regr.NVE = res.regr.NVE)
        return(res)
        }
#----------------------------------------------------------------------------------------------
#calculate final efficiency scores based on updated z-differences

Zvar2 <- function(x,eff,id,coeff,z,lambda)
        {
        #data types
        x <- as.vector(x)
        z <- as.matrix(z)
        eff <- as.vector(eff)
        lambda <- as.matrix(lambda)
        names(x) = id
        rownames(z) = id
        names(eff) = id

        #cost norm for each dmu
        x.norm = lambda %*% x
        #norm contribution for each reference dmu
        x.norm.contrib = lambda %*% diag(x)
        #weight for each reference dmu
        w.ref = x.norm.contrib / rowSums(x.norm.contrib)
        #differences versus reference dmus
        z.diff = z - w.ref %*% z

        #Adjusts efficiency score
        eff.corr <- as.vector(eff - z.diff%*%coeff[2:(ncol(z)+1)])

        res <- list(eff.corr=eff.corr,z.diff=z.diff, cost.norm.contribution = x.norm.contrib, cost.norm.share = w.ref)
        return(res)
        }


#----------------------------------------------------------------------------------------------


#calibrating efficiency scores
#----- begin function calibrate
calibrate <- function(eff,totex,weight=NULL)
  {
  #eff, totex, and weight are vectors with lengths equal to the number of DMUs.
  eff = as.vector(eff)
  totex = as.vector(totex)
  if(!is.null(weight)) weight = as.vector(weight)

  #The purpose of the calibration is to ensure that the averagely efficient company a return equal to the reference rate of return.
  #The capital weighted calibration also corrects (somewhat) for the age bias caused by using book values as basis for the capital costs.
  #Other calibration variants, e.g., a multiplicative formula, have been used previously.
  #Setting weight=NULL means that the multiplicative calibration variant will be used.
  #See Bj�rndal, Bj�rndal and Fange (2010).

  industry.avg <- sum(totex*eff)/sum(totex)
  calibration.amount <- sum(totex)-sum(totex*eff)
  if(is.null(weight))
    {
    #multiplicative calibration, i.e., scaling the efficiency scores
    eff.cal <- eff / industry.avg
    }else
    {
    #additive calibration, i.e., adding a constant to all efficiency scores
    #note that weight = totex is equivalent to adding (1-industry.avg) to all the efficiency scores
    weight <- weight / sum(weight)
    eff.cal <- eff + calibration.amount*weight/totex
    }

  return(list(eff.cal=eff.cal,industry.avg=industry.avg,calibration.amount=calibration.amount))
  }
#------------------------------------------------------------------------------

NVE_cal = function(eff, cost_base, RAB)
{
        eff = as.vector(eff)
        cost_base = as.matrix(cost_base)
        RAB = as.matrix(RAB)
        #eff is the Geo-adjusted efficency-scores
        #cost_base is an "estimated" cost base, estimated from future CPI-values
        #RAB is the regulatory asset base
        
        cost_norm = eff*cost_base
        tot.cost_base = sum(cost_base)
        tot.cost_norm = sum(cost_norm)
        tot.RAB = sum(RAB)
        
        cost_norm.calRAB = cost_norm + (tot.cost_base - tot.cost_norm) * (RAB/tot.RAB)
        cost_norm.supp =  (tot.cost_base - tot.cost_norm) * (RAB/tot.RAB)
        
        eff.cal = cost_norm.calRAB / cost_base
        ind.av.eff = tot.cost_norm/tot.cost_base
        
        res = list(eff.cal=as.vector(eff.cal), cost_norm=as.vector(cost_norm), cost_norm.supp=as.vector(cost_norm.supp),
                   tot.cost_base=tot.cost_base,tot.RAB=tot.RAB, ind.av.eff=ind.av.eff,
                   cost_norm.calRAB=as.vector(cost_norm.calRAB))

}
#---------------------------------------------------------------------------------------------------------------------
#Function for comparing dataframes or groups from Cookbook for R
#Written by knitr and Jekyll. If you find any errors, please email winston@stdout.org
#http://www.cookbook-r.com/Manipulating_data/Comparing_data_frames/

dupsBetweenGroups <- function (df, idcol) {
        # df: the data frame
        # idcol: the column which identifies the group each row belongs to
        
        # Get the data columns to use for finding matches
        datacols <- setdiff(names(df), idcol)
        
        # Sort by idcol, then datacols. Save order so we can undo the sorting later.
        sortorder <- do.call(order, df)
        df <- df[sortorder,]
        
        # Find duplicates within each id group (first copy not marked)
        dupWithin <- duplicated(df)
        
        # With duplicates within each group filtered out, find duplicates between groups. 
        # Need to scan up and down with duplicated() because first copy is not marked.
        dupBetween = rep(NA, nrow(df))
        dupBetween[!dupWithin] <- duplicated(df[!dupWithin,datacols])
        dupBetween[!dupWithin] <- duplicated(df[!dupWithin,datacols], fromLast=TRUE) | dupBetween[!dupWithin]
        
        # ============= Replace NA's with previous non-NA value ==============
        # This is why we sorted earlier - it was necessary to do this part efficiently
        
        # Get indexes of non-NA's
        goodIdx <- !is.na(dupBetween)
        
        # These are the non-NA values from x only
        # Add a leading NA for later use when we index into this vector
        goodVals <- c(NA, dupBetween[goodIdx])
        
        # Fill the indices of the output vector with the indices pulled from
        # these offsets of goodVals. Add 1 to avoid indexing to zero.
        fillIdx <- cumsum(goodIdx)+1
        
        # The original vector, now with gaps filled
        dupBetween <- goodVals[fillIdx]
        
        # Undo the original sort
        dupBetween[sortorder] <- dupBetween
        
        # Return the vector of which entries are duplicated across groups
        return(dupBetween)
}
#--------------------------------------------------------------------------------------------------------------------

ToRho = function(x, lambda){

        x <- as.vector(x)
        lambda <- as.matrix(lambda)

        # cost norm for each dmu
        x.norm <- lambda %*% x
        ids = colnames(lambda)
        # norm contribution for each reference dmu
        x.norm.contrib <- lambda %*% diag(x)
        # Set name of columns equal to rows ## NEEDS QA
        colnames(x.norm.contrib) = colnames(lambda)
        # Keep only columns for peers
        x.norm.contrib1 = x.norm.contrib[, colSums(x.norm.contrib) > 0]
        # Contribution to normcost pr peer in total
        norm.pr.peer = colSums(x.norm.contrib1)
        # Total norm cost
        total.norm = sum(norm.pr.peer)
        # Torgersens rho
        Torg.Rho = as.matrix(norm.pr.peer / total.norm)
        colnames(Torg.Rho) = "Torg.Rho"
        
        res <- list(Torg.Rho = Torg.Rho)
}

#---------------------------------------------------------------------------------------------------------------------

#Information on relative importance of each peer pr dmu


PeerI <- function(x,eff,id,lambda)
{
        #data types
        x <- as.vector(x)
        eff <- as.vector(eff)
        lambda <- as.matrix(lambda)
        names(x) = id
      
        
        #cost norm for each dmu
        x.norm = lambda %*% x
        #norm contribution for each reference dmu
        x.norm.contrib = lambda %*% diag(x)
        #weight for each reference dmu
        w.ref = x.norm.contrib / rowSums(x.norm.contrib)

        colnames(x.norm.contrib) = colnames(lambda)
        colnames(w.ref) = colnames(lambda)
        
        res <- list(cost.norm = x.norm, cost.norm.contribution = x.norm.contrib, cost.norm.share = w.ref)
        return(res)
}


#---------------------------------------------------------------------------------------------------------------------
merge_NVE = function(comps, new.org, new.id, new.name, sum_variables, ldz_weighted.var, rdz_weighted.var, merge.mean, df){

comps = as.vector(comps)
new.org = as.numeric(new.org)
new.id = as.numeric(new.id)
new.name = as.character(new.name)
df = data.frame(df)



df$ldz_n.mgc_sum = df$ldz_mgc # Number of map grid cells for "sum"-vector
df$rdz_n.mgc_sum = df$rdz_mgc


# Create data frame with observations for merging companies
md = filter(df, df$orgn %in% comps)

# Create data frame with sum of variables in harm.var_sum, for merging companies
mds =   as.data.frame(md %>%
                              group_by(y) %>%
                              summarise_at(.vars = c(sum_variables), funs(sum)))

mds$orgn = new.org
mds$id = new.id
mds$id.y = as.numeric(paste(mds$id, mds$y, sep = ""))

comp.info = c("orgn", "y", "id", "id.y")

ld_mdw = select(md, one_of(ldz_weighted.var))
ld_mdw$mutipl.col = ld_mdw$ldz_mgc
ld_mdw = as.data.frame(bind_cols(ld_mdw, select(md, one_of(comp.info))))
ld_mdw[ldz_weighted.var] = ld_mdw[ldz_weighted.var] * ld_mdw$mutipl.col

ld_mdw.fm = as.data.frame(ld_mdw %>%
                                  group_by(y) %>%
                                  summarise_at(.vars = c(ldz_harm.var_gc), funs(sum)))



ld_mdw.fm$id = new.id
ld_mdw.fm$id.y = as.numeric(paste(ld_mdw.fm$id, ld_mdw.fm$y, sep = ""))
ld_mdw.fm$id = NULL
ld_mdw.fm$y = NULL

mds = inner_join(mds, ld_mdw.fm, by = "id.y")
mds[ldz_harm.var_gc] = mds[ldz_harm.var_gc] / mds$ldz_n.mgc_sum



rd_mdw = select(md, one_of(rdz_harm.var_gc))
rd_mdw$mutipl.col = rd_mdw$rdz_mgc
rd_mdw = as.data.frame(bind_cols(rd_mdw, select(md, one_of(comp.info))))
rd_mdw[rdz_harm.var_gc] = rd_mdw[rdz_harm.var_gc] * rd_mdw$mutipl.col

rd_mdw.fm = as.data.frame(rd_mdw %>%
                                  group_by(y) %>%
                                  summarise_at(.vars = c(rdz_harm.var_gc), funs(sum)))


rd_mdw.fm$id = new.id
rd_mdw.fm$id.y = as.numeric(paste(rd_mdw.fm$id, rd_mdw.fm$y, sep = ""))
rd_mdw.fm$id = NULL
rd_mdw.fm$y = NULL

mds = inner_join(mds, rd_mdw.fm, by = "id.y")
mds[rdz_harm.var_gc] = mds[rdz_harm.var_gc] / mds$rdz_n.mgc_sum
mds$comp = as.character(new.name)
mds$name = mds$comp

mds$ap.t_2 = (md %>%
                      group_by(y) %>%
                      summarise_at(.vars = c(merge.pr), funs(mean)))$ap.t_2

mds$ldz_n.mgc_sum = NULL
mds$rdz_n.mgc_sum = NULL

res <- list(mds = mds)

}
