% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/ann_merge.r
\name{ann_merge}
\alias{ann_merge}
\title{Merge the copy number variation data downloaded from TCGA using gdc}
\usage{
ann_merge(dirr, metadatafile)
}
\arguments{
\item{dirr}{a string of direction, catalogue of copy number variation data}

\item{metadatafile}{a metadata file download from TCGA}
}
\value{
a matrix,each column is a sample, each row is a gene
}
\description{
Merge the copy number variation data downloaded from TCGA using gdc
}
\examples{
metadatafile_name <- "metadata.cart.2018-11-09.json"
\dontrun{jieguo2 <- ann_merge(dirr = system.file(file.path("extdata","cnv"),
package="GeoTcgaData"),metadatafile=metadatafile_name)}
}
