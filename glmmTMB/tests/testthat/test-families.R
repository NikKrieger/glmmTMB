## test more exotic familes/model types

stopifnot(require("testthat"),
          require("glmmTMB"))

simfun0 <- function(beta=c(2,1),
                   sd.re=5,
                   ngrp=10,nobs=200,
                   invlink=exp) {
    x <- rnorm(nobs)
    f <- factor(rep(1:ngrp,nobs/ngrp))
    u <- rnorm(ngrp,sd=sd.re)
    eta <- beta[1]+beta[2]*x+u[f]
    mu <- invlink(eta)
    return(data.frame(x,f,mu))
}

test_that("binomial", {
    load(system.file("testdata","radinger_dat.RData",package="lme4"))
    radinger_dat <<- radinger_dat ## global assignment for testthat
    mod1 <<- glmmTMB(presabs~predictor+(1|species),family=binomial,
                    radinger_dat)
    mod2 <<- update(mod1,as.logical(presabs)~.)
    expect_equal(predict(mod1),predict(mod2))

    ## Compare 2-column and prop/size specification
    dd <- data.frame(success=1:10, failure=11:20)
    dd$size <- rowSums(dd)
    dd$prop <- local( success / size, dd)
    mod4 <- glmmTMB(cbind(success,failure)~1,family=binomial,data=dd)
    mod5 <- glmmTMB(prop~1,weights=size,family=binomial,data=dd)
    expect_equal( logLik(mod4)     , logLik(mod5) )
    expect_equal( fixef(mod4)$cond , fixef(mod5)$cond )

    ## Now with extra weights
    dd$w <- 2
    mod6 <- glmmTMB(cbind(success,failure)~1,family=binomial,data=dd,weights=w)
    mod7 <- glmmTMB(prop~1,weights=size*w,family=binomial,data=dd)
    mod6.glm <- glm(cbind(success,failure)~1,family=binomial,data=dd,weights=w)
    mod7.glm <- glm(prop~1,weights=size*w,family=binomial,data=dd)
    expect_equal( logLik(mod6)[[1]]     , logLik(mod6.glm)[[1]] )
    expect_equal( logLik(mod7)[[1]]     , logLik(mod7.glm)[[1]] )
    expect_equal( fixef(mod6)$cond , fixef(mod7)$cond )

    ## Test TRUE/FALSE specification
    x <- c(TRUE, TRUE, FALSE)
    dx <- data.frame(x)
    m1 <- glmmTMB(x~1, family=binomial(), data=dx)
    m2 <- glm    (x~1, family=binomial(), data=dx)
    expect_equal(
        as.numeric(logLik(m1)),
        as.numeric(logLik(m2))
    )
    expect_equal(
        as.numeric(unlist(fixef(m1))),
        as.numeric(coef(m2))
    )

    ## Mis-specifications
    prop <- c(.1, .2, .3)  ## weights=1 => prop * weights non integers
    expect_warning( glmmTMB(prop~1, family=binomial()) )   ## Warning as glm
    x <- c(1, 2, 3)        ## weights=1 => x > weights !
    expect_error  ( glmmTMB(x~1, family=binomial(),
                            data = data.frame(x)))      ## Error as glm

})

## check for negative values
test_that("detect negative values in two-column binomial response", {
    x <- matrix(c(-1, 1, 2, 2, 3, 4), nrow = 3)
    expect_error(glmmTMB(x~1, family=binomial(), data = NULL),
                 "negative values not allowed")
})

count_dists <-c("poisson", "genpois", "compois",
                "truncated_genpois",
                "nbinom1", "nbinom2",
                "truncated_nbinom1",
                "truncated_nbinom2"
                )

binom_dists <- c("binomial", "betabinomial")

test_that("count distributions", {
    dd <- data.frame(y=c(0.5, rep(1:4, c(9, 2, 2, 2))))
    for (f in count_dists) {
        expect_warning(glmmTMB(y~1, data=dd, family=f), "non-integer")
    }
})

