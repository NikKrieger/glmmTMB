% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/utils.R
\name{up2date}
\alias{up2date}
\alias{gt_load}
\title{conditionally update glmmTMB object fitted with an old TMB version}
\usage{
up2date(oldfit, update_gauss_disp = FALSE)

gt_load(fn, verbose = FALSE, ...)
}
\arguments{
\item{oldfit}{a fitted glmmTMB object}

\item{update_gauss_disp}{update \code{betadisp} from variance to SD parameterization?}

\item{fn}{partial path to system file (e.g. test_data/foo.rda)}

\item{verbose}{print names of updated objects?}

\item{\dots}{values passed through to \code{up2date}}
}
\description{
conditionally update glmmTMB object fitted with an old TMB version

Load data from system file, updating glmmTMB objects
}
