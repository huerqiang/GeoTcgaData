% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/kegg_diff_gene.R
\name{diff_gene}
\alias{diff_gene}
\title{Get the differentially expressioned genes using DESeq2 package}
\usage{
diff_gene(profile2_input)
}
\arguments{
\item{profile2_input}{a result of classify_sample}
}
\value{
a matrix, information of differential expression genes
}
\description{
Get the differentially expressioned genes using DESeq2 package
}
\examples{
profile2 <- classify_sample(kegg_liver)
jieguo <- diff_gene(profile2)
}