test_that("binom-type distributions", {
    dd <- data.frame(y=c(0.5, rep(1:4, c(9, 2, 2, 2)))/10)
    for (f in binom_dists) {
        expect_warning(glmmTMB(y~1,
                               weights = rep(10, nrow(dd)),
                               data=dd, family=f), "non-integer")
    }
})



test_that("beta", {
  skip_on_cran()
    set.seed(101)
    nobs <- 200; eps <- 0.001; phi <- 0.1
    dd0 <- simfun0(nobs=nobs,sd.re=1,invlink=plogis)
    y <- with(dd0,rbeta(nobs,shape1=mu/phi,shape2=(1-mu)/phi))
    dd <<- data.frame(dd0,y=pmin(1-eps,pmax(eps,y)))
    m1 <- glmmTMB(y~x+(1|f),family=beta_family(),
                  data=dd)
    expect_equal(fixef(m1)[[1]],
                 structure(c(1.98250567574413, 0.843382531038295),
                           .Names = c("(Intercept)", "x")),
                 tol=1e-5)
    expect_equal(c(VarCorr(m1)[[1]][[1]]),
                 0.433230926800709, tol=1e-5)
    ## allow family="beta", but with warning
    expect_warning(m2 <- glmmTMB(y~x+(1|f),family="beta",
                  data=dd),"please use")
    expect_equal(coef(summary(m1)),coef(summary(m2)))

 })

test_that("nbinom", {
    skip_on_cran()
    nobs <- 200; phi <- 0.1
    set.seed(101)
    dd0 <- simfun0(nobs=nobs)
    ## global assignment for testthat (??)
    dd <- data.frame(dd0,y=rnbinom(nobs,size=phi,mu=dd0$mu))
    m1 <- glmmTMB(y~x+(1|f),family=nbinom2(),
                  data=dd)
    expect_equal(fixef(m1)[[1]],
                 structure(c(2.09866748794435, 1.12703589660625),
                           .Names = c("(Intercept)", "x")),
                 tolerance = 1e-5)
    expect_equal(c(VarCorr(m1)[[1]][[1]]),
                  9.54680210862774, tolerance = 1e-5)
    expect_equal(sigma(m1),0.09922738,tolerance = 1e-5)
    expect_equal(head(residuals(m1, type = "deviance"),2),
                 c(`1` = -0.806418177063906, `2` = -0.312895476230701),
                 tolerance = 1e-5)
    
     ## nbinom1
     ## to simulate, back-calculate shape parameters for NB2 ...
     nbphi <- 2
     nbvar <- nbphi*dd0$mu  ## n.b. actual model is (1+phi)*var,
                        ## so estimate of phi is approx. 1
     ## V = mu*(1+mu/k) -> mu/k = V/mu-1 -> k = mu/(V/mu-1)
     k <- with(dd0,mu/(nbvar/mu - 1))
     y <- rnbinom(nobs,size=k,mu=dd$mu)
     dd <- data.frame(dd0,y=y) ## global assignment for testthat
     m1 <- glmmTMB(y~x+(1|f),family=nbinom1(),
                   data=dd)
     expect_equal(c(unname(c(fixef(m1)[[1]])),
                    c(VarCorr(m1)[[1]][[1]]),
                    sigma(m1)),
       c(1.93154240357181, 0.992776302432081,
         16.447888398429, 1.00770603513152),
       tolerance = 1e-5)
    expect_equal(head(residuals(m1, type = "deviance"),2),
                 c(`1` = 0.966425183534698, `2` = -0.213960044837981),
                 tolerance = 1e-5)

    ## identity link: GH #20
    x <- 1:100; m <- 2; b <- 100
    y <- m*x+b
    set.seed(101)
    dat <<- data.frame(obs=rnbinom(length(y), mu=y, size=5), x=x)
    ## with(dat, plot(x, obs))
    ## coef(mod1 <- MASS::glm.nb(obs~x,link="identity",dat))
    expect_equal(fixef(glmmTMB(obs~x, family=nbinom2(link="identity"), dat)),
       structure(list(cond = structure(c(115.092240041138, 1.74390840106971),
       .Names = c("(Intercept)", "x")), zi = numeric(0),
       disp = structure(1.71242627201796, .Names = "(Intercept)")),
       .Names = c("cond", "zi", "disp"), class = "fixef.glmmTMB"))


    ## segfault (GH #248)
    dd <- data.frame(success=1:10,failure=10)
    expect_error(glmmTMB(cbind(success,failure)~1,family=nbinom2,data=dd),
                 "matrix-valued responses are not allowed")
 })

