#' NCBI Entrez connector abstract class.
#'
#' This is an abstract class, mother class of all NCBI Entrez connector classes.
#'
#' Note: the implementation of the \code{getEntryIds()} method uses a last
#' resort solution.  It returns only a small subset of Ncbi entries.
#'
#' @seealso \code{\link{BiodbConn}}.
#'
#' @examples
#' # Create an instance with default settings:
#' mybiodb <- biodb::newInst()
#'
#' # Create a connector
#' conn <- mybiodb$getFactory()$createConn('ncbi.gene')
#'
#' # Get an entry
#' e <- conn$getEntry('2833')
#'
#' # Terminate instance.
#' mybiodb$terminate()
#'
#' @import biodb
#' @import R6
#' @import XML
#' @export
NcbiEntrezConn <- R6::R6Class("NcbiEntrezConn",
inherit=biodb::BiodbConn,

public=list(

#' @description
#' New instance initializer. Connector classes must not be instantiated
#' directly. Instead, you must use the createConn() method of the factory class.
#' @param entrez.name   Entrez database name (ex: "gene").
#' @param entrez.tag    Entrez database tag (ex: "Entrezgene").
#' @param entrez.id.tag Entrez database ID tag (ex: "Gene-track_geneid").
#' @param ... All other parameters are passed to the super class initializer.
#' @return Nothing.
initialize=function(entrez.name, entrez.tag=NULL, entrez.id.tag=NULL, ...) {

    super$initialize(...)
    abstractClass('NcbiEntrezConn', self)
    chk::chk_string(entrez.name)
    chk::chk_null_or(entrez.tag, chk::chk_string)
    chk::chk_null_or(entrez.id.tag, chk::chk_string)

    # Set values
    private$entrez.name <- entrez.name
    private$entrez.tag <- entrez.tag
    private$entrez.id.tag <- entrez.id.tag
}

#' @description
#' Calls Entrez efetch web service. See
#' https://www.ncbi.nlm.nih.gov/books/NBK25499/#chapter4.EFetch.
#' @param id A character vector of entry IDs.
#' @param rettype The retrieval type. See NCBI documentation.
#' @param retmode The retrieval mode. See NCBI documentation.
#' @param retfmt Use to set the format of the returned value. 'plain' will
#' return the raw results from the server, as a character value. 'parsed' will
#' return the parsed results, as an XML object. 'request' will return a
#' BiodbRequest object representing the request as it would have been sent.
#' @return Depending on `retfmt` parameter.
,wsEfetch=function(id, rettype=NULL, retmode=NULL,
    retfmt=c('plain', 'parsed', 'request')) {

    retfmt <- match.arg(retfmt)
    chk::chk_null_or(rettype, chk::chk_string)
    chk::chk_null_or(retmode, chk::chk_string)

    # Build request
    params <- c(db=private$entrez.name, id=paste(id, collapse=','))
    if ( ! is.null(rettype))
        params <- c(params, rettype=rettype)
    if ( ! is.null(retmode))
        params <- c(params, retmode=retmode)
    u <- c(self$getPropValSlot('urls', 'ws.url'), 'efetch.fcgi')
    url <- biodb::BiodbUrl$new(url=u, params=params)
    request <- self$makeRequest(method='get', url=url)
    if (retfmt == 'request')
        return(request)

    # Send request
    results <- self$getBiodb()$getRequestScheduler()$sendRequest(request)

    # Parse
    if (retfmt == 'parsed' && retmode == 'xml')
        results <-  XML::xmlInternalTreeParse(results, asText=TRUE)

    return(results)
},

#' @description
#' Calls Entrez esearch web service. See
#' https://www.ncbi.nlm.nih.gov/books/NBK25499/#chapter4.ESearch.
#' @param term Text query. See NCBI documentation.
#' @param field Entrez field to which to limit the search. See NCBI
#' documentation.
#' @param retmax Maximum number of entry IDs to return.
#' @param retfmt Use to set the format of the returned value. 'plain' will
#' return the raw results from the server, as a character value. 'parsed' will
#' return the parsed results, as an XML object. 'request' will return a
#' BiodbRequest object representing the request as it would have been sent.
#' 'ids' will return a character vector containing the IDs of the matching
#' entries.
#' @return Depending on `retfmt` parameter.
wsEsearch=function(term, field=NULL, retmax=NULL,
    retfmt=c('plain', 'parsed', 'request', 'ids')) {

    retfmt <- match.arg(retfmt)
    chk::chk_null_or(field, chk::chk_string)
    chk::chk_null_or(retmax, chk::chk_whole_number)

    # Build request
    params <- c(db=private$entrez.name, term=term)
    if ( ! is.null(field))
        params <- c(params, field=field)
    if ( ! is.null(retmax) && retmax > 0)
        params <- c(params, retmax=as.integer(retmax))
    u <- c(self$getPropValSlot('urls', 'ws.url'), 'esearch.fcgi')
    url <- biodb::BiodbUrl$new(url=u, params=params)
    request <- self$makeRequest(method='get', url=url)
    if (retfmt == 'request')
        return(request)

    # Send request
    results <- self$getBiodb()$getRequestScheduler()$sendRequest(request)

    # Parse results
    if (retfmt != 'plain') {

        # Parse XML
        results <-  XML::xmlInternalTreeParse(results, asText=TRUE)

        # Get IDs
        if (retfmt == 'ids')
            results <- XML::xpathSApply(results, "//IdList/Id", XML::xmlValue)
    }

    return(results)
}

#' @description
#' Calls Entrez einfo web service, returning information about this
#' database. See https://www.ncbi.nlm.nih.gov/books/NBK25499/#chapter4.EInfo.
#' @param retfmt Use to set the format of the returned value. 'plain' will
#' return the raw results from the server, as a character value. 'parsed' will
#' return the parsed results, as an XML object. 'request' will return a
#' BiodbRequest object representing the request as it would have been sent.
#' @return Depending on `retfmt` parameter.
,wsEinfo=function(retfmt=c('plain', 'request', 'parsed')) {

    retfmt <- match.arg(retfmt)

    # Build request
    params <- c(db=private$entrez.name, version='2.0')
    u <- c(self$getPropValSlot('urls', 'ws.url'), 'einfo.fcgi')
    url <- biodb::BiodbUrl$new(url=u, params=params)
    request <- self$makeRequest(method='get', url=url)
    if (retfmt == 'request')
        return(request)

    # Send request
    results <- self$getBiodb()$getRequestScheduler()$sendRequest(request)

    # Parse XML
    if (retfmt == 'parsed')
        results <-  XML::xmlInternalTreeParse(results, asText=TRUE)

    return(results)
}
),

private=list(
    entrez.name=NULL
    ,entrez.tag=NULL
    ,entrez.id.tag=NULL

,doGetNbEntries=function(count=FALSE) {

    # Send request
    xml <- self$wsEinfo(retfmt='parsed')

    # Get number of elements
    n <- XML::xpathSApply(xml, "//Count", XML::xmlValue)
    n <- as.integer(n)

    return(n)
}

,extractReturnedIds=function(xml, tag, ns=NULL) {
    nsname <- if (is.null(ns)) '' else paste0(names(ns)[[1]], ':')
    xpath <- paste0("//", nsname, tag)
    if (is.null(ns))
        returned.ids <- XML::xpathSApply(xml, xpath, XML::xmlValue)
    else
        returned.ids <- XML::xpathSApply(xml, xpath, XML::xmlValue,
        namespaces=ns)
    return(returned.ids)
}

,extractIndividualContents=function(xml, tag, ns=NULL) {
    nsname <- if (is.null(ns)) '' else paste0(names(ns)[[1]], ':')
    xpath <- paste0("//", nsname, tag)
    if (is.null(ns))
        nodes <- XML::getNodeSet(xml, xpath)
    else
        nodes <- XML::getNodeSet(xml, xpath, namespaces=ns)
    contents <- vapply(nodes, XML::saveXML, FUN.VALUE='')
    return(contents)
}

,checkXml=function(xmlstr, re) {
    v <- TRUE
    if (is.na(xmlstr) || length(grep(re, xmlstr)) > 0) {
        v <- FALSE
        biodb::logDebug0("XML contains error messages.",
            " At least one of the IDs to retrieve is wrong.")
    }
    return(v)
}

,retrieveContents=function(id, err.re, id.tag, entry.tag, ns=NULL) {

    biodb::logInfo("Get entry content(s) for %d id(s)...", length(id))

    URL.MAX.LENGTH <- 2048
    concatenate <- TRUE
    done <- FALSE

    while ( ! done) {

        done <- TRUE

        # Initialize return values
        content <- rep(NA_character_, length(id))

        # Get URL requests
        urls <- self$getEntryContentRequest(id,
            concatenate=concatenate, max.length=URL.MAX.LENGTH)

        # Loop on all URLs
        for (u in urls) {

            # Send request
            request <- biodb::BiodbRequest$new(biodb::BiodbUrl$new(u))
            xmlstr <- self$getBiodb()$getRequestScheduler()$sendRequest(request)

            # Handle errors
            if ( ! private$checkXml(xmlstr, err.re)) {
                if (concatenate && length(id) > 1) {
                    concatenate <- done <- FALSE
                    break
                }
                next
            }

            # Parse XML
            xml <- XML::xmlInternalTreeParse(xmlstr, asText=TRUE)

            # Extract and store contents
            returned.ids <- private$extractReturnedIds(xml, tag=id.tag, ns=ns)
            individual.contents <- private$extractIndividualContents(xml,
                tag=entry.tag, ns=ns)
            content[match(returned.ids, id)] <- individual.contents
        }
    }

    return(content)
}

,doGetEntryContentFromDb=function(id) {
    return(private$retrieveContents(id=id, err.re='<ERROR>',
        id.tag=private$entrez.id.tag, entry.tag=private$entrez.tag))
}

,doGetEntryContentRequest=function(id, concatenate=TRUE) {

    if (concatenate)
        urls <- self$wsEfetch(id, retmode='xml',
            retfmt='request')$getUrl()$toString()
    else {
        fct <- function(single.id) { 
            self$wsEfetch(single.id, retmode='xml',
                retfmt='request')$getUrl()$toString()
        }
        urls <- vapply(id, fct, FUN.VALUE='')
    }

    return(urls)
}

,doGetEntryIds=function(max.results=NA_integer_) {

    # XXX Returns only a small subset of Ncbi entries
    retmax <- if (is.na(max.results)) 1000000L else as.integer(max.results)
    return(self$wsEsearch(term='e', retmax=retmax, retfmt='ids'))
}

))
