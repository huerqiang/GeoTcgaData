#' Get methylation difference gene
#'
#' @title differential_methy
#' @rdname differential_methy
#' @param cpgData data.frame of cpg beta value, , or SummarizedExperiment object
#' @param sampleGroup vector of sample group
#' @param groupCol group column
#' @param combineMethod method to combine the cpg pvalues, 
#' a function or one of "stouffer", "fisher" and "rhoScores".
#' @param missing_value Method to impute missing expression data,
#' one of "zero" and "knn".
#' @param cpg2gene data.frame to annotate cpg locus to gene
#' @param normMethod Method to do normalization: "PBC" or "BMIQ".
#' @param region region of genes, one of "Body", "TSS1500", "TSS200",
#' "3'UTR", "1stExon", "5'UTR", and "IGR". Only used when cpg2gene is NULL.
#' @param model if "cpg", step1: calculate difference cpgs;
#' step2: calculate difference genes.
#' if "gene", step1: calculate the methylation level of genes;
#' step2: calculate difference genes.
#' @param adjust.method character string specifying the method
#' used to adjust p-values for multiple testing.
#' See \link{p.adjust} for possible values.
#' @param ucscData Logical, whether the data comes from UCSC Xena.
#' @param adjPvalCutoff adjusted pvalue cutoff
#' @importFrom stats p.adjust
#' @return data.frame
#' @export
#' @examples
#' \donttest{
#' # use TCGAbiolinks data
#' library(TCGAbiolinks)
#' query <- GDCquery(project = "TCGA-ACC",
#'     data.category = "DNA Methylation",
#'     data.type = "Methylation Beta Value",
#'     platform = "Illumina Human Methylation 450")
#' GDCdownload(query, method = "api", files.per.chunk = 5,
#'     directory = Your_Path)
#' merge_result <- Merge_methy_tcga(Your_Path_to_DNA_Methylation_data)
#' library(ChAMP) # To avoid reporting errors
#' differential_gene <- differential_methy(cpgData = merge_result,
#'     sampleGroup = sample(c("C","T"),
#'     ncol(merge_result[[1]]), replace = TRUE))
#' }
#' # use user defined data
#' library(ChAMP)
#' cpgData <- matrix(runif(2000), nrow = 200, ncol = 10)
#' rownames(cpgData) <- paste0("cpg", seq_len(200))
#' colnames(cpgData) <- paste0("sample", seq_len(10))
#' sampleGroup <- c(rep("group1", 5), rep("group2", 5))
#' names(sampleGroup) <- colnames(cpgData)
#' cpg2gene <- data.frame(cpg = rownames(cpgData), 
#'     gene = rep(paste0("gene", seq_len(20)), 10))
#' result <- differential_methy(cpgData, sampleGroup, 
#'     cpg2gene = cpg2gene, normMethod = NULL)
#' # use SummarizedExperiment object input
#' library(ChAMP)
#' cpgData <- matrix(runif(2000), nrow = 200, ncol = 10)
#' rownames(cpgData) <- paste0("cpg", seq_len(200))
#' colnames(cpgData) <- paste0("sample", seq_len(10))
#' sampleGroup <- c(rep("group1", 5), rep("group2", 5))
#' names(sampleGroup) <- colnames(cpgData)
#' cpg2gene <- data.frame(cpg = rownames(cpgData), 
#'     gene = rep(paste0("gene", seq_len(20)), 10))
#' colData <- S4Vectors::DataFrame(
#'     row.names = colnames(cpgData),
#'     group = sampleGroup
#' )
#' data <- SummarizedExperiment::SummarizedExperiment(
#'          assays=S4Vectors::SimpleList(counts=cpgData),
#'          colData = colData)
#' result <- differential_methy(cpgData = data, 
#'     groupCol = "group", normMethod = NULL, 
#'     cpg2gene = cpg2gene)  
differential_methy  <- function(cpgData, sampleGroup,
                    groupCol,
                    # combineMethod = RobustRankAggreg::rhoScores,
                    combineMethod = "stouffer",
                    missing_value = "knn", 
                    cpg2gene = NULL,
                    normMethod = "PBC", 
                    region = "TSS1500",
                    model = "gene",
                    adjust.method = "BH",
                    adjPvalCutoff = 0.05,
                    ucscData = FALSE) {
    region <- match.arg(region, c("Body", "TSS1500", "TSS200",
        "3'UTR", "1stExon", "5'UTR", "IGR"))
    model <- match.arg(model, c("cpg", "gene"))

    if (inherits(cpgData,  "SummarizedExperiment")) {
        cpgData2 <- cpgData
        cpgData <- assays(cpgData2)$counts
        sampleGroup <- colData(cpgData2)[, groupCol]
        names(sampleGroup) <- rownames(colData(cpgData2))
    } else {
        if (inherits(cpgData,  "list")) { 
            cpgData <- cpgData[[1]]
        }
    }


    if (ucscData) {
        class(cpgData) <- "data.frame"
        rownames(cpgData) <- cpgData[, 1]
        cpgs <- rownames(cpgData)
        cpgData <- cpgData[, -1]
        group <- sampleGroup
        if (is.null(group)) {
            group <- lapply(colnames(cpgData), function(x) {
                strsplit(x, "-")[[1]][4]
            }) |> unlist()
    
            group <- substring(group, 1, 1)
        }
    }



    cpgData <- as.matrix(cpgData)
    # Use KNN to fill in missing values
    if (missing_value == "zero") {
        cpgData[is.na(cpgData)] <- 0
        data.m <- cpgData
    } else {
        data.m <- impute::impute.knn(cpgData)$data
    }

    # normalize data
    myNorm <- data.m
    if (!is.null(normMethod)) {
        myNorm <- ChAMP::champ.norm(beta = data.m, rgSet = NULL, 
            mset = NULL, method = normMethod)
    }
    if (!is.null(cpg2gene)) {
        cpg_gene <- cpg2gene
    } else {
        cpg_gene <- get_cpg_annotation(region = region)
    }


    if (model == "gene") {
        cpg_gene <-  split(cpg_gene[, 2], cpg_gene[, 1])   
        genes <- unlist(lapply(cpg_gene, function(x) {paste(x,collapse = ";")}))
        cpg_gene <- data.frame(cpg = names(cpg_gene), gene = genes)
        rownames(cpg_gene) <- cpg_gene[, 1]
        myNorm <- as.data.frame(myNorm)
        myNorm$gene <- cpg_gene[rownames(myNorm), 2]
        # myNorm <- myNorm[, c(ncol(myNorm), 1:(ncol(myNorm) - 1))]
        myNorm <- myNorm[, c(ncol(myNorm), seq_len(ncol(myNorm) - 1))]
        myNorm <- myNorm[!is.na(myNorm$gene), ]


        myNorm$gene <- as.character(myNorm$gene)
        myNorm2 <- repAssign(myNorm, ";")
        myNorm3 <- gene_ave(myNorm2)

        ## use limma to do differential expression analysis
        gene_pvalue <- differential_limma(myNorm3, group = sampleGroup,
            adjust.method = adjust.method)
        gene_pvalue$gene <- rownames(gene_pvalue)
    } else {
        # Identify Differential Methylation Positions (DMP)
        myDMP <- ChAMP::champ.DMP(beta = myNorm,
            pheno = sampleGroup, adjPVal = 1)
        myDMP <- as.data.frame(myDMP)

        # use cpg_gene to annotate CpGs
        pvalues <- cpg_gene
        pvalues$pvalue <- myDMP[cpg_gene[, 1], 4]
        # rownames(pvalues) <- pvalues[, 1]
        pvalues <- pvalues[!is.na(pvalues$pvalue), ]
        
        if (is.function(combineMethod)) {
            gene_pvalue <- stats::aggregate(pvalues[, 4],
                by = list(pvalues[, 2]),
                # FUN = combine_pvalue, combineMethod = combineMethod
                FUN = combineMethod
            )
            colnames(gene_pvalue) <- c("gene", "pvalue")
        } else {
            aa <- pvalues$pvalue
            bb <- split(aa, pvalues$gene)
            gene_pvalue <- data.frame(gene = names(bb), 
                pvalue = unlist(lapply(bb, function(x) x[1])))
            if (combineMethod == "stouffer") {
                
                myBetas <- myNorm[pvalues$cpg, ]
                myBetas <- split(as.data.frame(myBetas), pvalues$gene)
                correl <- lapply(myBetas, function(x) cor(t(x)))
                weights <- lapply(correl, function(x) 1/apply(x^2,1,sum))
                
                for (i in seq_len(nrow(gene_pvalue))) {
                    if (length(bb[[i]]) > 1) {
                        gene_pvalue[i, 2] <- sumz(bb[[i]], weights[[i]])$p
                    }       
                }
            }

            if (combineMethod == "fisher") {
                for (i in seq_len(nrow(gene_pvalue))) {
                    if (length(bb[[i]]) > 1) {
                        gene_pvalue[i, 2] <- sumlog(bb[[i]])$p
                    }       
                }
            }
        }
        


        # get logFC of genes
        myNorm2 <- myNorm[pvalues[, 1], ]
        myNorm2 <- stats::aggregate(myNorm2,
            by = list(pvalues[, 2]), FUN = mean)

        myNorm2 <- myNorm2[myNorm2[, 1] != "", ]
        rownames(myNorm2) <- myNorm2[, 1]
        myNorm2 <- myNorm2[, -1]
        groups <- sort(unique(sampleGroup))
        mean1 <- rowMeans(myNorm2[, sampleGroup == groups[1]], na.rm = TRUE)
        mean2 <- rowMeans(myNorm2[, sampleGroup == groups[2]], na.rm = TRUE)
        logFC <- mean1 - mean2            

        gene_pvalue$logFC <- logFC[gene_pvalue[, 1]]
        colnames(gene_pvalue) <- c("gene", "P.Value", "logFC")
        gene_pvalue$gene <- as.character(gene_pvalue$gene)
        gene_pvalue$adj.P.Val <- p.adjust(gene_pvalue$P.Value,
            method = adjust.method)
        rownames(gene_pvalue) <- gene_pvalue$gene
    }
    gene_pvalue <- gene_pvalue[gene_pvalue$adj.P.Val < adjPvalCutoff, ]
    return(gene_pvalue)                        
}