test_that("dbetabinom", {
    skip_on_cran()
    set.seed(101)
    nobs <- 200; eps <- 0.001; phi <- 0.1
    dd0 <- simfun0(nobs=nobs,sd.re=1,invlink=plogis)
    p <- with(dd0,rbeta(nobs,shape1=mu/phi,shape2=(1-mu)/phi))
    p <- pmin(1-eps,pmax(p,eps))
    b <- rbinom(nobs,size=5,prob=p)
    dd <<- data.frame(dd0,y=b,N=5)
    m1 <- glmmTMB(y/N~x+(1|f),
                  weights=N,
                  family=betabinomial(),
                  data=dd)
    expect_equal(c(unname(c(fixef(m1)[[1]])),
                   c(VarCorr(m1)[[1]][[1]]),
                   sigma(m1)),
                 c(2.1482114,1.0574946,0.7016553,8.3768711),
                 tolerance=1e-5)
    ## Two-column specification
    m2 <- glmmTMB(cbind(y, N-y) ~ x + (1|f),
                  family=betabinomial(),
                  data=dd)
    expect_identical(c(m1$fit), c(m2$fit)) ## drop time attribute
    ## Rolf Turner example:
    X <- readRDS(system.file("test_data","turner_bb.rds",package="glmmTMB"))
    fmla <- cbind(Dead, Alive) ~ (Trt + 0)/Dose + (Dose | Rep)
    ## baseline (binomial, not betabinomial)
    fit0  <- glmmTMB(fmla, data = X, family = binomial(link = "cloglog"),
                     dispformula = ~1)
    skip_on_cran()
    ## fails ATLAS tests with failure in inner optimization
    ## loop ("gradient function must return a numeric vector of length 16")
    fit1  <-  suppressWarnings(
        ## NaN function evaluation;
        ## non-pos-def Hessian;
        ## false convergence warning from nlminb
        glmmTMB(fmla, data = X, family = betabinomial(link = "cloglog"),
                dispformula = ~1)
    )
    fit1_glmmA <- readRDS(system.file("test_data","turner_bb_GLMMadaptive.rds",
                                      package="glmmTMB"))
    suppressWarnings(
        fit2  <- glmmTMB(fmla, data = X,
                         family = betabinomial(link = "cloglog"),
                         dispformula = ~1,
                         start=list(beta=fixef(fit0)$cond))
        ## non-pos-def Hessian warning
        ## diagnose() suggests a singular fit
        ## but fixed effects actually look OK
    )
    ff1 <- fixef(fit1)$cond
    ff2 <- fixef(fit2)$cond

    ## conclusions:
    ## (1) glmmTMB fit from initial starting vals is bad
    ## (2) glmmTMB fit from restart is OK (for fixed effects)
    ## (3) GLMMadaptive matches OK **but not** for nAGQ=1 (which _should_
    ##     fit) --
    np <- length(ff1)
    ff_GA <- fit1_glmmA[1:np,ncol(fit1_glmmA)]
    expect_equal(ff_GA, ff2, tolerance=0.05)

    if (FALSE) {
        ## graphical exploration ...
        cc <- cbind(ff1,ff2,fit1_glmmA[1:np,])
        matplot(cc,type="b")
        ## plot diffs between glmmTMB fit and GLMMadaptive for nAGQ>1
        adiff <- sweep(fit1_glmmA[1:np,-1],1,ff2,"-")
        matplot(adiff, type="b",
                ylab="diff from glmmTMB")
    }
})

