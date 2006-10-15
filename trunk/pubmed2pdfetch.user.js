// pubmed2pdfetch
// version 0.1
// 2006-10-15
// Copyright (c) 2006, Edoardo "Dado" Marcora, Ph.D. <http://marcora.caltech.edu/>
// Released under the MIT license <http://www.opensource.org/licenses/mit-license.php>
// --------------------------------------------------------------------
//
// This is a Greasemonkey user script.  To install it, you need
// Greasemonkey 0.6.4 or later: http://greasemonkey.mozdev.org/
// and Firefox 1.5 : http://www.mozilla.com/
// Then restart Firefox and revisit this script.
// Under Tools, there will be a new menu item to "Install User Script".
// Accept the default configuration and install.
//
// To uninstall, go to Tools/Manage User Scripts,
// select "pubmed2connotea", and click Uninstall.
//
// --------------------------------------------------------------------

// ==UserScript==
// @name          pubmed2connotea
// @namespace     http://www.integragen.com
// @description   append a shortcut link used to add an entry in http://www.connotea.org or http://www.citeulike.org/ when browsing NCBI pubmed
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