#' differential_limma
#'
#' @param df data.frame of the omic data
#' @param group a vector, group of samples.
#' @param adjust.method adjust.method.
#' @return data.frame
#' @export
#' @examples
#' df <- matrix(runif(200), 25, 8)
#' df <- as.data.frame(df)
#' rownames(df) <- paste0("gene", 1:25)
#' colnames(df) <- paste0("sample", 1:8)
#' group <- sample(c("group1", "group2"), 8, replace = TRUE)
#' result <- differential_limma(df = df, group = group)
differential_limma <- function(df, group, adjust.method = "BH") {
    groups <- unique(group)
    # if group is a numberic vector(even for c("0", "1")), will get errors.
    group <- gsub(groups[1], "nromal", group)
    group <- gsub(groups[2], "disease", group)
    design <- stats::model.matrix(~ 0 + factor(group))
    colnames(design) <- levels(factor(group))
    contrast.matrix <- limma::makeContrasts(
        contrasts = paste(colnames(design)[2:1],
        collapse = "-"
    ), levels = colnames(design))

    fit <- limma::lmFit(df, design)
    fit <- limma::contrasts.fit(fit, contrast.matrix)
    fit <- limma::eBayes(fit)
    limma::topTable(fit, adjust.method = adjust.method, number = Inf)
    ## or limma::topTable(fit, coef = 1, adjust='BH', number=Inf)
    ## contrasts.fit is not necessory
    # groups <- unique(group)
    # group <- gsub(groups[1], "nromal", group)
    # group <- gsub(groups[2], "disease", group)
    # design <- stats::model.matrix(~factor(group))

    # fit2 <- lmFit(df, design)
    # fit2 <- eBayes(fit2)
    # topTable(fit2,coef=2, adjust='BH', number=Inf)

    ## coef parameter is not necessory：
    # opTable(fit2, adjust='BH', number=Inf)
}