test_that("truncated", {
    skip_on_cran()
    ## Poisson
    set.seed(101)
    z_tp <<- rpois(1000,lambda=exp(1))
    z_tp <<- z_tp[z_tp>0]
    if (FALSE) {
        ## n.b.: keep library() calls commented out, they may
        ##   trigger CRAN complaints
        ## library(glmmADMB)
        g0_tp <- glmmadmb(z_tp~1,family="truncpoiss",link="log")
        fixef(g0) ## 0.9778591
    }
    g1_tp <- glmmTMB(z_tp~1,family=truncated_poisson(),
                  data=data.frame(z_tp))
    expect_equal(unname(fixef(g1_tp)[[1]]),0.9778593,tolerance = 1e-5)
    ## Truncated poisson with zeros => invalid:
    num_zeros <- 10
    z_tp0 <<- c(rep(0, num_zeros), z_tp)
    expect_error(g1_tp0 <- glmmTMB(z_tp0~1,family=truncated_poisson(),
                      data=data.frame(z_tp0)))
    ## Truncated poisson with zeros and zero-inflation:
    g1_tp0 <- glmmTMB(z_tp0~1,family=truncated_poisson(),
                      ziformula=~1,
                      data=data.frame(z_tp0))
    expect_equal( plogis(as.numeric(fixef(g1_tp0)$zi)), num_zeros/length(z_tp0), tolerance = 1e-7 ) ## Test zero-prob
    expect_equal(fixef(g1_tp0)$cond,  fixef(g1_tp)$cond, tolerance = 1e-6) ## Test conditional model
    ## nbinom2
    set.seed(101)
    z_nb <<- rnbinom(1000,size=2,mu=exp(2))
    z_nb <<- z_nb[z_nb>0]
    if (FALSE) {
        ## library(glmmADMB)
        g0_nb2 <- glmmadmb(z_nb~1,family="truncnbinom",link="log")
        fixef(g0_nb2) ## 1.980207
        g0_nb2$alpha ## 1.893
    }
    g1_nb2 <- glmmTMB(z_nb~1,family=truncated_nbinom2(),
            data=data.frame(z_nb))
    expect_equal(c(unname(fixef(g1_nb2)[[1]]),sigma(g1_nb2)),
                 c(1.980207,1.892970),tolerance = 1e-5)
    ## Truncated nbinom2 with zeros => invalid:
    num_zeros <- 10
    z_nb0 <<- c(rep(0, num_zeros), z_nb)
    expect_error(g1_nb0 <- glmmTMB(z_nb0~1,family=truncated_nbinom2(),
                      data=data.frame(z_nb0)))
    ## Truncated nbinom2 with zeros and zero-inflation:
    g1_nb0 <- glmmTMB(z_nb0~1,family=truncated_nbinom2(),
                      ziformula=~1,
                      data=data.frame(z_nb0))
    expect_equal( plogis(as.numeric(fixef(g1_nb0)$zi)), num_zeros/length(z_nb0), tolerance = 1e-7 ) ## Test zero-prob
    expect_equal(fixef(g1_nb0)$cond, fixef(g1_nb2)$cond, tolerance = 1e-6) ## Test conditional model
    ## nbinom1: constant mean, so just a reparameterization of
    ##     nbinom2 (should have the same likelihood)
    ## phi=(1+mu/k)=1+exp(2)/2 = 4.69
    if (FALSE) {
        ## library(glmmADMB)
        g0_nb1 <- glmmadmb(z_nb~1,family="truncnbinom1",link="log")
        fixef(g0_nb1) ## 2.00112
        g0_nb1$alpha ## 3.784
    }
    g1_nb1 <- glmmTMB(z_nb~1,family=truncated_nbinom1(),
            data=data.frame(z_nb))
    expect_equal(c(unname(fixef(g1_nb1)[[1]]),sigma(g1_nb1)),
                 c(1.980207,3.826909),tolerance = 1e-5)
    ## Truncated nbinom1 with zeros => invalid:
    expect_error(g1_nb0 <- glmmTMB(z_nb0~1,family=truncated_nbinom1(),
                      data=data.frame(z_nb0)))
    ## Truncated nbinom2 with zeros and zero-inflation:
    g1_nb0 <- glmmTMB(z_nb0~1,family=truncated_nbinom1(),
                      ziformula=~1,
                      data=data.frame(z_nb0))
    expect_equal( plogis(as.numeric(fixef(g1_nb0)$zi)), num_zeros/length(z_nb0), tolerance = 1e-7 ) ## Test zero-prob
    expect_equal(fixef(g1_nb0)$cond, fixef(g1_nb1)$cond, tolerance = 1e-6) ## Test conditional model
})

