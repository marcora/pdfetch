// pubmed2pdfetch
// version 0.2
// 2006-10-15
// Copyright (c) 2006, Edoardo "Dado" Marcora, Ph.D. <http://marcora.caltech.edu/>
// Released under the MIT license <http://www.opensource.org/licenses/mit-license.php>
// --------------------------------------------------------------------
//
// This is a Greasemonkey user script.
//
// This script works by extending Firefox <http://www.mozilla.com/>
// via Greasemonkey <http://greasemonkey.mozdev.org/>.
//
// To install this script, open it in Firefox+Greasemonkey and click
// Install.
//
// To uninstall, go to Tools/Manage User Scripts, select
// "pubmed2pdfetch", and click Uninstall.
//
// --------------------------------------------------------------------

// ==UserScript==
// @name          pubmed2pdfetch
// @namespace     http://edoardo.marcora.net/
// @description   Append a 'Download' link when browsing PubMed.
// @include       http://www.ncbi.nlm.nih.gov/entrez/*
// ==/UserScript==

function insertPubmed2Pdfetch(){

    var html = document.evaluate("//p[@class='pmid']",
                                 document.body,
                                 null,
                                 XPathResult.FIRST_ORDERED_NODE_TYPE,
                                 null).singleNodeValue;

    if (html != null){

        html = html.innerHTML;

        var re = /PMID:\s+(\d+)\s+/;

        var pos = html.search(re);
    
        if (pos >= 0){

            var pmid = re.exec(html)[1]; 
	
            var a = document.createElement("a");
            a.setAttribute("title","Download reprint of this article using PDFetch");
            a.setAttribute("href","http://localhost:8888/fetch/"+pmid);
            a.setAttribute("class","dblinks");
    
            var anchor = document.createTextNode("Download");
    
            a.appendChild(anchor);

            var linkbar = document.evaluate("//span[@class='linkbar']",
                                            document.body,
                                            null,
                                            XPathResult.FIRST_ORDERED_NODE_TYPE,
                                            null).singleNodeValue;

            if (linkbar != null){ linkbar.appendChild(a); }
        }
    }
}

window.addEventListener("load", insertPubmed2Pdfetch, false);