#' Merge methylation data downloaded from TCGA
#'
#' When the methylation data is downloaded from TCGA, 
#' each sample is saved in a folder, which contains the methylation value file 
#' and the descriptive file. This function can directly 
#' extract and consolidate all folders.
#' @param dirr a string for the directory of methylation data download from tcga
#' useing the tools gdc
#' @return a matrix, a combined methylation expression spectrum matrix
#' @export
#'
#' @examples
#' merge_result <- Merge_methy_tcga(system.file(file.path("extdata", "methy"),
#'     package = "GeoTcgaData"))
Merge_methy_tcga <- function(dirr = NULL) {
    options(warn = -1)
    # file_num=1
    if (is.null(dirr)) stop("please give your directory of methylation data!")
    tcga_dir <- dir(dirr)
    filePath <- file.path(dirr, tcga_dir[1])
    methyFile <- get_methy_df(filePath)
    methyResult <- matrix(0, nrow = nrow(methyFile), ncol = length(tcga_dir))
    rownames(methyResult) <- methyFile[, 1]
    samples <- rep(0, length(tcga_dir))
    methyResult[, 1] <- methyFile[, 2]
    samples[1] <- colnames(methyFile)[2]
    message("file", 1, " is over")
    for (i in 2:length(tcga_dir)) {
        message("file", i, " is over")
        filePath <- file.path(dirr, tcga_dir[i])
        methyFile <- get_methy_df(filePath)
        methyResult[, i] <- methyFile[, 2]
        samples[i] <- colnames(methyFile)[2]
        gc()
    }
    colnames(methyResult) <- samples
    cpg_info <- methyFile[, -2]
    return(list(methyResult = methyResult, cpg_info = cpg_info))
}