##Genpois
test_that("truncated_genpois",{
  skip_on_cran()
    tgp1 <<- glmmTMB(z_nb ~1, data=data.frame(z_nb), family=truncated_genpois())
    tgpdat <<- data.frame(y=simulate(tgp1)[,1])
    tgp2 <<- glmmTMB(y ~1, tgpdat, family=truncated_genpois())
    expect_equal(sigma(tgp1), sigma(tgp2), tolerance = 1e-1)
    expect_equal(fixef(tgp1)$cond[1], fixef(tgp2)$cond[1], tolerance = 1e-2)
    cc <- confint(tgp2, full=TRUE)
    expect_lt(cc["sigma", "2.5 %"], sigma(tgp1))
    expect_lt(sigma(tgp1), cc["sigma", "97.5 %"])
    expect_lt(cc["cond.(Intercept)", "2.5 %"], unname(fixef(tgp1)$cond[1]))
    expect_lt(unname(fixef(tgp1)$cond[1]), cc["cond.(Intercept)", "97.5 %"])
})


##Compois
test_that("truncated_compois",{
    skip_on_cran()
	cmpdat <<- data.frame(f=factor(rep(c('a','b'), 10)),
	 			y=c(15,5,20,7,19,7,19,7,19,6,19,10,20,8,21,8,22,7,20,8))
	tcmp1 <<- glmmTMB(y~f, cmpdat, family= truncated_compois())
	expect_equal(unname(fixef(tcmp1)$cond), c(2.9652730653, -0.9773987194), tolerance = 1e-6)
	expect_equal(sigma(tcmp1), 0.1833339, tolerance = 1e-6)
	expect_equal(predict(tcmp1,type="response")[1:2], c(19.4, 7.3), tolerance = 1e-6)
})

test_that("compois", {
    skip_on_cran()
#	cmpdat <<- data.frame(f=factor(rep(c('a','b'), 10)),
#	 			y=c(15,5,20,7,19,7,19,7,19,6,19,10,20,8,21,8,22,7,20,8))
	cmp1 <<- glmmTMB(y~f, cmpdat, family=compois())
	expect_equal(unname(fixef(cmp1)$cond), c(2.9652730653, -0.9773987194), tolerance = 1e-6)
	expect_equal(sigma(cmp1), 0.1833339, tolerance = 1e-6)
	expect_equal(predict(cmp1,type="response")[1:2], c(19.4, 7.3), tolerance = 1e-6)
})

test_that("genpois", {
    skip_on_cran()
	gendat <<- data.frame(y=c(11,10,9,10,9,8,11,7,9,9,9,8,11,10,11,9,10,7,13,9))
	gen1 <<- glmmTMB(y~1, family=genpois(), gendat)
	expect_equal(unname(fixef(gen1)$cond), 2.251292, tolerance = 1e-6)
	expect_equal(sigma(gen1), 0.235309, tolerance = 1e-6)
})

