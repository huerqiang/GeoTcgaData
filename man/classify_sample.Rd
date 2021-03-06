% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/kegg_diff_gene.R
\name{classify_sample}
\alias{classify_sample}
\title{Get the differentially expressioned genes using DESeq2 package}
\usage{
classify_sample(profile_input)
}
\arguments{
\item{profile_input}{a data.frame}
}
\value{
a data.frame, a intermediate results of DESeq2
}
\description{
Get the differentially expressioned genes using DESeq2 package
}
\examples{
profile2 <- classify_sample(kegg_liver)
}