#' Read methylated data file and turn it into data frame
#'
#' @param filePath Path of files
#' @return data.frame
#' @noRd
get_methy_df <- function(filePath) {
    methyDir <- dir(filePath)
    if (length(methyDir) == 1) {
        file_name <- file.path(filePath, methyDir)
        sample <- unlist(strsplit(methyDir, "\\."))[1]
    } else {
        for (j in seq_len(length(methyDir))) {
            if (length(grep("jhu-usc", methyDir[j])) > 0) {
                file_name <- file.path(filePath, dir(filePath)[j])
                sample <- unlist(strsplit(dir(filePath)[j], "\\."))[6]
            }
        }
    }

    methyFile <- data.table::fread(file_name, header = FALSE)
    class(methyFile) <- "data.frame"
    colnames(methyFile)[2] <- sample
    return(methyFile)
}


get_cpg_annotation <- function(region = "TSS1500") {
    ## library to avoid errors.
    # library(IlluminaHumanMethylation450kanno.ilmn12.hg19)
    ann <- minfi::getAnnotation(
                IlluminaHumanMethylation450kanno.ilmn12.hg19::IlluminaHumanMethylation450kanno.ilmn12.hg19)
    ann <- as.data.frame(ann)
    cpg_gene <- ann[, c("Name", "UCSC_RefGene_Name", "UCSC_RefGene_Group")]
    # cpg_gene <- cpg_gene[grep(region, cpg_gene$UCSC_RefGene_Group), ]
    cpg_gene <- cpg_gene[cpg_gene[, 2] != "", ]
    genelist <- strsplit(cpg_gene[, 2], ";")
    regionlist <- strsplit(cpg_gene[, 3], ";")
    geneLength <- unlist(lapply(genelist, length))
    cpgs <- rep(cpg_gene[, 1], times = geneLength)
    cpg_gene2 <- data.frame(cpg = cpgs, gene = unlist(genelist), 
        region = unlist(regionlist))
    cpg_gene2 <- cpg_gene2[grep(region, cpg_gene2$region), ]
    return(unique(cpg_gene2))
}