test_that("tweedie", {
    skip_on_cran()
    ## Boiled down tweedie:::rtweedie :
    rtweedie <- function (n, xi = power, mu, phi, power = NULL)
    {
        mu <- array(dim = n, mu)
        if ((power > 1) & (power < 2)) {
            rt <- array(dim = n, NA)
            lambda <- mu^(2 - power)/(phi * (2 - power))
            alpha <- (2 - power)/(1 - power)
            gam <- phi * (power - 1) * mu^(power - 1)
            N <- rpois(n, lambda = lambda)
            for (i in (1:n)) {
                rt[i] <- sum(rgamma(N[i], shape = -alpha, scale = gam[i]))
            }
        } else stop()
        as.vector(rt)
    }
    ## Simulation experiment
    nobs <- 2000; mu <- 4; phi <- 2; p <- 1.7
    set.seed(101)
    y <- rtweedie(nobs, mu=mu, phi=phi, power=p)
    twm <- glmmTMB(y ~ 1, family=tweedie(), data = NULL)
    ## Check mu
    expect_equal(unname( exp(fixef(twm)$cond) ),
                 mu,
                 tolerance = .1)
    ## Check phi
    expect_equal(unname( exp(fixef(twm)$disp) ),
                 phi,
                 tolerance = .1)
    ## Check power
    expect_equal(unname( plogis(twm$fit$par["psi"]) + 1 ),
                 p,
                 tolerance = .01)
    ## Check internal rtweedie used by simulate
    y2 <- c(simulate(twm)[,1],simulate(twm)[,1])
    twm2 <- glmmTMB(y2 ~ 1, family=tweedie(), data = NULL)
    expect_equal(fixef(twm)$cond, fixef(twm2)$cond, tolerance = 1e-1)
    expect_equal(sigma(twm), sigma(twm2), tolerance = 1e-1)
    expect_equal(ranef(twm),
                 structure(list(cond = list(), zi = list(), disp = list()), class = "ranef.glmmTMB"))
})

test_that("gaussian_sqrt", {
    set.seed(101)
    nobs <- 200
    dd0_sqrt <- simfun0(nobs=nobs,sd.re=1,invlink=function(x) x^2)
    dd0_sqrt$y <- rnorm(nobs,mean=dd0_sqrt$mu,sd=0.1)
    g1 <- glmmTMB(y~x+(1|f), family=gaussian(link="sqrt"),
                  data=dd0_sqrt)
    expect_equal(fixef(g1),
                 structure(list(cond = c(`(Intercept)` = 2.03810165917618, x = 1.00241002916226
                                         ), zi = numeric(0), disp = c(`(Intercept)` = -2.341751)),
                           class = "fixef.glmmTMB"),
                 tolerance = 1e-6)
})

test_that("link function info available", {
    fam1 <- c("poisson","nbinom1","nbinom2","compois")
    fam2 <- c("binomial","beta_family","betabinomial","tweedie")
    for (f in c(fam1,paste0("truncated_",fam1),fam2)) {
        ## print(f)
        expect_true("linkinv" %in% names(get(f)()))
    }
})

d.AD <- data.frame(counts=c(18,17,15,20,10,20,25,13,12),
                   outcome=gl(3,1,9),
                   treatment=gl(3,3))
glm.D93 <- glmmTMB(counts ~ outcome + treatment, family = poisson(), data=d.AD)
glm.D93C <- glmmTMB(counts ~ outcome + treatment, family = "poisson", data=d.AD)

test_that("link info added to family", {
    expect_warning(glm.D93B <- glmmTMB(counts ~ outcome + treatment,
                    family = list(family="poisson", link="log"),
                    d.AD))
## note update(..., family= ...) is only equal up to tolerance=5e-5 ...
    expect_equal(predict(glm.D93),predict(glm.D93B))
    expect_equal(predict(glm.D93),predict(glm.D93C))
})

test_that("lognormal family", {
    test_fun <- function(n, m, v) {
        x <- rnorm(n, mean=m, sd=sqrt(v))
        dd <- data.frame(y=exp(x))
        m1 <- glmmTMB(y~1, family="lognormal", data=dd)
        m2 <- glmmTMB(log(y) ~ 1, data = dd)
        expect_equal(logLik(m1), logLik(m2)-sum(log(dd$y)))
        ## noisy because of expected vs observed mean/variance
        expect_equal(unname(fixef(m1)$cond), m+v/2, tolerance = 1e-2)
        expect_equal(sigma(m1), sqrt((exp(v)-1)*exp(2*m+v)), tolerance = 5e-2)
    }
    set.seed(102)
    test_fun(n = 2e4, m = 0.4, v = 0.2)
    test_fun(n = 2e4, m = 0.7, v = 0.5)
    set.seed(101)
    dd <- data.frame(y = c(0, rlnorm(100, 1, 1)))
    expect_is(glmmTMB(y ~ 1, data = dd, family = lognormal(), ziformula = ~1),
              "glmmTMB")
    expect_error(glmmTMB(y ~ 1, data = dd, family = lognormal()),
                 "must be > 0 ")
    dd <- rbind(dd, data.frame(y=-1))
    expect_error(glmmTMB(y ~ 1, data = dd, family = lognormal(), ziformula = ~1),
                 "must be >= 0")
})

