% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/arrayDiff.R
\name{differential_array}
\alias{differential_array}
\title{Differential analysis of Microarray data}
\usage{
differential_array(df, group, method = "limma", adjust.method = "BH")
}
\arguments{
\item{df}{data.frame of the omic data, each column is a sample, 
and each row is a gene.}

\item{group}{a vector, group of samples.}

\item{method}{method to do differential analysis, 
one of "limma", "ttest", "wilcox".}

\item{adjust.method}{adjust.method, one of "holm", "hochberg", "hommel", 
"bonferroni", "BH", "BY", "fdr", and "none".}
}
\value{
data.frame
}
\description{
Differential analysis of Microarray data
}
\examples{
\donttest{
library(GeoTcgaData)
library(data.table)
# Use real GEO data as example
arrayData <- read.table("GSE54807_series_matrix.txt.gz",
    sep = "\t", header = TRUE,
        fill=TRUE, comment.char = "!", check.names=FALSE)
gpl <- fread("GPL6244-17930.txt", sep = "\t", header = TRUE)
gpl <- gpl[, c("ID", "gene_assignment")]
class(gpl) <- "data.frame"

for (i in seq_len(nrow(gpl))) {
        aa <- strsplit(gpl[i, 2], " // ")[[1]][5]
        gpl[i, 2] <- as.character(strsplit(aa, " /// ")[[1]][1])
}
gpl[,1] <- as.character(gpl[,1])
arrayData[, 1] <- as.character(arrayData[, 1])
rownames(gpl) <- gpl[, 1]
arrayData[, 1] <- gpl[arrayData[, 1], 2]


arrayData <- repRemove(arrayData," /// ")

# Remove rows that do not correspond to genes
arrayData <- arrayData[!is.na(arrayData[, 1]), ]
arrayData <- arrayData[!arrayData[, 1] == "", ]
arrayData <- arrayData[!arrayData[, 1] == "---", ]


arrayData <- arrayData[order(arrayData[, 1]), ]
arrayData <- gene_ave(arrayData, 1)

keep <- apply(arrayData, 1, function(x) sum(x < 1) < (length(x)/2))
arrayData <- arrayData[keep, ]

group <- c(rep("group1", 12), rep("group2", 12))
result <- differential_array(df = arrayData, group = group)
}
# Use random data as example
arrayData <- matrix(runif(200), 25, 8)
rownames(arrayData) <- paste0("gene", 1:25)
colnames(arrayData) <- paste0("sample", 1:8)
group <- c(rep("group1", 4), rep("group2", 4))
names(group) <- colnames(arrayData)
result <- differential_array(df = arrayData, group = group)
}