test_that("t-distributed response", {
    set.seed(101)
    dd <- data.frame(y = 3 + 5*rt(1000, df = 10))
    m1 <- glmmTMB(y ~ 1, family = t_family, data = dd)
    expect_equal(unname(fixef(m1)$cond), 2.89682907080939,
                 tolerance = 1e-6)
    expect_equal(sigma(m1), 4.96427774321411,
                 tolerance = 1e-6)
    m2 <- glmmTMB(y ~ 1, family = t_family, data = dd,
                  start = list(psi = log(10)),
                  map = list(psi = factor(NA)))
    expect_equal(sigma(m2), 5.01338678750139,
                 tolerance = 1e-6)
})

test_that("nbinom12 family", {
    set.seed(101)
    n <- 10000
    x <- rnorm(n)
    mu <- exp(2 + 1*x)
    vv <- mu*(1+2+mu/0.5)
    k <- mu/(vv/mu - 1)
    dd <- data.frame(x, y = rnbinom(n, mu = mu, size = k))
    m1 <- glmmTMB(y ~ x, family = nbinom12, data = dd)
    ## basic test
    ## should have phi = 2, k = 0.5
    ## log(phi) ~ 0.7, log(psi) ~ -0.7
    expect_equal(    m1$obj$env$last.par.best,
                 c(beta = 1.98948426828242, beta = 1.00635151325394,
                   betadisp = 0.68344614610532, psi = -0.686823594633112),
                 tolerance = 1e-6)
    expect_equal(sigma(m1), 1.980692, tolerance = 1e-6)
})

test_that("skewnormal family", {
    dd <- data.frame(dummy = rep(1, 500))
    dd$y <- simulate_new(~1,
                            newdata = dd,
                            newparams = list(beta = -1,
                                             betadisp = 3,
                                             psi = -5),
                            seed = 101,
                            family = "skewnormal")[[1]]
    expect_equal(range(dd$y), c(-64.8363758099827, 32.87734399648))
    expect_equal(length(unique(dd$y)), 500L)
    fit <- glmmTMB(y ~ 1,
                   data = dd,
                   family = "skewnormal",
                   start = list(betadisp = log(sd(dd$y)),
                                psi = -5))
    expect_equal(fit$obj$env$last.par.best,
                 c(beta = 0.0765490512716489,
                   betadisp = 2.94927708520387,
                   psi = -6.12362878509844),
                 tolerance = 1e-6)
    expect_equal(family_params(fit),
                 c(`Skewnormal shape` = -6.12362878509844),
                 tolerance = 1e-6)
})

test_that("make_family initialize works", {
    ## GH #1133
    if (require(effects)) {
        data("sleepstudy", package = "lme4")
        m2 <- glmmTMB(round(Reaction) ~ Days + (1 | Subject), sleepstudy,
                      family = truncated_nbinom2)
        ee <- suppressWarnings(effects::Effect("Days", m2))
        expect_equal(c(ee$fit),
                     c(5.5317435373068, 5.6003872162399,
                       5.669030895173, 5.77199641357265, 
                       5.84064009250575))
    }
})

test_that("testing family specification", {
    ## test S4 (motivating example was VGAM::zipoisson,
    ##  but we want an S4 object that comes from packages we already
    ## depend on

    ## family() returns S4 object
    expect_error(glmmTMB(hp ~ mpg, data = mtcars,
                         family = Matrix::Matrix),
                 "must be a list")
    ## family() returns list without $family element
    expect_error(glmmTMB(hp ~ mpg, data = mtcars,
                         family = function() list()),
                 "must be a list")
    ## family is a non-existent object
    expect_error(glmmTMB(hp ~ mpg, data = mtcars,
                         family = zipoisson),
                 "not found")
    ## get(family) doesn't find a function
    expect_error(glmmTMB(hp ~ mpg, data = mtcars,
                         family = "zipoisson"),
                 "of mode.*not found")

})
